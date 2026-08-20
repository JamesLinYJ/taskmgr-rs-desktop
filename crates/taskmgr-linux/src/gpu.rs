// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux DRM GPU 采样
//
//   文件:       crates/taskmgr-linux/src/gpu.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Linux DRM sysfs ABI；Documentation/ABI/testing/sysfs-driver-amdgpu
// --------------------------------------------------------------------------

//! 枚举 DRM card，并只读取驱动实际公开的已知 sysfs 指标。

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;

use taskmgr_core::{
    BackendError, GpuAdapter, GpuData, GpuEngine, HISTORY_CAPACITY, HistoryBuffer, SnapshotData,
};

struct AdapterHistory {
    utilization: HistoryBuffer,
    dedicated: HistoryBuffer,
    shared: HistoryBuffer,
}

pub struct GpuSampler {
    histories: HashMap<String, AdapterHistory>,
}

impl GpuSampler {
    pub fn new() -> Self {
        Self {
            histories: HashMap::new(),
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let root = Path::new("/sys/class/drm");
        let entries = fs::read_dir(root)
            .map_err(|error| BackendError::io("enumerate /sys/class/drm", &error))?;
        let mut adapters = Vec::new();
        let mut live = HashSet::new();
        for entry in entries.filter_map(Result::ok) {
            let id = entry.file_name().to_string_lossy().into_owned();
            if !is_card_name(&id) {
                continue;
            }
            let device = entry.path().join("device");
            if !device.exists() {
                continue;
            }
            live.insert(id.clone());
            let uevent = fs::read_to_string(device.join("uevent")).unwrap_or_default();
            let driver = field(&uevent, "DRIVER");
            let pci_id = field(&uevent, "PCI_ID");
            let slot = field(&uevent, "PCI_SLOT_NAME");
            let name = match (&driver, &pci_id) {
                (Some(driver), Some(pci_id)) => format!("{driver} ({pci_id})"),
                (Some(driver), None) => driver.clone(),
                _ => id.clone(),
            };
            let utilization = read_number(device.join("gpu_busy_percent"))
                .or_else(|| read_number(device.join("gt_busy_percent")));
            let dedicated_used = read_u64(device.join("mem_info_vram_used"));
            let dedicated_total = read_u64(device.join("mem_info_vram_total"));
            let shared_used = read_u64(device.join("mem_info_gtt_used"));
            let shared_total = read_u64(device.join("mem_info_gtt_total"));
            let temperature = read_temperature(&device);
            let version = fs::read_to_string(device.join("driver/module/version"))
                .ok()
                .map(|value| value.trim().to_string());
            let history = self
                .histories
                .entry(id.clone())
                .or_insert_with(|| AdapterHistory {
                    utilization: HistoryBuffer::new(HISTORY_CAPACITY),
                    dedicated: HistoryBuffer::new(HISTORY_CAPACITY),
                    shared: HistoryBuffer::new(HISTORY_CAPACITY),
                });
            if let Some(value) = utilization {
                history.utilization.push(value);
            }
            if let Some(value) = dedicated_used {
                history.dedicated.push(value as f64);
            }
            if let Some(value) = shared_used {
                history.shared.push(value as f64);
            }
            let detail_error = (utilization.is_none()
                && dedicated_total.is_none()
                && temperature.is_none())
                .then(|| {
                    BackendError::unsupported(
                        "DRM adapter metrics",
                        "the kernel driver exposes inventory but no utilization, memory, or temperature metrics",
                    )
                });
            adapters.push(GpuAdapter {
                id,
                name,
                utilization_percent: utilization,
                dedicated_used_bytes: dedicated_used,
                dedicated_total_bytes: dedicated_total,
                shared_used_bytes: shared_used,
                shared_total_bytes: shared_total,
                temperature_celsius: temperature,
                driver_version: version,
                driver_date: None,
                graphics_api: driver.map(|driver| format!("DRM/{driver}")),
                physical_location: slot,
                hardware_reserved_bytes: None,
                engines: vec![GpuEngine {
                    name: "3D".to_string(),
                    utilization_percent: utilization,
                    history: history.utilization.snapshot(),
                }],
                dedicated_history: history.dedicated.snapshot(),
                shared_history: history.shared.snapshot(),
                detail_error,
            });
        }
        self.histories.retain(|id, _| live.contains(id));
        adapters.sort_by(|left, right| left.id.cmp(&right.id));
        let selected_adapter = (!adapters.is_empty()).then_some(0);
        Ok(SnapshotData::Gpu(GpuData {
            adapters,
            selected_adapter,
        }))
    }
}

impl Default for GpuSampler {
    fn default() -> Self {
        Self::new()
    }
}

fn is_card_name(name: &str) -> bool {
    name.strip_prefix("card").is_some_and(|suffix| {
        !suffix.is_empty() && suffix.bytes().all(|byte| byte.is_ascii_digit())
    })
}

fn field(text: &str, name: &str) -> Option<String> {
    let prefix = format!("{name}=");
    text.lines()
        .find_map(|line| line.strip_prefix(&prefix).map(str::to_string))
}

fn read_u64(path: impl AsRef<Path>) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_number(path: impl AsRef<Path>) -> Option<f64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_temperature(device: &Path) -> Option<f64> {
    let hwmon = fs::read_dir(device.join("hwmon")).ok()?;
    for entry in hwmon.filter_map(Result::ok) {
        let value = read_number(entry.path().join("temp1_input"));
        if let Some(value) = value {
            return Some(value / 1_000.0);
        }
    }
    None
}
