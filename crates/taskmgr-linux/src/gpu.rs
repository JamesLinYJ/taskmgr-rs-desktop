// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux DRM GPU 采样
//
//   文件:       crates/taskmgr-linux/src/gpu.rs
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Linux DRM sysfs ABI；NVML；Vulkan VK_EXT_pci_bus_info
// --------------------------------------------------------------------------

//! 以 DRM sysfs 作为 Linux GPU 清单的唯一来源。
//!
//! 内核驱动公开指标时直接读取 sysfs；NVIDIA DRM 不公开的利用率、显存和温度通过
//! NVML 正式 ABI 补齐。Vulkan 设备只在 `VK_EXT_pci_bus_info` 给出完全一致的 PCI
//! 地址时关联，绝不根据枚举顺序或名称猜测。

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

use taskmgr_core::{
    BackendError, GpuAdapter, GpuData, GpuDriverModel, GpuEngine, GpuEngineKind, HISTORY_CAPACITY,
    HistoryBuffer, SnapshotData,
};

use crate::nvml::{Nvml, NvmlMetrics};
use crate::vulkan::{self, VulkanDevice};

struct AdapterHistory {
    utilization: HistoryBuffer,
    dedicated: HistoryBuffer,
    shared: HistoryBuffer,
    engines: HashMap<String, HistoryBuffer>,
}

impl AdapterHistory {
    fn new() -> Self {
        Self {
            utilization: HistoryBuffer::new(HISTORY_CAPACITY),
            dedicated: HistoryBuffer::new(HISTORY_CAPACITY),
            shared: HistoryBuffer::new(HISTORY_CAPACITY),
            engines: HashMap::new(),
        }
    }
}

struct EngineSample {
    id: &'static str,
    kind: GpuEngineKind,
    utilization: Option<f64>,
}

enum NvmlState {
    Available(Nvml),
    Unavailable(String),
}

pub struct GpuSampler {
    histories: HashMap<String, AdapterHistory>,
    nvml: NvmlState,
    vulkan_devices: HashMap<String, VulkanDevice>,
}

impl GpuSampler {
    pub fn new() -> Self {
        Self {
            histories: HashMap::new(),
            nvml: match Nvml::load() {
                Ok(nvml) => NvmlState::Available(nvml),
                Err(error) => NvmlState::Unavailable(error),
            },
            vulkan_devices: vulkan::discover().unwrap_or_default(),
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let root = Path::new("/sys/class/drm");
        let entries = fs::read_dir(root)
            .map_err(|error| BackendError::io("enumerate /sys/class/drm", &error))?;
        let mut adapters = Vec::new();
        let mut live = HashSet::new();

        for entry in entries.filter_map(Result::ok) {
            let card_id = entry.file_name().to_string_lossy().into_owned();
            if !is_card_name(&card_id) {
                continue;
            }
            let device = entry.path().join("device");
            if !device.exists() {
                continue;
            }

            live.insert(card_id.clone());
            let uevent = fs::read_to_string(device.join("uevent")).unwrap_or_default();
            let driver = field(&uevent, "DRIVER");
            let pci_id = field(&uevent, "PCI_ID");
            let pci_address = field(&uevent, "PCI_SLOT_NAME");
            let vulkan = pci_address
                .as_ref()
                .and_then(|address| self.vulkan_devices.get(address));

            let mut name = inventory_name(&card_id, driver.as_deref(), pci_id.as_deref());
            if let Some(vulkan_name) = vulkan.map(|device| device.name.trim())
                && !vulkan_name.is_empty()
            {
                name = vulkan_name.to_string();
            }

            let mut utilization = read_percent(device.join("gpu_busy_percent"))
                .or_else(|| read_percent(device.join("gt_busy_percent")));
            let mut dedicated_used = read_u64(device.join("mem_info_vram_used"));
            let mut dedicated_total = read_u64(device.join("mem_info_vram_total"));
            let shared_used = read_u64(device.join("mem_info_gtt_used"));
            let shared_total = read_u64(device.join("mem_info_gtt_total"));
            let mut temperature = read_temperature(&device);
            let mut driver_version = read_trimmed(device.join("driver/module/version"));
            let mut nvml_error = None;
            let mut engine_samples = vec![EngineSample {
                id: "overall",
                kind: GpuEngineKind::Overall,
                utilization,
            }];

            if driver.as_deref() == Some("nvidia") {
                match self.sample_nvml(pci_address.as_deref()) {
                    Ok(metrics) => {
                        if let Some(value) = metrics.name.clone() {
                            name = value;
                        }
                        utilization = metrics.gpu_utilization.or(utilization);
                        dedicated_used = metrics.memory_used.or(dedicated_used);
                        dedicated_total = metrics.memory_total.or(dedicated_total);
                        temperature = metrics.temperature_celsius.or(temperature);
                        driver_version = metrics.driver_version.clone().or(driver_version);
                        engine_samples = nvidia_engines(&metrics, utilization);
                    }
                    Err(error) => nvml_error = Some(error),
                }
            }

            let (primary_device_node, render_device_node) = drm_device_nodes(&device, &card_id);
            let history = self
                .histories
                .entry(card_id.clone())
                .or_insert_with(AdapterHistory::new);
            push_optional(&mut history.utilization, utilization);
            push_optional(
                &mut history.dedicated,
                memory_percent(dedicated_used, dedicated_total),
            );
            push_optional(
                &mut history.shared,
                memory_percent(shared_used, shared_total),
            );

            let engine_ids = engine_samples
                .iter()
                .map(|engine| engine.id)
                .collect::<HashSet<_>>();
            history
                .engines
                .retain(|id, _| engine_ids.contains(id.as_str()));
            let engines = engine_samples
                .into_iter()
                .map(|engine| {
                    let engine_history = history
                        .engines
                        .entry(engine.id.to_string())
                        .or_insert_with(|| HistoryBuffer::new(HISTORY_CAPACITY));
                    push_optional(engine_history, engine.utilization);
                    GpuEngine {
                        id: engine.id.to_string(),
                        kind: engine.kind,
                        ordinal: None,
                        name: None,
                        utilization_percent: engine.utilization,
                        history: engine_history.snapshot(),
                    }
                })
                .collect();

            let has_runtime_metrics = utilization.is_some()
                || dedicated_total.is_some()
                || shared_total.is_some()
                || temperature.is_some();
            let detail_error = if let Some(error) = nvml_error {
                Some(BackendError::internal("query NVIDIA NVML metrics", error))
            } else if !has_runtime_metrics {
                Some(BackendError::unsupported(
                    "DRM adapter metrics",
                    "the kernel driver exposes inventory but no utilization, memory, or temperature metrics",
                ))
            } else {
                None
            };

            adapters.push(GpuAdapter {
                id: card_id,
                name,
                driver_model: GpuDriverModel::LinuxDrm,
                utilization_percent: utilization,
                dedicated_used_bytes: dedicated_used,
                dedicated_total_bytes: dedicated_total,
                shared_used_bytes: shared_used,
                shared_total_bytes: shared_total,
                temperature_celsius: temperature,
                driver_name: driver,
                driver_version,
                driver_date: None,
                graphics_api: vulkan.map(|device| device.api_version.clone()),
                physical_location: pci_address,
                primary_device_node,
                render_device_node,
                hardware_reserved_bytes: None,
                engines,
                dedicated_usage_history_percent: history.dedicated.snapshot(),
                shared_usage_history_percent: history.shared.snapshot(),
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

    fn sample_nvml(&self, pci_address: Option<&str>) -> Result<NvmlMetrics, String> {
        let pci_address = pci_address.ok_or_else(|| {
            "DRM did not expose PCI_SLOT_NAME, so the NVIDIA device cannot be matched safely"
                .to_string()
        })?;
        match &self.nvml {
            NvmlState::Available(nvml) => nvml.sample(pci_address),
            NvmlState::Unavailable(error) => Err(error.clone()),
        }
    }
}

impl Default for GpuSampler {
    fn default() -> Self {
        Self::new()
    }
}

fn nvidia_engines(metrics: &NvmlMetrics, overall: Option<f64>) -> Vec<EngineSample> {
    let candidates = [
        EngineSample {
            id: "overall",
            kind: GpuEngineKind::Overall,
            utilization: overall,
        },
        EngineSample {
            id: "memory",
            kind: GpuEngineKind::Memory,
            utilization: metrics.memory_utilization,
        },
        EngineSample {
            id: "video-encode",
            kind: GpuEngineKind::VideoEncode,
            utilization: metrics.encoder_utilization,
        },
        EngineSample {
            id: "video-decode",
            kind: GpuEngineKind::VideoDecode,
            utilization: metrics.decoder_utilization,
        },
    ];
    candidates
        .into_iter()
        .filter(|engine| engine.id == "overall" || engine.utilization.is_some())
        .collect()
}

fn inventory_name(card_id: &str, driver: Option<&str>, pci_id: Option<&str>) -> String {
    match (driver, pci_id) {
        (Some(driver), Some(pci_id)) => format!("{driver} ({pci_id})"),
        (Some(driver), None) => driver.to_string(),
        _ => card_id.to_string(),
    }
}

fn drm_device_nodes(device: &Path, card_id: &str) -> (Option<String>, Option<String>) {
    let mut primary = None;
    let mut render = None;
    if let Ok(entries) = fs::read_dir(device.join("drm")) {
        for entry in entries.filter_map(Result::ok) {
            let name = entry.file_name().to_string_lossy().into_owned();
            if name == card_id {
                primary = Some(format!("/dev/dri/{name}"));
            } else if is_render_name(&name) {
                render = Some(format!("/dev/dri/{name}"));
            }
        }
    }
    (primary, render)
}

fn is_card_name(name: &str) -> bool {
    numeric_suffix(name, "card")
}

fn is_render_name(name: &str) -> bool {
    numeric_suffix(name, "renderD")
}

fn numeric_suffix(name: &str, prefix: &str) -> bool {
    name.strip_prefix(prefix).is_some_and(|suffix| {
        !suffix.is_empty() && suffix.bytes().all(|byte| byte.is_ascii_digit())
    })
}

fn field(text: &str, name: &str) -> Option<String> {
    let prefix = format!("{name}=");
    text.lines()
        .find_map(|line| line.strip_prefix(&prefix).map(str::to_string))
}

fn read_trimmed(path: PathBuf) -> Option<String> {
    let value = fs::read_to_string(path).ok()?.trim().to_string();
    (!value.is_empty()).then_some(value)
}

fn read_u64(path: impl AsRef<Path>) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_number(path: impl AsRef<Path>) -> Option<f64> {
    let value: f64 = fs::read_to_string(path).ok()?.trim().parse().ok()?;
    value.is_finite().then_some(value)
}

fn read_percent(path: impl AsRef<Path>) -> Option<f64> {
    let value = read_number(path)?;
    (0.0..=100.0).contains(&value).then_some(value)
}

fn read_temperature(device: &Path) -> Option<f64> {
    let hwmon = fs::read_dir(device.join("hwmon")).ok()?;
    for entry in hwmon.filter_map(Result::ok) {
        if let Some(value) = read_number(entry.path().join("temp1_input")) {
            return Some(value / 1_000.0);
        }
    }
    None
}

fn memory_percent(used: Option<u64>, total: Option<u64>) -> Option<f64> {
    let (used, total) = (used?, total?);
    (total > 0).then(|| (used as f64 * 100.0 / total as f64).clamp(0.0, 100.0))
}

fn push_optional(history: &mut HistoryBuffer, value: Option<f64>) {
    if let Some(value) = value {
        history.push(value);
    }
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::{drm_device_nodes, field, inventory_name, is_card_name, is_render_name};

    #[test]
    fn accepts_only_primary_drm_card_names() {
        assert!(is_card_name("card0"));
        assert!(is_card_name("card12"));
        assert!(!is_card_name("card0-DP-1"));
        assert!(!is_card_name("renderD128"));
        assert!(!is_card_name("card"));
    }

    #[test]
    fn recognizes_render_node_names() {
        assert!(is_render_name("renderD128"));
        assert!(!is_render_name("renderD"));
        assert!(!is_render_name("card1"));
    }

    #[test]
    fn parses_exact_uevent_fields() {
        let text = "DRIVER=nvidia\nPCI_ID=10DE:2D59\nPCI_SLOT_NAME=0000:01:00.0\n";
        assert_eq!(field(text, "DRIVER").as_deref(), Some("nvidia"));
        assert_eq!(
            field(text, "PCI_SLOT_NAME").as_deref(),
            Some("0000:01:00.0")
        );
        assert_eq!(field(text, "PCI"), None);
    }

    #[test]
    fn uses_driver_and_pci_id_for_inventory_fallback() {
        assert_eq!(
            inventory_name("card1", Some("nvidia"), Some("10DE:2D59")),
            "nvidia (10DE:2D59)"
        );
    }

    #[test]
    fn discovers_primary_and_render_nodes_from_drm_inventory() {
        let root = tempdir().expect("temporary directory");
        let drm = root.path().join("drm");
        fs::create_dir_all(drm.join("card1")).expect("card directory");
        fs::create_dir_all(drm.join("renderD128")).expect("render directory");
        let (primary, render) = drm_device_nodes(root.path(), "card1");
        assert_eq!(primary.as_deref(), Some("/dev/dri/card1"));
        assert_eq!(render.as_deref(), Some("/dev/dri/renderD128"));
    }
}
