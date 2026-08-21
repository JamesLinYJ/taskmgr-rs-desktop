// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台快照与操作模型
//
//   文件:       crates/taskmgr-core/src/model.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Rust 标准库；Serde 数据模型；项目 FRB 协议 v1
// --------------------------------------------------------------------------

//! 定义 Rust 平台后端、FRB 和 Flutter UI 共享的值类型。
//!
//! 缺失指标始终使用 `Option`；空集合仅表示一次成功采样确实没有对象。采样失败通过
//! [`SnapshotMeta::error`] 或 [`BackendEvent::PageUnavailable`] 明确传递。

use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u16 = 1;
pub const SETTINGS_SCHEMA_VERSION: u16 = 3;
pub const HISTORY_CAPACITY: usize = 120;
pub const ORIGINAL_MAIN_WINDOW_WIDTH: f64 = 396.0;
pub const ORIGINAL_MAIN_WINDOW_HEIGHT: f64 = 401.0;

const PREVIOUS_MAIN_WINDOW_WIDTH: f64 = 600.0;
const PREVIOUS_MAIN_WINDOW_HEIGHT: f64 = 430.0;

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PageId {
    Applications,
    Processes,
    Performance,
    Cpu,
    Gpu,
    Network,
    Users,
}

impl PageId {
    pub const ALL: [Self; 7] = [
        Self::Applications,
        Self::Processes,
        Self::Performance,
        Self::Cpu,
        Self::Gpu,
        Self::Network,
        Self::Users,
    ];
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PlatformKind {
    Windows,
    Linux,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Architecture {
    X86_64,
    Arm64,
    Unknown,
}

impl Architecture {
    pub fn current() -> Self {
        match std::env::consts::ARCH {
            "x86_64" => Self::X86_64,
            "aarch64" => Self::Arm64,
            _ => Self::Unknown,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Availability {
    Supported,
    Partial,
    Unsupported,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ColumnId {
    Task,
    Status,
    WindowStation,
    Desktop,
    ImageName,
    Pid,
    UserName,
    SessionId,
    Cpu,
    CpuTime,
    MemoryUsage,
    MemoryDelta,
    PageFaults,
    PageFaultsDelta,
    VirtualMemory,
    PagedPool,
    NonPagedPool,
    BasePriority,
    HandleCount,
    ThreadCount,
    FileDescriptorCount,
    Nice,
    Cgroup,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionKind {
    Refresh,
    RunTask,
    SwitchTo,
    BringToFront,
    Minimize,
    Maximize,
    TileHorizontally,
    TileVertically,
    Cascade,
    EndTask,
    EndProcess,
    EndProcessTree,
    SetPriority,
    SetNice,
    SetAffinity,
    OpenFileLocation,
    DisconnectSession,
    LogoffSession,
    SendMessage,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct PageCapability {
    pub page: PageId,
    pub availability: Availability,
    pub columns: Vec<ColumnId>,
    pub actions: Vec<ActionKind>,
    pub detail: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct PlatformCapabilities {
    pub protocol_version: u16,
    pub platform: PlatformKind,
    pub architecture: Architecture,
    pub pages: Vec<PageCapability>,
    pub privileged_details: Availability,
    pub tray: Availability,
    pub compositor: Option<String>,
    /// 当前平台后端可安全用于进程亲和性动作的逻辑处理器索引。
    pub logical_processors: Vec<u32>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum UpdateSpeed {
    High,
    Normal,
    Low,
    Paused,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ApplicationViewMode {
    LargeIcons,
    SmallIcons,
    #[default]
    Details,
}

impl UpdateSpeed {
    pub const fn interval_millis(self) -> Option<u64> {
        match self {
            Self::High => Some(500),
            Self::Normal => Some(2_000),
            Self::Low => Some(4_000),
            Self::Paused => None,
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct BackendOptions {
    pub update_speed: UpdateSpeed,
    pub active_page: PageId,
    pub include_privileged_details: bool,
}

impl Default for BackendOptions {
    fn default() -> Self {
        Self {
            update_speed: UpdateSpeed::Normal,
            active_page: PageId::Applications,
            include_privileged_details: false,
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct WindowGeometry {
    pub x: Option<f64>,
    pub y: Option<f64>,
    pub width: f64,
    pub height: f64,
    pub maximized: bool,
}

impl Default for WindowGeometry {
    fn default() -> Self {
        Self {
            x: None,
            y: None,
            width: ORIGINAL_MAIN_WINDOW_WIDTH,
            height: ORIGINAL_MAIN_WINDOW_HEIGHT,
            maximized: false,
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct ColumnLayout {
    pub column: ColumnId,
    pub width: f64,
    pub visible: bool,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct UiSettings {
    pub schema_version: u16,
    pub locale: Option<String>,
    pub active_page: PageId,
    pub update_speed: UpdateSpeed,
    pub always_on_top: bool,
    pub minimize_on_use: bool,
    pub confirmations: bool,
    pub hide_when_minimized: bool,
    pub show_kernel_times: bool,
    pub one_graph_per_cpu: bool,
    #[serde(default)]
    pub tiny_footprint: bool,
    #[serde(default)]
    pub application_view_mode: ApplicationViewMode,
    pub window: WindowGeometry,
    pub process_columns: Vec<ColumnLayout>,
}

impl Default for UiSettings {
    fn default() -> Self {
        Self {
            schema_version: SETTINGS_SCHEMA_VERSION,
            locale: None,
            active_page: PageId::Applications,
            update_speed: UpdateSpeed::Normal,
            always_on_top: false,
            minimize_on_use: false,
            confirmations: true,
            hide_when_minimized: false,
            show_kernel_times: false,
            // The archived Task Manager defaults to one history pane per logical processor.
            one_graph_per_cpu: true,
            tiny_footprint: false,
            application_view_mode: ApplicationViewMode::Details,
            window: WindowGeometry::default(),
            process_columns: vec![
                ColumnLayout {
                    column: ColumnId::ImageName,
                    width: 107.0,
                    visible: true,
                },
                ColumnLayout {
                    column: ColumnId::Pid,
                    width: 50.0,
                    visible: true,
                },
                ColumnLayout {
                    column: ColumnId::Cpu,
                    width: 35.0,
                    visible: true,
                },
                ColumnLayout {
                    column: ColumnId::CpuTime,
                    width: 70.0,
                    visible: true,
                },
                ColumnLayout {
                    column: ColumnId::MemoryUsage,
                    width: 70.0,
                    visible: true,
                },
                ColumnLayout {
                    column: ColumnId::UserName,
                    width: 107.0,
                    visible: true,
                },
            ],
        }
    }
}

impl UiSettings {
    pub fn normalize(mut self) -> Self {
        let source_schema = self.schema_version;
        if source_schema < SETTINGS_SCHEMA_VERSION
            && self.window.width == PREVIOUS_MAIN_WINDOW_WIDTH
            && self.window.height == PREVIOUS_MAIN_WINDOW_HEIGHT
        {
            self.window.width = ORIGINAL_MAIN_WINDOW_WIDTH;
            self.window.height = ORIGINAL_MAIN_WINDOW_HEIGHT;
        }
        if source_schema < 3 {
            // Schema 1/2 accidentally inverted the archived default. Those schemas were only
            // emitted by the pre-release Flutter port, so migrate them to the intended default.
            self.one_graph_per_cpu = true;
        }
        self.schema_version = SETTINGS_SCHEMA_VERSION;
        if !self.window.width.is_finite() || self.window.width < ORIGINAL_MAIN_WINDOW_WIDTH {
            self.window.width = ORIGINAL_MAIN_WINDOW_WIDTH;
        }
        if !self.window.height.is_finite() || self.window.height < ORIGINAL_MAIN_WINDOW_HEIGHT {
            self.window.height = ORIGINAL_MAIN_WINDOW_HEIGHT;
        }
        if self.window.x.is_some_and(|value| !value.is_finite()) {
            self.window.x = None;
        }
        if self.window.y.is_some_and(|value| !value.is_finite()) {
            self.window.y = None;
        }
        let mut seen = std::collections::HashSet::new();
        self.process_columns.retain(|layout| {
            layout.width.is_finite()
                && (24.0..=1_000.0).contains(&layout.width)
                && seen.insert(layout.column)
        });
        if !self
            .process_columns
            .iter()
            .any(|layout| layout.column == ColumnId::ImageName)
        {
            self.process_columns.insert(
                0,
                ColumnLayout {
                    column: ColumnId::ImageName,
                    width: 107.0,
                    visible: true,
                },
            );
        }
        self
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct SettingsLoadResult {
    pub settings: UiSettings,
    pub recovered_corrupt_path: Option<String>,
    pub warning: Option<BackendError>,
}

#[derive(Clone, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
pub struct ProcessIdentity {
    pub pid: u32,
    pub start_time: u64,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ApplicationIdentity {
    pub native_id: u64,
    pub process: Option<ProcessIdentity>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ApplicationStatus {
    Running,
    NotResponding,
    Unknown,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct ApplicationRow {
    pub identity: ApplicationIdentity,
    pub title: String,
    pub status: ApplicationStatus,
    pub window_station: Option<String>,
    pub desktop: Option<String>,
    pub icon_png: Option<Vec<u8>>,
    pub large_icon_png: Option<Vec<u8>>,
    pub allowed_actions: Vec<ActionKind>,
    pub row_error: Option<BackendError>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct ProcessRow {
    pub identity: ProcessIdentity,
    pub parent_pid: Option<u32>,
    pub image_name: String,
    pub executable_path: Option<String>,
    pub user_name: Option<String>,
    pub session_id: Option<u32>,
    pub cpu_percent: Option<f64>,
    pub cpu_time_millis: Option<u64>,
    pub memory_kib: Option<u64>,
    pub memory_delta_kib: Option<i64>,
    pub page_faults: Option<u64>,
    pub page_faults_delta: Option<i64>,
    pub virtual_memory_kib: Option<u64>,
    pub paged_pool_kib: Option<u64>,
    pub non_paged_pool_kib: Option<u64>,
    pub base_priority: Option<String>,
    pub handle_count: Option<u64>,
    pub thread_count: Option<u64>,
    pub file_descriptor_count: Option<u64>,
    pub nice: Option<i32>,
    pub cgroup: Option<String>,
    /// 一次成功读取的当前亲和性；`None` 表示权限或平台 API 未提供。
    pub affinity: Option<Vec<u32>>,
    pub row_error: Option<BackendError>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum CpuCacheKind {
    Data,
    Instruction,
    Unified,
    Trace,
    Other,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CpuCache {
    pub level: u8,
    pub kind: CpuCacheKind,
    /// Capacity of one cache instance.
    pub size_bytes: u64,
    pub instance_count: u32,
    pub associativity: Option<u32>,
    pub line_size_bytes: Option<u32>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct CpuCoreClass {
    /// Windows efficiency class or Linux scheduler capacity. `None` means a uniform topology.
    pub efficiency_class: Option<u32>,
    pub core_count: u32,
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
pub struct CpuCurrentMetrics {
    pub average_frequency_mhz: Option<f64>,
    pub minimum_frequency_mhz: Option<f64>,
    pub maximum_frequency_mhz: Option<f64>,
    pub user_percent: Option<f64>,
    pub kernel_percent: Option<f64>,
    pub dpc_percent: Option<f64>,
    pub interrupt_percent: Option<f64>,
    pub interrupts_per_second: Option<u64>,
    pub uptime_seconds: Option<u64>,
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
pub struct CpuSystemMetrics {
    pub process_count: Option<u64>,
    pub thread_count: Option<u64>,
    pub handle_count: Option<u64>,
    pub file_descriptor_count: Option<u64>,
    pub open_file_count: Option<u64>,
    pub processor_queue_length: Option<u64>,
    pub context_switches_per_second: Option<u64>,
    pub system_calls_per_second: Option<u64>,
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
pub struct CpuTopologyMetrics {
    pub package_count: Option<u32>,
    pub numa_node_count: Option<u32>,
    pub processor_group_count: Option<u32>,
    pub die_count: Option<u32>,
    pub module_count: Option<u32>,
    pub physical_core_count: Option<u32>,
    pub logical_processor_count: Option<u32>,
    pub core_classes: Vec<CpuCoreClass>,
    pub smt_core_count: Option<u32>,
    pub minimum_threads_per_core: Option<u32>,
    pub maximum_threads_per_core: Option<u32>,
    pub virtualization: Option<bool>,
    pub second_level_address_translation: Option<bool>,
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Serialize)]
pub struct CpuHardwareMetrics {
    pub manufacturer: Option<String>,
    pub socket: Option<String>,
    pub processor_id: Option<String>,
    pub architecture: Option<String>,
    pub address_width_bits: Option<u16>,
    pub data_width_bits: Option<u16>,
    pub family: Option<String>,
    pub level: Option<String>,
    pub revision: Option<String>,
    pub stepping: Option<String>,
    pub firmware_max_frequency_mhz: Option<f64>,
    pub isa_features: Vec<String>,
    pub caches: Vec<CpuCache>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct GpuEngine {
    pub id: String,
    pub kind: GpuEngineKind,
    pub ordinal: Option<u32>,
    /// Driver-defined engine name, used only when `kind` is `Other`.
    pub name: Option<String>,
    pub utilization_percent: Option<f64>,
    pub history: Vec<f64>,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
pub enum GpuEngineKind {
    Overall,
    Memory,
    ThreeD,
    Copy,
    VideoEncode,
    VideoDecode,
    Compute,
    Security,
    Other,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
pub enum GpuDriverModel {
    WindowsWddm,
    LinuxDrm,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct GpuAdapter {
    pub id: String,
    pub name: String,
    pub driver_model: GpuDriverModel,
    pub utilization_percent: Option<f64>,
    pub dedicated_used_bytes: Option<u64>,
    pub dedicated_total_bytes: Option<u64>,
    pub shared_used_bytes: Option<u64>,
    pub shared_total_bytes: Option<u64>,
    pub temperature_celsius: Option<f64>,
    pub driver_name: Option<String>,
    pub driver_version: Option<String>,
    pub driver_date: Option<String>,
    pub graphics_api: Option<String>,
    pub physical_location: Option<String>,
    pub primary_device_node: Option<String>,
    pub render_device_node: Option<String>,
    pub hardware_reserved_bytes: Option<u64>,
    pub engines: Vec<GpuEngine>,
    /// Dedicated-memory utilization history normalized to 0–100 percent.
    pub dedicated_usage_history_percent: Vec<f64>,
    /// Shared-memory utilization history normalized to 0–100 percent.
    pub shared_usage_history_percent: Vec<f64>,
    pub detail_error: Option<BackendError>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct NetworkInterface {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub operational: bool,
    pub link_speed_bits_per_second: Option<u64>,
    pub received_bytes_per_second: Option<f64>,
    pub sent_bytes_per_second: Option<f64>,
    pub utilization_percent: Option<f64>,
    pub received_history: Vec<f64>,
    pub sent_history: Vec<f64>,
    pub row_error: Option<BackendError>,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct UserSessionIdentity {
    pub id: String,
    pub login_time: Option<u64>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct UserSession {
    pub identity: UserSessionIdentity,
    pub user_name: String,
    pub session: Option<String>,
    pub client_name: Option<String>,
    pub state: String,
    pub idle_seconds: Option<u64>,
    pub allowed_actions: Vec<ActionKind>,
    pub row_error: Option<BackendError>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct ApplicationsData {
    pub rows: Vec<ApplicationRow>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct ProcessesData {
    pub rows: Vec<ProcessRow>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct PerformanceData {
    pub process_count: Option<u64>,
    pub thread_count: Option<u64>,
    /// Windows system handle count; `None` on Linux.
    pub handle_count: Option<u64>,
    /// Linux in-use file-handle count from `/proc/sys/fs/file-nr`; `None` on Windows.
    pub open_file_count: Option<u64>,
    pub memory_total_kib: Option<u64>,
    pub memory_available_kib: Option<u64>,
    pub file_cache_kib: Option<u64>,
    pub commit_total_kib: Option<u64>,
    pub commit_limit_kib: Option<u64>,
    pub commit_peak_kib: Option<u64>,
    pub kernel_total_kib: Option<u64>,
    pub kernel_paged_kib: Option<u64>,
    pub kernel_non_paged_kib: Option<u64>,
    /// Linux-native memory details. Windows leaves these fields unavailable.
    pub swap_used_kib: Option<u64>,
    pub slab_kib: Option<u64>,
    pub kernel_stack_kib: Option<u64>,
    pub page_tables_kib: Option<u64>,
    pub cpu_percent: Option<f64>,
    pub memory_percent: Option<f64>,
    pub cpu_history: Vec<f64>,
    pub kernel_history: Vec<f64>,
    pub memory_history: Vec<f64>,
    pub logical_cpu_histories: Vec<Vec<f64>>,
    pub logical_kernel_histories: Vec<Vec<f64>>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct CpuData {
    pub model: Option<String>,
    pub utilization_percent: Option<f64>,
    pub history: Vec<f64>,
    pub kernel_history: Vec<f64>,
    pub current: CpuCurrentMetrics,
    pub system: CpuSystemMetrics,
    pub topology: CpuTopologyMetrics,
    pub hardware: CpuHardwareMetrics,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct GpuData {
    pub adapters: Vec<GpuAdapter>,
    pub selected_adapter: Option<usize>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct NetworkData {
    pub interfaces: Vec<NetworkInterface>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct UsersData {
    pub sessions: Vec<UserSession>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(tag = "page", content = "data", rename_all = "snake_case")]
pub enum SnapshotData {
    Applications(ApplicationsData),
    Processes(ProcessesData),
    Performance(Box<PerformanceData>),
    Cpu(Box<CpuData>),
    Gpu(GpuData),
    Network(NetworkData),
    Users(UsersData),
}

impl SnapshotData {
    pub const fn page(&self) -> PageId {
        match self {
            Self::Applications(_) => PageId::Applications,
            Self::Processes(_) => PageId::Processes,
            Self::Performance(_) => PageId::Performance,
            Self::Cpu(_) => PageId::Cpu,
            Self::Gpu(_) => PageId::Gpu,
            Self::Network(_) => PageId::Network,
            Self::Users(_) => PageId::Users,
        }
    }

    pub fn into_event(self, meta: SnapshotMeta) -> BackendEvent {
        match self {
            Self::Applications(data) => BackendEvent::Applications(PageSnapshot { meta, data }),
            Self::Processes(data) => BackendEvent::Processes(PageSnapshot { meta, data }),
            Self::Performance(data) => {
                BackendEvent::Performance(Box::new(PageSnapshot { meta, data: *data }))
            }
            Self::Cpu(data) => BackendEvent::Cpu(Box::new(PageSnapshot { meta, data: *data })),
            Self::Gpu(data) => BackendEvent::Gpu(PageSnapshot { meta, data }),
            Self::Network(data) => BackendEvent::Network(PageSnapshot { meta, data }),
            Self::Users(data) => BackendEvent::Users(PageSnapshot { meta, data }),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct BackendError {
    pub domain: String,
    pub code: i64,
    pub context: String,
    pub message: String,
}

impl BackendError {
    pub fn io(context: impl Into<String>, error: &std::io::Error) -> Self {
        Self {
            domain: "io".to_string(),
            code: i64::from(error.raw_os_error().unwrap_or(-1)),
            context: context.into(),
            message: error.to_string(),
        }
    }

    pub fn unsupported(context: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            domain: "capability".to_string(),
            code: 0,
            context: context.into(),
            message: message.into(),
        }
    }

    pub fn internal(context: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            domain: "internal".to_string(),
            code: -1,
            context: context.into(),
            message: message.into(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct SnapshotMeta {
    pub generation: u64,
    pub sampled_at_millis: u64,
    pub stale: bool,
    pub error: Option<BackendError>,
}

impl SnapshotMeta {
    pub fn fresh(generation: u64) -> Self {
        Self {
            generation,
            sampled_at_millis: unix_time_millis(),
            stale: false,
            error: None,
        }
    }

    pub fn stale_with_error(generation: u64, error: BackendError) -> Self {
        Self {
            generation,
            sampled_at_millis: unix_time_millis(),
            stale: true,
            error: Some(error),
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct PageSnapshot<T> {
    pub meta: SnapshotMeta,
    pub data: T,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(tag = "event", content = "payload", rename_all = "snake_case")]
pub enum BackendEvent {
    Capabilities(PlatformCapabilities),
    Applications(PageSnapshot<ApplicationsData>),
    Processes(PageSnapshot<ProcessesData>),
    Performance(Box<PageSnapshot<PerformanceData>>),
    Cpu(Box<PageSnapshot<CpuData>>),
    Gpu(PageSnapshot<GpuData>),
    Network(PageSnapshot<NetworkData>),
    Users(PageSnapshot<UsersData>),
    PageUnavailable { page: PageId, meta: SnapshotMeta },
    PrivilegeChanged(PrivilegeResult),
}

impl BackendEvent {
    pub const fn page(&self) -> Option<PageId> {
        match self {
            Self::Capabilities(_) | Self::PrivilegeChanged(_) => None,
            Self::Applications(_) => Some(PageId::Applications),
            Self::Processes(_) => Some(PageId::Processes),
            Self::Performance(_) => Some(PageId::Performance),
            Self::Cpu(_) => Some(PageId::Cpu),
            Self::Gpu(_) => Some(PageId::Gpu),
            Self::Network(_) => Some(PageId::Network),
            Self::Users(_) => Some(PageId::Users),
            Self::PageUnavailable { page, .. } => Some(*page),
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ProcessPriority {
    Low,
    BelowNormal,
    Normal,
    AboveNormal,
    High,
    Realtime,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum WindowAction {
    SwitchTo,
    BringToFront,
    Minimize,
    Maximize,
    Close,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum WindowArrangement {
    TileHorizontally,
    TileVertically,
    Cascade,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum UserAction {
    Disconnect,
    Logoff,
    SendMessage,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum ActionRequest {
    RunTask {
        command_line: String,
    },
    EndProcess {
        identity: ProcessIdentity,
        include_descendants: bool,
    },
    SetPriority {
        identity: ProcessIdentity,
        priority: ProcessPriority,
    },
    SetNice {
        identity: ProcessIdentity,
        nice: i32,
    },
    SetAffinity {
        identity: ProcessIdentity,
        logical_processors: Vec<u32>,
    },
    OpenFileLocation {
        identity: ProcessIdentity,
    },
    Window {
        identity: ApplicationIdentity,
        operation: WindowAction,
    },
    ArrangeWindows {
        identities: Vec<ApplicationIdentity>,
        arrangement: WindowArrangement,
    },
    UserSession {
        identity: UserSessionIdentity,
        operation: UserAction,
        title: Option<String>,
        message: Option<String>,
    },
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionStatus {
    Succeeded,
    Failed,
    RequiresElevation,
    Unsupported,
    Busy,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ActionResult {
    pub status: ActionStatus,
    pub error: Option<BackendError>,
}

impl ActionResult {
    pub const fn succeeded() -> Self {
        Self {
            status: ActionStatus::Succeeded,
            error: None,
        }
    }

    pub fn failed(error: BackendError) -> Self {
        Self {
            status: ActionStatus::Failed,
            error: Some(error),
        }
    }

    pub fn unsupported(message: impl Into<String>) -> Self {
        Self {
            status: ActionStatus::Unsupported,
            error: Some(BackendError::unsupported("execute_action", message)),
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PrivilegeState {
    Inactive,
    Active,
    Cancelled,
    Unavailable,
    Failed,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct PrivilegeResult {
    pub state: PrivilegeState,
    pub error: Option<BackendError>,
}

impl PrivilegeResult {
    pub fn unavailable(message: impl Into<String>) -> Self {
        Self {
            state: PrivilegeState::Unavailable,
            error: Some(BackendError::unsupported("privileged_helper", message)),
        }
    }
}

pub fn unix_time_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |duration| {
            duration
                .as_secs()
                .saturating_mul(1_000)
                .saturating_add(u64::from(duration.subsec_millis()))
        })
}

#[cfg(test)]
mod tests {
    use super::{
        ActionRequest, ApplicationIdentity, ColumnId, ORIGINAL_MAIN_WINDOW_HEIGHT,
        ORIGINAL_MAIN_WINDOW_WIDTH, PageId, SETTINGS_SCHEMA_VERSION, UiSettings, WindowArrangement,
        WindowGeometry,
    };

    #[test]
    fn page_order_matches_the_product_contract() {
        assert_eq!(
            PageId::ALL,
            [
                PageId::Applications,
                PageId::Processes,
                PageId::Performance,
                PageId::Cpu,
                PageId::Gpu,
                PageId::Network,
                PageId::Users,
            ]
        );
    }

    #[test]
    fn settings_normalization_keeps_one_image_name_column() {
        let mut settings = UiSettings::default();
        settings.process_columns.clear();
        settings.window.width = f64::NAN;
        let settings = settings.normalize();
        assert_eq!(settings.window.width, ORIGINAL_MAIN_WINDOW_WIDTH);
        assert!(
            settings
                .process_columns
                .iter()
                .any(|layout| layout.column == ColumnId::ImageName)
        );
    }

    #[test]
    fn previous_default_geometry_migrates_to_the_original_dialog_size() {
        let settings = UiSettings {
            schema_version: 1,
            window: WindowGeometry {
                width: 600.0,
                height: 430.0,
                ..WindowGeometry::default()
            },
            ..UiSettings::default()
        }
        .normalize();

        assert_eq!(settings.schema_version, SETTINGS_SCHEMA_VERSION);
        assert_eq!(settings.window.width, ORIGINAL_MAIN_WINDOW_WIDTH);
        assert_eq!(settings.window.height, ORIGINAL_MAIN_WINDOW_HEIGHT);
    }

    #[test]
    fn pre_v3_settings_migrate_to_the_original_per_cpu_default() {
        let settings = UiSettings {
            schema_version: 2,
            one_graph_per_cpu: false,
            ..UiSettings::default()
        }
        .normalize();

        assert!(settings.one_graph_per_cpu);
        assert_eq!(settings.schema_version, SETTINGS_SCHEMA_VERSION);
    }

    #[test]
    fn current_settings_preserve_an_explicit_combined_cpu_graph() {
        let settings = UiSettings {
            one_graph_per_cpu: false,
            ..UiSettings::default()
        }
        .normalize();

        assert!(!settings.one_graph_per_cpu);
    }

    #[test]
    fn window_arrangement_protocol_is_explicit_and_typed() {
        let value = serde_json::to_value(ActionRequest::ArrangeWindows {
            identities: vec![ApplicationIdentity {
                native_id: 7,
                process: None,
            }],
            arrangement: WindowArrangement::Cascade,
        })
        .expect("serialize arrangement action");

        assert_eq!(value["action"], "arrange_windows");
        assert_eq!(value["arrangement"], "cascade");
        assert!(value.get("command").is_none());
    }
}
