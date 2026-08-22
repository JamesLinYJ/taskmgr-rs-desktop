// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows CPU 固件信息
//
//   文件:       crates/taskmgr-windows/src/wmi.rs
//
//   日期:       2026年08月22日
//   环境:       Windows x64/ARM64 WMI；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Win32_Processor；IWbemServices；VARIANT
// --------------------------------------------------------------------------

//! 读取注册表与原生拓扑无法可靠提供的 CPU 固件字段。
//!
//! COM/WMI 生命周期完全限定在一次静态库存查询中，返回值只包含普通 Rust 值；失败时
//! 调用方继续使用注册表和 CPUID 回退。

use std::collections::BTreeSet;
use std::mem::ManuallyDrop;

use taskmgr_core::BackendError;
use windows::Win32::Foundation::{RPC_E_CHANGED_MODE, RPC_E_TOO_LATE};
use windows::Win32::System::Com::{
    CLSCTX_INPROC_SERVER, COINIT_MULTITHREADED, CoCreateInstance, CoInitializeEx,
    CoInitializeSecurity, CoSetProxyBlanket, CoUninitialize, EOAC_NONE, RPC_C_AUTHN_LEVEL_CALL,
    RPC_C_IMP_LEVEL_IMPERSONATE,
};
use windows::Win32::System::Rpc::{RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE};
use windows::Win32::System::Variant::{VARIANT, VT_BSTR, VT_EMPTY, VT_I4, VT_NULL, VariantClear};
use windows::Win32::System::Wmi::{
    CIM_STRING, CIM_UINT16, CIM_UINT32, IWbemClassObject, IWbemLocator, IWbemServices,
    WBEM_E_NOT_FOUND, WBEM_FLAG_FORWARD_ONLY, WBEM_FLAG_RETURN_IMMEDIATELY, WBEM_INFINITE,
    WbemLocator,
};
use windows::core::{BSTR, PCWSTR};

#[derive(Clone, Debug, Default)]
pub(crate) struct CpuFirmwareInfo {
    pub(crate) model: Option<String>,
    pub(crate) manufacturer: Option<String>,
    pub(crate) socket: Option<String>,
    pub(crate) processor_id: Option<String>,
    pub(crate) address_width_bits: Option<u16>,
    pub(crate) data_width_bits: Option<u16>,
    pub(crate) family: Option<String>,
    pub(crate) level: Option<String>,
    pub(crate) revision: Option<String>,
    pub(crate) stepping: Option<String>,
    pub(crate) maximum_frequency_mhz: Option<f64>,
}

#[derive(Clone, Debug)]
struct FirmwareProcessor {
    device_id: String,
    model: Option<String>,
    manufacturer: Option<String>,
    socket: Option<String>,
    processor_id: Option<String>,
    address_width_bits: Option<u16>,
    data_width_bits: Option<u16>,
    family: Option<u16>,
    level: Option<u16>,
    revision: Option<u16>,
    stepping: Option<String>,
    maximum_frequency_mhz: Option<u32>,
}

pub(crate) fn query_cpu_firmware() -> Result<CpuFirmwareInfo, BackendError> {
    let provider = CpuWmiProvider::connect()?;
    let processors = provider.query_processors()?;
    Ok(summarize_processors(&processors))
}

fn summarize_processors(processors: &[FirmwareProcessor]) -> CpuFirmwareInfo {
    CpuFirmwareInfo {
        model: join_unique_strings(processors, |value| value.model.as_deref()),
        manufacturer: join_unique_strings(processors, |value| value.manufacturer.as_deref()),
        socket: join_unique_owned(processors.iter().filter_map(|value| {
            value
                .socket
                .as_deref()
                .map(str::trim)
                .filter(|socket| !socket.is_empty())
                .map(|socket| format!("{}: {socket}", value.device_id))
        })),
        processor_id: join_unique_strings(processors, |value| value.processor_id.as_deref()),
        address_width_bits: common_value(processors, |value| value.address_width_bits),
        data_width_bits: common_value(processors, |value| value.data_width_bits),
        family: join_unique_numbers(processors, |value| value.family),
        level: join_unique_numbers(processors, |value| value.level),
        revision: join_unique_numbers(processors, |value| value.revision),
        stepping: join_unique_strings(processors, |value| value.stepping.as_deref()),
        maximum_frequency_mhz: processors
            .iter()
            .filter_map(|value| value.maximum_frequency_mhz)
            .max()
            .map(f64::from),
    }
}

fn join_unique_strings(
    processors: &[FirmwareProcessor],
    select: impl Fn(&FirmwareProcessor) -> Option<&str>,
) -> Option<String> {
    join_unique_owned(
        processors
            .iter()
            .filter_map(select)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string),
    )
}

fn join_unique_numbers<T>(
    processors: &[FirmwareProcessor],
    select: impl Fn(&FirmwareProcessor) -> Option<T>,
) -> Option<String>
where
    T: Copy + Ord + ToString,
{
    join_unique_owned(
        processors
            .iter()
            .filter_map(select)
            .map(|value| value.to_string()),
    )
}

fn join_unique_owned(values: impl IntoIterator<Item = String>) -> Option<String> {
    let values = values.into_iter().collect::<BTreeSet<_>>();
    (!values.is_empty()).then(|| values.into_iter().collect::<Vec<_>>().join(", "))
}

fn common_value<T: Copy + Eq>(
    processors: &[FirmwareProcessor],
    select: impl Fn(&FirmwareProcessor) -> Option<T>,
) -> Option<T> {
    let mut values = processors.iter().filter_map(select);
    let first = values.next()?;
    values.all(|value| value == first).then_some(first)
}

struct ComApartment(bool);

impl ComApartment {
    fn initialize() -> Result<Self, BackendError> {
        // SAFETY: initialization and uninitialization are paired on this same thread. If the
        // caller already owns a different apartment, COM is still initialized and WMI can use it.
        let owns_initialization = match unsafe { CoInitializeEx(None, COINIT_MULTITHREADED) }.ok() {
            Ok(()) => true,
            Err(error) if error.code() == RPC_E_CHANGED_MODE => false,
            Err(error) => return Err(hresult_error("CoInitializeEx for CPU WMI", &error)),
        };
        match unsafe {
            CoInitializeSecurity(
                None,
                -1,
                None,
                None,
                RPC_C_AUTHN_LEVEL_CALL,
                RPC_C_IMP_LEVEL_IMPERSONATE,
                None,
                EOAC_NONE,
                None,
            )
        } {
            Ok(()) => Ok(Self(owns_initialization)),
            Err(error) if error.code() == RPC_E_TOO_LATE => Ok(Self(owns_initialization)),
            Err(error) => {
                if owns_initialization {
                    // SAFETY: the successful initialization above must be balanced here.
                    unsafe { CoUninitialize() };
                }
                Err(hresult_error("CoInitializeSecurity for CPU WMI", &error))
            }
        }
    }
}

impl Drop for ComApartment {
    fn drop(&mut self) {
        if self.0 {
            // SAFETY: this object owns one successful CoInitializeEx on the same thread.
            unsafe { CoUninitialize() };
        }
    }
}

struct CpuWmiProvider {
    services: IWbemServices,
    _apartment: ComApartment,
}

impl CpuWmiProvider {
    fn connect() -> Result<Self, BackendError> {
        let apartment = ComApartment::initialize()?;
        // SAFETY: COM is initialized and the requested class is the documented in-proc locator.
        let locator: IWbemLocator =
            unsafe { CoCreateInstance(&WbemLocator, None, CLSCTX_INPROC_SERVER) }
                .map_err(|error| hresult_error("CoCreateInstance WbemLocator", &error))?;
        let empty = BSTR::new();
        // SAFETY: all BSTR values remain live for this synchronous connection call.
        let services = unsafe {
            locator.ConnectServer(
                &BSTR::from("ROOT\\CIMV2"),
                &empty,
                &empty,
                &empty,
                0,
                &empty,
                None,
            )
        }
        .map_err(|error| hresult_error("IWbemLocator::ConnectServer for CPU", &error))?;
        // SAFETY: the service proxy is live; the blanket uses documented local WMI settings.
        unsafe {
            CoSetProxyBlanket(
                &services,
                RPC_C_AUTHN_WINNT,
                RPC_C_AUTHZ_NONE,
                PCWSTR::null(),
                RPC_C_AUTHN_LEVEL_CALL,
                RPC_C_IMP_LEVEL_IMPERSONATE,
                None,
                EOAC_NONE,
            )
        }
        .map_err(|error| hresult_error("CoSetProxyBlanket for CPU WMI", &error))?;
        Ok(Self {
            services,
            _apartment: apartment,
        })
    }

    fn query_processors(&self) -> Result<Vec<FirmwareProcessor>, BackendError> {
        let query = BSTR::from(
            "SELECT DeviceID, Name, Manufacturer, SocketDesignation, ProcessorId, Family, Level, \
             Revision, Stepping, AddressWidth, DataWidth, MaxClockSpeed FROM Win32_Processor",
        );
        // SAFETY: service and query strings remain live for the synchronous ExecQuery call.
        let enumerator = unsafe {
            self.services.ExecQuery(
                &BSTR::from("WQL"),
                &query,
                WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                None,
            )
        }
        .map_err(|error| hresult_error("IWbemServices::ExecQuery Win32_Processor", &error))?;

        let mut processors = Vec::new();
        loop {
            let mut objects: [Option<IWbemClassObject>; 1] = [None];
            let mut returned = 0u32;
            // SAFETY: output storage is valid and the enumerator initializes at most one object.
            let status = unsafe { enumerator.Next(WBEM_INFINITE, &mut objects, &mut returned) };
            status
                .ok()
                .map_err(|error| hresult_error("Win32_Processor enumerator", &error))?;
            if returned == 0 {
                break;
            }
            if returned != 1 {
                return Err(invalid_data(
                    "Win32_Processor returned an invalid row count",
                ));
            }
            let object = objects[0]
                .take()
                .ok_or_else(|| invalid_data("Win32_Processor returned a null row"))?;
            let Some(device_id) = get_wmi_string(&object, "DeviceID")? else {
                continue;
            };
            processors.push(FirmwareProcessor {
                device_id,
                model: get_wmi_string(&object, "Name")?,
                manufacturer: get_wmi_string(&object, "Manufacturer")?,
                socket: get_wmi_string(&object, "SocketDesignation")?,
                processor_id: get_wmi_string(&object, "ProcessorId")?,
                family: get_wmi_u16(&object, "Family")?,
                level: get_wmi_u16(&object, "Level")?,
                revision: get_wmi_u16(&object, "Revision")?,
                stepping: get_wmi_string(&object, "Stepping")?,
                address_width_bits: get_wmi_u16(&object, "AddressWidth")?,
                data_width_bits: get_wmi_u16(&object, "DataWidth")?,
                maximum_frequency_mhz: get_wmi_u32(&object, "MaxClockSpeed")?,
            });
        }
        if processors.is_empty() {
            return Err(invalid_data("Win32_Processor returned no usable rows"));
        }
        processors.sort_by(|left, right| left.device_id.cmp(&right.device_id));
        Ok(processors)
    }
}

struct OwnedVariant(VARIANT);

impl OwnedVariant {
    fn new() -> Self {
        Self(VARIANT::default())
    }

    fn value(&self) -> &windows::Win32::System::Variant::VARIANT_0_0 {
        // SAFETY: reading the discriminant and matching union member is handled by each getter.
        unsafe { &self.0.Anonymous.Anonymous }
    }
}

impl Drop for OwnedVariant {
    fn drop(&mut self) {
        // SAFETY: the VARIANT is initialized and uniquely owned by this wrapper.
        let _ = unsafe { VariantClear(&mut self.0) };
    }
}

struct WmiProperty {
    value: OwnedVariant,
    cim_type: i32,
}

fn get_wmi_property(
    object: &IWbemClassObject,
    name: &'static str,
) -> Result<Option<WmiProperty>, BackendError> {
    let wide_name = name.encode_utf16().chain([0]).collect::<Vec<_>>();
    let mut value = OwnedVariant::new();
    let mut cim_type = 0;
    // SAFETY: name is null terminated and the VARIANT/type outputs remain writable for the call.
    let result = unsafe {
        object.Get(
            PCWSTR(wide_name.as_ptr()),
            0,
            &mut value.0,
            Some(&mut cim_type),
            None,
        )
    };
    match result {
        Ok(()) => Ok(Some(WmiProperty { value, cim_type })),
        Err(error) if error.code().0 == WBEM_E_NOT_FOUND.0 => Ok(None),
        Err(error) => Err(hresult_error(
            &format!("IWbemClassObject::Get {name}"),
            &error,
        )),
    }
}

fn get_wmi_string(
    object: &IWbemClassObject,
    name: &'static str,
) -> Result<Option<String>, BackendError> {
    let Some(property) = get_wmi_property(object, name)? else {
        return Ok(None);
    };
    if property.cim_type != CIM_STRING.0 {
        return Ok(None);
    }
    let inner = property.value.value();
    match inner.vt {
        VT_EMPTY | VT_NULL => Ok(None),
        VT_BSTR => {
            // SAFETY: VT_BSTR selects bstrVal. VariantClear remains its sole owner.
            let bstr: &ManuallyDrop<BSTR> = unsafe { &inner.Anonymous.bstrVal };
            let bstr = unsafe { &*(bstr as *const ManuallyDrop<BSTR>).cast::<BSTR>() };
            let value = String::from_utf16(bstr)
                .map_err(|_| invalid_data(format!("Win32_Processor {name} encoding")))?;
            let value = value.trim();
            Ok((!value.is_empty()).then(|| value.to_string()))
        }
        _ => Ok(None),
    }
}

fn get_wmi_u16(object: &IWbemClassObject, name: &'static str) -> Result<Option<u16>, BackendError> {
    let Some(property) = get_wmi_property(object, name)? else {
        return Ok(None);
    };
    if property.cim_type != CIM_UINT16.0 {
        return Ok(None);
    }
    let inner = property.value.value();
    match inner.vt {
        VT_EMPTY | VT_NULL => Ok(None),
        VT_I4 => {
            // SAFETY: VT_I4 selects lVal.
            let value = unsafe { inner.Anonymous.lVal };
            Ok(u16::try_from(value).ok())
        }
        _ => Ok(None),
    }
}

fn get_wmi_u32(object: &IWbemClassObject, name: &'static str) -> Result<Option<u32>, BackendError> {
    let Some(property) = get_wmi_property(object, name)? else {
        return Ok(None);
    };
    if property.cim_type != CIM_UINT32.0 {
        return Ok(None);
    }
    let inner = property.value.value();
    match inner.vt {
        VT_EMPTY | VT_NULL => Ok(None),
        VT_I4 => {
            // SAFETY: VT_I4 selects lVal. WMI transports CIM_UINT32 through the signed storage.
            Ok(Some(u32::from_ne_bytes(
                unsafe { inner.Anonymous.lVal }.to_ne_bytes(),
            )))
        }
        _ => Ok(None),
    }
}

fn hresult_error(context: &str, error: &windows::core::Error) -> BackendError {
    BackendError {
        domain: "hresult".to_string(),
        code: i64::from(error.code().0),
        context: context.to_string(),
        message: error.to_string(),
    }
}

fn invalid_data(context: impl Into<String>) -> BackendError {
    BackendError::internal(context, "Windows returned inconsistent CPU firmware data")
}

#[cfg(test)]
mod tests {
    use super::{FirmwareProcessor, summarize_processors};

    #[test]
    fn firmware_summary_uses_classic_socket_and_identity_format() {
        let summary = summarize_processors(&[FirmwareProcessor {
            device_id: "CPU0".to_string(),
            model: Some("Example CPU".to_string()),
            manufacturer: Some("AuthenticAMD".to_string()),
            socket: Some("FL1".to_string()),
            processor_id: Some("178BFBFF00A60F12".to_string()),
            address_width_bits: Some(64),
            data_width_bits: Some(64),
            family: Some(107),
            level: Some(25),
            revision: Some(24834),
            stepping: Some("2".to_string()),
            maximum_frequency_mhz: Some(2400),
        }]);

        assert_eq!(summary.socket.as_deref(), Some("CPU0: FL1"));
        assert_eq!(summary.processor_id.as_deref(), Some("178BFBFF00A60F12"));
        assert_eq!(summary.family.as_deref(), Some("107"));
        assert_eq!(summary.revision.as_deref(), Some("24834"));
        assert_eq!(summary.maximum_frequency_mhz, Some(2400.0));
    }
}
