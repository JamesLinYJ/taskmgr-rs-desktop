// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows GPU 静态元数据
//
//   文件:       crates/taskmgr-windows/src/gpu_metadata.rs
//
//   日期:       2026年08月21日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   D3DKMTQueryAdapterInfo；SetupAPI Device Properties
// --------------------------------------------------------------------------

//! 通过适配器 LUID 找到精确的 PnP 设备，再读取驱动与位置属性。
//!
//! D3DKMT 温度和已安装显存是可选来源；任一字段失败只留下结构化错误，
//! 不会清空同一适配器已经可信的其他字段。

use std::ffi::c_void;
use std::mem::{size_of, zeroed};
use std::ptr::{null, null_mut};

use taskmgr_core::BackendError;
use windows_sys::Wdk::Graphics::Direct3D::{
    D3DDDI_QUERYREGISTRY_ADAPTERKEY, D3DDDI_QUERYREGISTRY_INFO,
    D3DDDI_QUERYREGISTRY_STATUS_SUCCESS, D3DKMT_ADAPTER_PERFDATA, D3DKMT_CLOSEADAPTER,
    D3DKMT_OPENADAPTERFROMLUID, D3DKMT_PNP_KEY_HARDWARE, D3DKMT_QUERY_PHYSICAL_ADAPTER_PNP_KEY,
    D3DKMT_QUERYADAPTERINFO, D3DKMTCloseAdapter, D3DKMTOpenAdapterFromLuid, D3DKMTQueryAdapterInfo,
    KMTQAITYPE_ADAPTERPERFDATA, KMTQAITYPE_PHYSICALADAPTERPNPKEY, KMTQAITYPE_QUERYREGISTRY,
};
use windows_sys::Win32::Devices::DeviceAndDriverInstallation::{
    DIGCF_PRESENT, GUID_DEVCLASS_DISPLAY, HDEVINFO, SP_DEVINFO_DATA, SetupDiDestroyDeviceInfoList,
    SetupDiGetClassDevsW, SetupDiGetDevicePropertyW, SetupDiOpenDeviceInfoW,
};
use windows_sys::Win32::Devices::Properties::{
    DEVPKEY_Device_DriverDate, DEVPKEY_Device_DriverProvider, DEVPKEY_Device_DriverVersion,
    DEVPKEY_Device_LocationInfo, DEVPKEY_Device_LocationPaths, DEVPROP_TYPE_FILETIME,
    DEVPROP_TYPE_STRING, DEVPROP_TYPE_STRING_LIST, DEVPROPTYPE,
};
use windows_sys::Win32::Foundation::{
    DEVPROPKEY, ERROR_GEN_FAILURE, ERROR_INSUFFICIENT_BUFFER, ERROR_NOT_FOUND, ERROR_SUCCESS,
    FILETIME, GetLastError, INVALID_HANDLE_VALUE, LUID, STATUS_BUFFER_OVERFLOW,
    STATUS_BUFFER_TOO_SMALL, SYSTEMTIME,
};
use windows_sys::Win32::System::Registry::REG_QWORD;
use windows_sys::Win32::System::Time::FileTimeToSystemTime;

const MAX_DEVICE_PROPERTY_BYTES: u32 = 64 * 1024 * 1024;
const MAX_PNP_KEY_CHARS: u32 = 32 * 1024;
const INSTALLED_MEMORY_VALUE_NAME: &str = "HardwareInformation.qwMemorySize";

#[derive(Clone, Debug, Default)]
pub(crate) struct GpuMetadata {
    pub(crate) temperature_celsius: Option<f64>,
    pub(crate) driver_name: Option<String>,
    pub(crate) driver_version: Option<String>,
    pub(crate) driver_date: Option<String>,
    pub(crate) physical_location: Option<String>,
    pub(crate) hardware_reserved_bytes: Option<u64>,
    pub(crate) detail_error: Option<BackendError>,
}

pub(crate) fn query_gpu_metadata(
    luid_high: u32,
    luid_low: u32,
    physical_index: u32,
    dedicated_limit: Option<u64>,
) -> Result<GpuMetadata, BackendError> {
    let adapter = OwnedKmtAdapter::open(LUID {
        LowPart: luid_low,
        HighPart: luid_high as i32,
    })?;
    let mut metadata = GpuMetadata::default();

    match adapter.temperature(physical_index) {
        Ok(value) => metadata.temperature_celsius = value.map(|value| f64::from(value) / 10.0),
        Err(error) => record_first_error(&mut metadata.detail_error, error),
    }
    match adapter.installed_memory(physical_index) {
        Ok(Some(installed)) => match dedicated_limit {
            Some(limit) if installed >= limit => {
                metadata.hardware_reserved_bytes = Some(installed - limit)
            }
            Some(_) => record_first_error(
                &mut metadata.detail_error,
                invalid_data("installed GPU memory is below the dedicated limit"),
            ),
            None => {}
        },
        Ok(None) => {}
        Err(error) => record_first_error(&mut metadata.detail_error, error),
    }

    let setup_result = adapter
        .pnp_hardware_key(physical_index)
        .and_then(|key| {
            device_instance_id_from_pnp_key(&key)
                .ok_or_else(|| invalid_data("GPU PnP hardware key shape"))
        })
        .and_then(|instance_id| query_setupapi_details(&instance_id));
    match setup_result {
        Ok(details) => {
            metadata.driver_name = details.driver_name;
            metadata.driver_version = details.driver_version;
            metadata.driver_date = details.driver_date;
            metadata.physical_location = details.physical_location;
            if let Some(error) = details.detail_error {
                record_first_error(&mut metadata.detail_error, error);
            }
        }
        Err(error) => record_first_error(&mut metadata.detail_error, error),
    }
    Ok(metadata)
}

fn record_first_error(target: &mut Option<BackendError>, error: BackendError) {
    if target.is_none() {
        *target = Some(error);
    }
}

struct OwnedKmtAdapter {
    handle: u32,
}

impl OwnedKmtAdapter {
    fn open(luid: LUID) -> Result<Self, BackendError> {
        let mut open = D3DKMT_OPENADAPTERFROMLUID {
            AdapterLuid: luid,
            hAdapter: 0,
        };
        let status = unsafe { D3DKMTOpenAdapterFromLuid(&mut open) };
        if status < 0 {
            return Err(nt_error("D3DKMTOpenAdapterFromLuid", status));
        }
        if open.hAdapter == 0 {
            return Err(invalid_data("D3DKMTOpenAdapterFromLuid output"));
        }
        Ok(Self {
            handle: open.hAdapter,
        })
    }

    fn query<T>(&self, query_type: i32, value: &mut T, context: &str) -> Result<(), BackendError> {
        let byte_length = u32::try_from(size_of::<T>())
            .map_err(|_| invalid_data("D3DKMT query structure size"))?;
        let mut query = D3DKMT_QUERYADAPTERINFO {
            hAdapter: self.handle,
            Type: query_type,
            pPrivateDriverData: (value as *mut T).cast::<c_void>(),
            PrivateDriverDataSize: byte_length,
        };
        let status = unsafe { D3DKMTQueryAdapterInfo(&mut query) };
        if status < 0 {
            Err(nt_error(context, status))
        } else {
            Ok(())
        }
    }

    fn temperature(&self, physical_index: u32) -> Result<Option<u32>, BackendError> {
        let mut value = D3DKMT_ADAPTER_PERFDATA {
            PhysicalAdapterIndex: physical_index,
            ..D3DKMT_ADAPTER_PERFDATA::default()
        };
        self.query(
            KMTQAITYPE_ADAPTERPERFDATA,
            &mut value,
            "D3DKMT adapter performance data",
        )?;
        Ok(Some(value.Temperature))
    }

    fn installed_memory(&self, physical_index: u32) -> Result<Option<u64>, BackendError> {
        let mut value = D3DDDI_QUERYREGISTRY_INFO {
            QueryType: D3DDDI_QUERYREGISTRY_ADAPTERKEY,
            ValueName: fixed_wide_value_name(INSTALLED_MEMORY_VALUE_NAME)?,
            ValueType: REG_QWORD,
            PhysicalAdapterIndex: physical_index,
            ..D3DDDI_QUERYREGISTRY_INFO::default()
        };
        self.query(
            KMTQAITYPE_QUERYREGISTRY,
            &mut value,
            "D3DKMT installed GPU memory registry query",
        )?;
        if value.Status != D3DDDI_QUERYREGISTRY_STATUS_SUCCESS {
            return Ok(None);
        }
        if value.OutputValueSize != size_of::<u64>() as u32 {
            return Err(invalid_data("installed GPU memory registry output size"));
        }
        let result = unsafe { value.Anonymous.OutputQword };
        Ok((result > 0).then_some(result))
    }

    fn pnp_hardware_key(&self, physical_index: u32) -> Result<String, BackendError> {
        let mut char_count = 0_u32;
        let mut sizing = D3DKMT_QUERY_PHYSICAL_ADAPTER_PNP_KEY {
            PhysicalAdapterIndex: physical_index,
            PnPKeyType: D3DKMT_PNP_KEY_HARDWARE,
            pDest: null_mut(),
            pCchDest: &mut char_count,
        };
        let mut query = D3DKMT_QUERYADAPTERINFO {
            hAdapter: self.handle,
            Type: KMTQAITYPE_PHYSICALADAPTERPNPKEY,
            pPrivateDriverData: (&mut sizing as *mut D3DKMT_QUERY_PHYSICAL_ADAPTER_PNP_KEY).cast(),
            PrivateDriverDataSize: size_of::<D3DKMT_QUERY_PHYSICAL_ADAPTER_PNP_KEY>() as u32,
        };
        let status = unsafe { D3DKMTQueryAdapterInfo(&mut query) };
        if status != STATUS_BUFFER_TOO_SMALL && status != STATUS_BUFFER_OVERFLOW && status < 0 {
            return Err(nt_error("D3DKMT physical adapter PnP key size", status));
        }
        if char_count == 0 || char_count > MAX_PNP_KEY_CHARS {
            return Err(invalid_data("D3DKMT physical adapter PnP key size"));
        }

        let mut buffer = vec![0_u16; char_count as usize];
        let mut actual_count = char_count;
        let mut payload = D3DKMT_QUERY_PHYSICAL_ADAPTER_PNP_KEY {
            PhysicalAdapterIndex: physical_index,
            PnPKeyType: D3DKMT_PNP_KEY_HARDWARE,
            pDest: buffer.as_mut_ptr(),
            pCchDest: &mut actual_count,
        };
        query.pPrivateDriverData =
            (&mut payload as *mut D3DKMT_QUERY_PHYSICAL_ADAPTER_PNP_KEY).cast();
        let status = unsafe { D3DKMTQueryAdapterInfo(&mut query) };
        if status < 0 {
            return Err(nt_error("D3DKMT physical adapter PnP key", status));
        }
        if actual_count == 0 || actual_count > char_count {
            return Err(invalid_data("D3DKMT physical adapter PnP key result"));
        }
        let length = buffer[..actual_count as usize]
            .iter()
            .position(|unit| *unit == 0)
            .ok_or_else(|| invalid_data("D3DKMT physical adapter PnP key terminator"))?;
        String::from_utf16(&buffer[..length])
            .map_err(|_| invalid_data("D3DKMT physical adapter PnP key encoding"))
    }
}

impl Drop for OwnedKmtAdapter {
    fn drop(&mut self) {
        if self.handle != 0 {
            let close = D3DKMT_CLOSEADAPTER {
                hAdapter: self.handle,
            };
            let _status = unsafe { D3DKMTCloseAdapter(&close) };
            self.handle = 0;
        }
    }
}

fn fixed_wide_value_name(value: &str) -> Result<[u16; 260], BackendError> {
    let mut result = [0_u16; 260];
    for (index, unit) in value.encode_utf16().enumerate() {
        if index >= result.len() - 1 {
            return Err(invalid_data("GPU registry value name length"));
        }
        result[index] = unit;
    }
    Ok(result)
}

fn device_instance_id_from_pnp_key(value: &str) -> Option<String> {
    let normalized = value.replace('/', "\\");
    let lowercase = normalized.to_ascii_lowercase();
    let start = lowercase.find("\\enum\\")? + "\\enum\\".len();
    let mut components = normalized[start..]
        .split('\\')
        .filter(|component| !component.is_empty());
    Some(format!(
        "{}\\{}\\{}",
        components.next()?,
        components.next()?,
        components.next()?
    ))
}

#[derive(Default)]
struct SetupDetails {
    driver_name: Option<String>,
    driver_version: Option<String>,
    driver_date: Option<String>,
    physical_location: Option<String>,
    detail_error: Option<BackendError>,
}

fn query_setupapi_details(instance_id: &str) -> Result<SetupDetails, BackendError> {
    let info_set = OwnedDeviceInfoSet::display_devices()?;
    let mut device_info = SP_DEVINFO_DATA {
        cbSize: size_of::<SP_DEVINFO_DATA>() as u32,
        ..unsafe { zeroed() }
    };
    let instance_id = wide(instance_id);
    if unsafe {
        SetupDiOpenDeviceInfoW(
            info_set.0,
            instance_id.as_ptr(),
            null_mut(),
            0,
            &mut device_info,
        )
    } == 0
    {
        return Err(last_error("SetupDiOpenDeviceInfoW for GPU adapter"));
    }

    let mut details = SetupDetails::default();
    details.driver_name = optional_string_property(
        info_set.0,
        &device_info,
        &DEVPKEY_Device_DriverProvider,
        DEVPROP_TYPE_STRING,
        "GPU driver provider property",
        &mut details.detail_error,
    );
    details.driver_version = optional_string_property(
        info_set.0,
        &device_info,
        &DEVPKEY_Device_DriverVersion,
        DEVPROP_TYPE_STRING,
        "GPU driver version property",
        &mut details.detail_error,
    );
    details.driver_date = optional_filetime_property(
        info_set.0,
        &device_info,
        &DEVPKEY_Device_DriverDate,
        "GPU driver date property",
        &mut details.detail_error,
    );
    details.physical_location = optional_string_property(
        info_set.0,
        &device_info,
        &DEVPKEY_Device_LocationInfo,
        DEVPROP_TYPE_STRING,
        "GPU location property",
        &mut details.detail_error,
    )
    .or_else(|| {
        optional_string_property(
            info_set.0,
            &device_info,
            &DEVPKEY_Device_LocationPaths,
            DEVPROP_TYPE_STRING_LIST,
            "GPU location path property",
            &mut details.detail_error,
        )
    });
    Ok(details)
}

struct OwnedDeviceInfoSet(HDEVINFO);

impl OwnedDeviceInfoSet {
    fn display_devices() -> Result<Self, BackendError> {
        let value = unsafe {
            SetupDiGetClassDevsW(&GUID_DEVCLASS_DISPLAY, null(), null_mut(), DIGCF_PRESENT)
        };
        if value == INVALID_HANDLE_VALUE as isize {
            Err(last_error("SetupDiGetClassDevsW for GPU adapters"))
        } else {
            Ok(Self(value))
        }
    }
}

impl Drop for OwnedDeviceInfoSet {
    fn drop(&mut self) {
        if self.0 != 0 && self.0 != INVALID_HANDLE_VALUE as isize {
            let _result = unsafe { SetupDiDestroyDeviceInfoList(self.0) };
            self.0 = INVALID_HANDLE_VALUE as isize;
        }
    }
}

fn optional_string_property(
    info_set: HDEVINFO,
    device_info: &SP_DEVINFO_DATA,
    key: &DEVPROPKEY,
    expected_type: DEVPROPTYPE,
    context: &str,
    detail_error: &mut Option<BackendError>,
) -> Option<String> {
    match query_device_string_property(info_set, device_info, key, expected_type, context) {
        Ok(value) => value,
        Err(error) => {
            record_first_error(detail_error, error);
            None
        }
    }
}

fn optional_filetime_property(
    info_set: HDEVINFO,
    device_info: &SP_DEVINFO_DATA,
    key: &DEVPROPKEY,
    context: &str,
    detail_error: &mut Option<BackendError>,
) -> Option<String> {
    match query_device_filetime_property(info_set, device_info, key, context) {
        Ok(value) => value,
        Err(error) => {
            record_first_error(detail_error, error);
            None
        }
    }
}

fn query_device_string_property(
    info_set: HDEVINFO,
    device_info: &SP_DEVINFO_DATA,
    key: &DEVPROPKEY,
    expected_type: DEVPROPTYPE,
    context: &str,
) -> Result<Option<String>, BackendError> {
    let Some((property_type, buffer)) = query_device_property(info_set, device_info, key, context)?
    else {
        return Ok(None);
    };
    if property_type != expected_type || !buffer.len().is_multiple_of(size_of::<u16>()) {
        return Err(invalid_data(context));
    }
    let units = buffer
        .chunks_exact(2)
        .map(|bytes| u16::from_le_bytes([bytes[0], bytes[1]]))
        .collect::<Vec<_>>();
    let length = units
        .iter()
        .position(|unit| *unit == 0)
        .ok_or_else(|| invalid_data(context))?;
    if length == 0 {
        return Ok(None);
    }
    String::from_utf16(&units[..length])
        .map(Some)
        .map_err(|_| invalid_data(context))
}

fn query_device_filetime_property(
    info_set: HDEVINFO,
    device_info: &SP_DEVINFO_DATA,
    key: &DEVPROPKEY,
    context: &str,
) -> Result<Option<String>, BackendError> {
    let Some((property_type, buffer)) = query_device_property(info_set, device_info, key, context)?
    else {
        return Ok(None);
    };
    if property_type != DEVPROP_TYPE_FILETIME || buffer.len() != size_of::<FILETIME>() {
        return Err(invalid_data(context));
    }
    let filetime = unsafe { buffer.as_ptr().cast::<FILETIME>().read_unaligned() };
    let mut system_time = SYSTEMTIME::default();
    if unsafe { FileTimeToSystemTime(&filetime, &mut system_time) } == 0 {
        return Err(last_error(context));
    }
    Ok(Some(format!(
        "{:04}-{:02}-{:02}",
        system_time.wYear, system_time.wMonth, system_time.wDay
    )))
}

fn query_device_property(
    info_set: HDEVINFO,
    device_info: &SP_DEVINFO_DATA,
    key: &DEVPROPKEY,
    context: &str,
) -> Result<Option<(DEVPROPTYPE, Vec<u8>)>, BackendError> {
    let mut property_type = 0_u32;
    let mut required_size = 0_u32;
    if unsafe {
        SetupDiGetDevicePropertyW(
            info_set,
            device_info,
            key,
            &mut property_type,
            null_mut(),
            0,
            &mut required_size,
            0,
        )
    } == 0
    {
        let error = unsafe { GetLastError() };
        if error == ERROR_NOT_FOUND {
            return Ok(None);
        }
        if error != ERROR_INSUFFICIENT_BUFFER {
            return Err(win32_error(context, error));
        }
    }
    if required_size == 0 || required_size > MAX_DEVICE_PROPERTY_BYTES {
        return Err(invalid_data(context));
    }
    let mut buffer = vec![0_u8; required_size as usize];
    if unsafe {
        SetupDiGetDevicePropertyW(
            info_set,
            device_info,
            key,
            &mut property_type,
            buffer.as_mut_ptr(),
            required_size,
            &mut required_size,
            0,
        )
    } == 0
    {
        return Err(last_error(context));
    }
    if required_size as usize > buffer.len() {
        return Err(invalid_data(context));
    }
    buffer.truncate(required_size as usize);
    Ok(Some((property_type, buffer)))
}

fn wide(value: &str) -> Vec<u16> {
    value.encode_utf16().chain([0]).collect()
}

fn last_error(context: &str) -> BackendError {
    let code = unsafe { GetLastError() };
    win32_error(
        context,
        if code == ERROR_SUCCESS {
            ERROR_GEN_FAILURE
        } else {
            code
        },
    )
}

fn win32_error(context: &str, code: u32) -> BackendError {
    BackendError {
        domain: "win32".to_string(),
        code: i64::from(code),
        context: context.to_string(),
        message: format!("Win32 error {code}"),
    }
}

fn nt_error(context: &str, status: i32) -> BackendError {
    BackendError {
        domain: "ntstatus".to_string(),
        code: i64::from(status),
        context: context.to_string(),
        message: format!("NTSTATUS 0x{:08X}", status as u32),
    }
}

fn invalid_data(context: &str) -> BackendError {
    BackendError {
        domain: "win32".to_string(),
        code: -1,
        context: context.to_string(),
        message: "invalid GPU adapter metadata".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{device_instance_id_from_pnp_key, fixed_wide_value_name};

    #[test]
    fn extracts_device_instance_from_registry_hardware_key() {
        assert_eq!(
            device_instance_id_from_pnp_key(
                r"\Registry\Machine\System\CurrentControlSet\Enum\PCI\VEN_1002&DEV_744C\6&abc&0&00000019"
            ),
            Some(r"PCI\VEN_1002&DEV_744C\6&abc&0&00000019".to_string())
        );
    }

    #[test]
    fn fixed_registry_name_is_terminated_without_truncation() {
        let value = fixed_wide_value_name("Memory").expect("valid name");
        assert_eq!(&value[..7], &[77, 101, 109, 111, 114, 121, 0]);
    }
}
