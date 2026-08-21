// +-------------------------------------------------------------------------
//
//   taskmgr-rs - NVIDIA NVML 指标适配器
//
//   文件:       crates/taskmgr-linux/src/nvml.rs
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；NVIDIA 610.57.04；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   NVIDIA Management Library API；System V AMD64 ABI；AArch64 PCS
// --------------------------------------------------------------------------

//! 通过运行时加载的 NVML 查询 NVIDIA 驱动未在 DRM sysfs 暴露的真实指标。
//! `Library` 的生命周期覆盖全部函数指针，所有 C 缓冲区固定有界且仅在成功后读取。

use std::ffi::{CString, c_char, c_int, c_uint, c_void};

use libloading::Library;

use crate::c_text::BoundedCText;

const NVML_SUCCESS: c_int = 0;
const NVML_TEMPERATURE_GPU: c_uint = 0;
const TEXT_BUFFER_BYTES: usize = 256;

type NvmlDevice = *mut c_void;
type InitFn = unsafe extern "C" fn() -> c_int;
type ShutdownFn = unsafe extern "C" fn() -> c_int;
type DeviceByPciFn = unsafe extern "C" fn(*const c_char, *mut NvmlDevice) -> c_int;
type DeviceNameFn = unsafe extern "C" fn(NvmlDevice, *mut c_char, c_uint) -> c_int;
type DriverVersionFn = unsafe extern "C" fn(*mut c_char, c_uint) -> c_int;
type UtilizationFn = unsafe extern "C" fn(NvmlDevice, *mut NvmlUtilization) -> c_int;
type MemoryInfoFn = unsafe extern "C" fn(NvmlDevice, *mut NvmlMemory) -> c_int;
type TemperatureFn = unsafe extern "C" fn(NvmlDevice, c_uint, *mut c_uint) -> c_int;
type CodecUtilizationFn = unsafe extern "C" fn(NvmlDevice, *mut c_uint, *mut c_uint) -> c_int;

#[repr(C)]
#[derive(Default)]
struct NvmlUtilization {
    gpu: c_uint,
    memory: c_uint,
}

#[repr(C)]
#[derive(Default)]
struct NvmlMemory {
    total: u64,
    free: u64,
    used: u64,
}

pub(crate) struct NvmlMetrics {
    pub(crate) name: Option<String>,
    pub(crate) driver_version: Option<String>,
    pub(crate) gpu_utilization: Option<f64>,
    pub(crate) memory_utilization: Option<f64>,
    pub(crate) encoder_utilization: Option<f64>,
    pub(crate) decoder_utilization: Option<f64>,
    pub(crate) memory_used: Option<u64>,
    pub(crate) memory_total: Option<u64>,
    pub(crate) temperature_celsius: Option<f64>,
}

pub(crate) struct Nvml {
    _library: Library,
    shutdown: ShutdownFn,
    device_by_pci: DeviceByPciFn,
    device_name: DeviceNameFn,
    driver_version: DriverVersionFn,
    utilization: UtilizationFn,
    memory_info: MemoryInfoFn,
    temperature: TemperatureFn,
    encoder_utilization: CodecUtilizationFn,
    decoder_utilization: CodecUtilizationFn,
}

impl Nvml {
    pub(crate) fn load() -> Result<Self, String> {
        // SAFETY: the requested SONAME is the stable NVML ABI library. It remains owned by
        // `Nvml` until after `nvmlShutdown`, so copied function pointers cannot outlive it.
        let library = unsafe { Library::new("libnvidia-ml.so.1") }
            .map_err(|error| format!("load libnvidia-ml.so.1: {error}"))?;
        let init: InitFn = load_symbol(&library, b"nvmlInit_v2\0")?;
        let shutdown = load_symbol(&library, b"nvmlShutdown\0")?;
        let device_by_pci = load_symbol(&library, b"nvmlDeviceGetHandleByPciBusId_v2\0")?;
        let device_name = load_symbol(&library, b"nvmlDeviceGetName\0")?;
        let driver_version = load_symbol(&library, b"nvmlSystemGetDriverVersion\0")?;
        let utilization = load_symbol(&library, b"nvmlDeviceGetUtilizationRates\0")?;
        let memory_info = load_symbol(&library, b"nvmlDeviceGetMemoryInfo\0")?;
        let temperature = load_symbol(&library, b"nvmlDeviceGetTemperature\0")?;
        let encoder_utilization = load_symbol(&library, b"nvmlDeviceGetEncoderUtilization\0")?;
        let decoder_utilization = load_symbol(&library, b"nvmlDeviceGetDecoderUtilization\0")?;
        // SAFETY: `init` has the exact NVML signature and requires no arguments.
        check("nvmlInit_v2", unsafe { init() })?;
        Ok(Self {
            _library: library,
            shutdown,
            device_by_pci,
            device_name,
            driver_version,
            utilization,
            memory_info,
            temperature,
            encoder_utilization,
            decoder_utilization,
        })
    }

    pub(crate) fn sample(&self, pci_address: &str) -> Result<NvmlMetrics, String> {
        let pci_address = CString::new(pci_address)
            .map_err(|_| "PCI address contains an embedded NUL".to_string())?;
        let mut device = std::ptr::null_mut();
        // SAFETY: the C string is NUL terminated and `device` is writable for one handle.
        check("nvmlDeviceGetHandleByPciBusId_v2", unsafe {
            (self.device_by_pci)(pci_address.as_ptr(), &mut device)
        })?;
        if device.is_null() {
            return Err("NVML returned a null device handle".to_string());
        }

        let name = query_text(device, self.device_name);
        let driver_version = query_driver_version(self.driver_version);
        let mut utilization = NvmlUtilization::default();
        // SAFETY: `device` came from NVML and the output structure matches nvmlUtilization_t.
        let utilization_result = unsafe { (self.utilization)(device, &mut utilization) };
        let (gpu_utilization, memory_utilization) = if utilization_result == NVML_SUCCESS {
            (
                valid_percent(utilization.gpu),
                valid_percent(utilization.memory),
            )
        } else {
            (None, None)
        };
        let mut memory = NvmlMemory::default();
        // SAFETY: `memory` matches the stable nvmlMemory_t layout.
        let memory_result = unsafe { (self.memory_info)(device, &mut memory) };
        let (memory_used, memory_total) = if memory_result == NVML_SUCCESS {
            (Some(memory.used), Some(memory.total))
        } else {
            (None, None)
        };
        let mut temperature = 0;
        // SAFETY: the sensor enum is NVML_TEMPERATURE_GPU and output is writable.
        let temperature_result =
            unsafe { (self.temperature)(device, NVML_TEMPERATURE_GPU, &mut temperature) };

        Ok(NvmlMetrics {
            name,
            driver_version,
            gpu_utilization,
            memory_utilization,
            encoder_utilization: query_codec(device, self.encoder_utilization),
            decoder_utilization: query_codec(device, self.decoder_utilization),
            memory_used,
            memory_total,
            temperature_celsius: (temperature_result == NVML_SUCCESS)
                .then_some(f64::from(temperature)),
        })
    }
}

impl Drop for Nvml {
    fn drop(&mut self) {
        // SAFETY: NVML was initialized successfully and the library is still loaded here.
        let _ = unsafe { (self.shutdown)() };
    }
}

fn load_symbol<T: Copy>(library: &Library, symbol: &[u8]) -> Result<T, String> {
    // SAFETY: each call site supplies the exact C ABI function-pointer type for the named NVML
    // symbol. The returned pointer is copied while `library` remains owned by `Nvml`.
    unsafe { library.get::<T>(symbol) }
        .map(|value| *value)
        .map_err(|error| {
            let name = String::from_utf8_lossy(symbol)
                .trim_end_matches('\0')
                .to_string();
            format!("load {name}: {error}")
        })
}

fn query_text(device: NvmlDevice, function: DeviceNameFn) -> Option<String> {
    let mut buffer = [0 as c_char; TEXT_BUFFER_BYTES];
    // SAFETY: the device is valid and the function receives the exact writable buffer length.
    let result = unsafe { function(device, buffer.as_mut_ptr(), buffer.len() as c_uint) };
    (result == NVML_SUCCESS)
        .then(|| BoundedCText::new(&buffer).decode_nul_terminated())
        .flatten()
}

fn query_driver_version(function: DriverVersionFn) -> Option<String> {
    let mut buffer = [0 as c_char; TEXT_BUFFER_BYTES];
    // SAFETY: the function receives the exact writable buffer length.
    let result = unsafe { function(buffer.as_mut_ptr(), buffer.len() as c_uint) };
    (result == NVML_SUCCESS)
        .then(|| BoundedCText::new(&buffer).decode_nul_terminated())
        .flatten()
}

fn query_codec(device: NvmlDevice, function: CodecUtilizationFn) -> Option<f64> {
    let mut utilization = 0;
    let mut sampling_period = 0;
    // SAFETY: both output pointers are valid for one unsigned integer.
    let result = unsafe { function(device, &mut utilization, &mut sampling_period) };
    (result == NVML_SUCCESS)
        .then(|| valid_percent(utilization))
        .flatten()
}

fn valid_percent(value: c_uint) -> Option<f64> {
    (value <= 100).then_some(f64::from(value))
}

fn check(operation: &str, result: c_int) -> Result<(), String> {
    if result == NVML_SUCCESS {
        Ok(())
    } else {
        Err(format!("{operation} failed with NVML status {result}"))
    }
}
