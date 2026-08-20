// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 平台后端
//
//   文件:       crates/taskmgr-windows/src/lib.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Win32；Tool Help；Process Status API；IP Helper；WTS
// --------------------------------------------------------------------------

//! 组合无 UI 依赖的 Windows 系统采集器与身份安全动作。
//!
//! 所有 HWND/HANDLE 都停留在平台模块中，公共快照只包含值类型和稳定身份。

#[cfg(windows)]
mod applications;
#[cfg(windows)]
mod gpu;
#[cfg(windows)]
mod launch;
#[cfg(windows)]
mod native;
#[cfg(windows)]
mod network;
#[cfg(windows)]
mod processes;
#[cfg(windows)]
mod system;
#[cfg(windows)]
mod users;

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, Architecture, Availability, BackendError, ColumnId,
    PROTOCOL_VERSION, PageCapability, PageId, PlatformCapabilities, PlatformKind, PlatformProvider,
    PrivilegeResult, SnapshotData,
};

#[cfg(windows)]
fn affinity_logical_processors() -> Vec<u32> {
    use windows_sys::Win32::System::Threading::{ALL_PROCESSOR_GROUPS, GetActiveProcessorCount};

    // SAFETY: the all-groups sentinel is documented and the call has no pointer arguments.
    let count = unsafe { GetActiveProcessorCount(ALL_PROCESSOR_GROUPS) };
    (0..count.min(usize::BITS)).collect()
}

#[cfg(not(windows))]
fn affinity_logical_processors() -> Vec<u32> {
    Vec::new()
}

pub struct WindowsProvider {
    #[cfg(windows)]
    applications: applications::ApplicationsSampler,
    #[cfg(windows)]
    processes: processes::ProcessSampler,
    #[cfg(windows)]
    system: system::SystemSampler,
    #[cfg(windows)]
    network: network::NetworkSampler,
    #[cfg(windows)]
    gpu: gpu::GpuSampler,
}

impl WindowsProvider {
    pub fn new() -> Self {
        Self {
            #[cfg(windows)]
            applications: applications::ApplicationsSampler::new(),
            #[cfg(windows)]
            processes: processes::ProcessSampler::new(),
            #[cfg(windows)]
            system: system::SystemSampler::new(),
            #[cfg(windows)]
            network: network::NetworkSampler::new(),
            #[cfg(windows)]
            gpu: gpu::GpuSampler::new(),
        }
    }
}

impl Default for WindowsProvider {
    fn default() -> Self {
        Self::new()
    }
}

impl PlatformProvider for WindowsProvider {
    fn capabilities(&self) -> PlatformCapabilities {
        PlatformCapabilities {
            protocol_version: PROTOCOL_VERSION,
            platform: PlatformKind::Windows,
            architecture: Architecture::current(),
            pages: vec![
                PageCapability {
                    page: PageId::Applications,
                    availability: Availability::Supported,
                    columns: vec![
                        ColumnId::Task,
                        ColumnId::Status,
                        ColumnId::WindowStation,
                        ColumnId::Desktop,
                    ],
                    actions: vec![
                        ActionKind::RunTask,
                        ActionKind::SwitchTo,
                        ActionKind::BringToFront,
                        ActionKind::Minimize,
                        ActionKind::Maximize,
                        ActionKind::TileHorizontally,
                        ActionKind::TileVertically,
                        ActionKind::Cascade,
                        ActionKind::EndTask,
                    ],
                    detail: Some("Win32 visible ownerless top-level windows".to_string()),
                },
                PageCapability {
                    page: PageId::Processes,
                    availability: Availability::Supported,
                    columns: vec![
                        ColumnId::ImageName,
                        ColumnId::Pid,
                        ColumnId::UserName,
                        ColumnId::SessionId,
                        ColumnId::Cpu,
                        ColumnId::CpuTime,
                        ColumnId::MemoryUsage,
                        ColumnId::MemoryDelta,
                        ColumnId::PageFaults,
                        ColumnId::PageFaultsDelta,
                        ColumnId::VirtualMemory,
                        ColumnId::PagedPool,
                        ColumnId::NonPagedPool,
                        ColumnId::BasePriority,
                        ColumnId::HandleCount,
                        ColumnId::ThreadCount,
                    ],
                    actions: vec![
                        ActionKind::EndProcess,
                        ActionKind::EndProcessTree,
                        ActionKind::SetPriority,
                        ActionKind::SetAffinity,
                        ActionKind::OpenFileLocation,
                    ],
                    detail: Some(
                        "Process actions revalidate PID and FILETIME creation time; affinity currently exposes the native processor-group mask"
                            .to_string(),
                    ),
                },
                PageCapability {
                    page: PageId::Performance,
                    availability: Availability::Supported,
                    columns: Vec::new(),
                    actions: vec![ActionKind::Refresh],
                    detail: None,
                },
                PageCapability {
                    page: PageId::Cpu,
                    availability: Availability::Partial,
                    columns: Vec::new(),
                    actions: vec![ActionKind::Refresh],
                    detail: Some(
                        "aggregate CPU data is available; per-logical-processor histories and PDH diagnostics remain pending"
                            .to_string(),
                    ),
                },
                PageCapability {
                    page: PageId::Gpu,
                    availability: Availability::Partial,
                    columns: Vec::new(),
                    actions: vec![ActionKind::Refresh],
                    detail: Some(
                        "DXGI inventory and WDDM GPU Engine/adapter-memory counters are available; driver metadata and temperature remain pending"
                            .to_string(),
                    ),
                },
                PageCapability {
                    page: PageId::Network,
                    availability: Availability::Supported,
                    columns: Vec::new(),
                    actions: vec![ActionKind::Refresh],
                    detail: Some("IP Helper MIB_IF_TABLE2 counters".to_string()),
                },
                PageCapability {
                    page: PageId::Users,
                    availability: Availability::Supported,
                    columns: Vec::new(),
                    actions: vec![
                        ActionKind::DisconnectSession,
                        ActionKind::LogoffSession,
                        ActionKind::SendMessage,
                    ],
                    detail: Some(
                        "WTS actions revalidate session id and logon time".to_string(),
                    ),
                },
            ],
            privileged_details: Availability::Partial,
            tray: Availability::Supported,
            compositor: None,
            logical_processors: affinity_logical_processors(),
        }
    }

    fn sample(&mut self, page: PageId) -> Result<SnapshotData, BackendError> {
        #[cfg(windows)]
        {
            match page {
                PageId::Applications => self.applications.sample(),
                PageId::Processes => self.processes.sample(),
                PageId::Performance => self.system.sample_performance(),
                PageId::Cpu => self.system.sample_cpu(),
                PageId::Gpu => self.gpu.sample(),
                PageId::Network => self.network.sample(),
                PageId::Users => users::sample(),
            }
        }
        #[cfg(not(windows))]
        {
            Err(BackendError::unsupported(
                format!("sample {page:?}"),
                "Windows APIs are only available in a Windows build",
            ))
        }
    }

    fn execute_action(&mut self, request: ActionRequest) -> ActionResult {
        #[cfg(windows)]
        {
            match request {
                ActionRequest::RunTask { command_line } => launch::run(&command_line),
                ActionRequest::Window { .. } | ActionRequest::ArrangeWindows { .. } => {
                    self.applications.execute(request)
                }
                ActionRequest::EndProcess { .. }
                | ActionRequest::SetPriority { .. }
                | ActionRequest::SetNice { .. }
                | ActionRequest::SetAffinity { .. }
                | ActionRequest::OpenFileLocation { .. } => self.processes.execute(request),
                ActionRequest::UserSession { .. } => users::execute(request),
            }
        }
        #[cfg(not(windows))]
        {
            let _ = request;
            ActionResult::unsupported("Windows actions are only available in a Windows build")
        }
    }

    fn open_privileged_session(&mut self) -> PrivilegeResult {
        PrivilegeResult::unavailable(
            "the UAC named-pipe helper is not implemented; the GUI remains unprivileged",
        )
    }
}
