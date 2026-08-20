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
pub const SETTINGS_SCHEMA_VERSION: u16 = 1;
pub const HISTORY_CAPACITY: usize = 120;

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
            width: 600.0,
            height: 430.0,
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
            one_graph_per_cpu: false,
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
        self.schema_version = SETTINGS_SCHEMA_VERSION;
        if !self.window.width.is_finite() || self.window.width < 400.0 {
            self.window.width = 600.0;
        }
        if !self.window.height.is_finite() || self.window.height < 300.0 {
            self.window.height = 430.0;
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

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct MetricValue {
    pub label: String,
    pub value: Option<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct CpuMetricGroup {
    pub title: String,
    pub metrics: Vec<MetricValue>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct GpuEngine {
    pub name: String,
    pub utilization_percent: Option<f64>,
    pub history: Vec<f64>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct GpuAdapter {
    pub id: String,
    pub name: String,
    pub utilization_percent: Option<f64>,
    pub dedicated_used_bytes: Option<u64>,
    pub dedicated_total_bytes: Option<u64>,
    pub shared_used_bytes: Option<u64>,
    pub shared_total_bytes: Option<u64>,
    pub temperature_celsius: Option<f64>,
    pub driver_version: Option<String>,
    pub driver_date: Option<String>,
    pub graphics_api: Option<String>,
    pub physical_location: Option<String>,
    pub hardware_reserved_bytes: Option<u64>,
    pub engines: Vec<GpuEngine>,
    pub dedicated_history: Vec<f64>,
    pub shared_history: Vec<f64>,
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
    pub handle_count: Option<u64>,
    pub memory_total_kib: Option<u64>,
    pub memory_available_kib: Option<u64>,
    pub file_cache_kib: Option<u64>,
    pub commit_total_kib: Option<u64>,
    pub commit_limit_kib: Option<u64>,
    pub commit_peak_kib: Option<u64>,
    pub kernel_total_kib: Option<u64>,
    pub kernel_paged_kib: Option<u64>,
    pub kernel_non_paged_kib: Option<u64>,
    pub cpu_percent: Option<f64>,
    pub memory_percent: Option<f64>,
    pub cpu_history: Vec<f64>,
    pub kernel_history: Vec<f64>,
    pub memory_history: Vec<f64>,
    pub logical_cpu_histories: Vec<Vec<f64>>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct CpuData {
    pub model: Option<String>,
    pub status: Option<String>,
    pub utilization_percent: Option<f64>,
    pub history: Vec<f64>,
    pub groups: Vec<CpuMetricGroup>,
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
    Cpu(CpuData),
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
            Self::Cpu(data) => BackendEvent::Cpu(PageSnapshot { meta, data }),
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
    Cpu(PageSnapshot<CpuData>),
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
        ActionRequest, ApplicationIdentity, ColumnId, PageId, UiSettings, WindowArrangement,
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
        assert_eq!(settings.window.width, 600.0);
        assert!(
            settings
                .process_columns
                .iter()
                .any(|layout| layout.column == ColumnId::ImageName)
        );
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
