// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux 平台后端
//
//   文件:       crates/taskmgr-linux/src/lib.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Linux kernel UAPI；proc(5)；sysfs(5)；DRM sysfs ABI；Wayland；EWMH
// --------------------------------------------------------------------------

//! 组合 Linux `/proc`、`/sys`、DRM、utmpx、Wayland 与 X11 EWMH 数据源。

#[cfg(target_os = "linux")]
mod applications;
#[cfg(target_os = "linux")]
mod gpu;
#[cfg(target_os = "linux")]
mod launch;
#[cfg(target_os = "linux")]
mod network;
#[cfg(target_os = "linux")]
mod procfs;
#[cfg(target_os = "linux")]
mod users;
#[cfg(target_os = "linux")]
mod wayland;
#[cfg(target_os = "linux")]
mod wayland_kde;
#[cfg(target_os = "linux")]
mod x11;

#[cfg(target_os = "linux")]
use taskmgr_core::{ActionKind, ColumnId};
use taskmgr_core::{
    ActionRequest, ActionResult, Architecture, Availability, BackendError, PROTOCOL_VERSION,
    PageCapability, PageId, PlatformCapabilities, PlatformKind, PlatformProvider, PrivilegeResult,
    SnapshotData,
};

#[cfg(target_os = "linux")]
use applications::ApplicationsProvider;
#[cfg(target_os = "linux")]
use gpu::GpuSampler;
#[cfg(target_os = "linux")]
use network::NetworkSampler;
#[cfg(target_os = "linux")]
use procfs::ProcSampler;

pub struct LinuxProvider {
    #[cfg(target_os = "linux")]
    procfs: ProcSampler,
    #[cfg(target_os = "linux")]
    network: NetworkSampler,
    #[cfg(target_os = "linux")]
    gpu: GpuSampler,
    #[cfg(target_os = "linux")]
    applications: ApplicationsProvider,
}

impl LinuxProvider {
    pub fn new() -> Self {
        Self {
            #[cfg(target_os = "linux")]
            procfs: ProcSampler::new(),
            #[cfg(target_os = "linux")]
            network: NetworkSampler::new(),
            #[cfg(target_os = "linux")]
            gpu: GpuSampler::new(),
            #[cfg(target_os = "linux")]
            applications: ApplicationsProvider::new(),
        }
    }
}

impl Default for LinuxProvider {
    fn default() -> Self {
        Self::new()
    }
}

impl PlatformProvider for LinuxProvider {
    fn capabilities(&self) -> PlatformCapabilities {
        #[cfg(target_os = "linux")]
        {
            let mut applications = self.applications.capability();
            applications.1.push(ActionKind::RunTask);
            PlatformCapabilities {
                protocol_version: PROTOCOL_VERSION,
                platform: PlatformKind::Linux,
                architecture: Architecture::current(),
                pages: vec![
                    PageCapability {
                        page: PageId::Applications,
                        availability: applications.0,
                        columns: vec![ColumnId::Task, ColumnId::Status],
                        actions: applications.1,
                        detail: applications.2,
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
                            ColumnId::Nice,
                            ColumnId::FileDescriptorCount,
                            ColumnId::ThreadCount,
                            ColumnId::Cgroup,
                        ],
                        actions: vec![
                            ActionKind::EndProcess,
                            ActionKind::EndProcessTree,
                            ActionKind::SetNice,
                            ActionKind::SetAffinity,
                            ActionKind::OpenFileLocation,
                        ],
                        detail: Some(
                            "Linux uses nice, file descriptors, RSS and cgroups".to_string(),
                        ),
                    },
                    PageCapability {
                        page: PageId::Performance,
                        availability: Availability::Partial,
                        columns: Vec::new(),
                        actions: vec![ActionKind::Refresh],
                        detail: Some(
                            "Windows commit and paged-pool counters have no exact Linux equivalent"
                                .to_string(),
                        ),
                    },
                    PageCapability {
                        page: PageId::Cpu,
                        availability: Availability::Supported,
                        columns: Vec::new(),
                        actions: vec![ActionKind::Refresh],
                        detail: None,
                    },
                    PageCapability {
                        page: PageId::Gpu,
                        availability: Availability::Partial,
                        columns: Vec::new(),
                        actions: vec![ActionKind::Refresh],
                        detail: Some(
                            "DRM exposes different metrics depending on the kernel driver"
                                .to_string(),
                        ),
                    },
                    PageCapability {
                        page: PageId::Network,
                        availability: Availability::Supported,
                        columns: Vec::new(),
                        actions: vec![ActionKind::Refresh],
                        detail: None,
                    },
                    PageCapability {
                        page: PageId::Users,
                        availability: Availability::Partial,
                        columns: Vec::new(),
                        actions: Vec::new(),
                        detail: Some(
                            "utmpx provides logged-in sessions; session control needs logind"
                                .to_string(),
                        ),
                    },
                ],
                privileged_details: Availability::Partial,
                // AppIndicator support is supplied by the Flutter desktop layer. Linux remains
                // partial because a compositor/session may omit a StatusNotifier host; the UI
                // therefore never enables "hide when minimized" from this flag alone.
                tray: Availability::Partial,
                compositor: std::env::var("XDG_CURRENT_DESKTOP").ok(),
                logical_processors: procfs::online_logical_processors(),
            }
        }
        #[cfg(not(target_os = "linux"))]
        {
            PlatformCapabilities {
                protocol_version: PROTOCOL_VERSION,
                platform: PlatformKind::Linux,
                architecture: Architecture::current(),
                pages: PageId::ALL
                    .into_iter()
                    .map(|page| PageCapability {
                        page,
                        availability: Availability::Unsupported,
                        columns: Vec::new(),
                        actions: Vec::new(),
                        detail: Some("Linux APIs require a Linux build".to_string()),
                    })
                    .collect(),
                privileged_details: Availability::Unsupported,
                tray: Availability::Unsupported,
                compositor: None,
                logical_processors: Vec::new(),
            }
        }
    }

    fn sample(&mut self, page: PageId) -> Result<SnapshotData, BackendError> {
        #[cfg(target_os = "linux")]
        {
            match page {
                PageId::Applications => self.applications.sample(),
                PageId::Processes => self.procfs.sample_processes(),
                PageId::Performance => self.procfs.sample_performance(),
                PageId::Cpu => self.procfs.sample_cpu(),
                PageId::Gpu => self.gpu.sample(),
                PageId::Network => self.network.sample(),
                PageId::Users => users::sample(),
            }
        }
        #[cfg(not(target_os = "linux"))]
        {
            Err(BackendError::unsupported(
                format!("sample {page:?}"),
                "Linux APIs require a Linux build",
            ))
        }
    }

    fn execute_action(&mut self, request: ActionRequest) -> ActionResult {
        #[cfg(target_os = "linux")]
        {
            match request {
                ActionRequest::RunTask { command_line } => launch::run(&command_line),
                ActionRequest::Window { .. } => self.applications.execute(request),
                ActionRequest::ArrangeWindows { .. } => ActionResult::unsupported(
                    "the active Linux compositor does not expose trusted window placement",
                ),
                ActionRequest::EndProcess { .. }
                | ActionRequest::SetPriority { .. }
                | ActionRequest::SetNice { .. }
                | ActionRequest::SetAffinity { .. }
                | ActionRequest::OpenFileLocation { .. } => self.procfs.execute(request),
                ActionRequest::UserSession { .. } => ActionResult::unsupported(
                    "session control requires the installed polkit helper",
                ),
            }
        }
        #[cfg(not(target_os = "linux"))]
        {
            let _ = request;
            ActionResult::unsupported("Linux actions require a Linux build")
        }
    }

    fn open_privileged_session(&mut self) -> PrivilegeResult {
        PrivilegeResult::unavailable(
            "install the DEB/RPM package to enable the polkit helper; portable builds stay unprivileged",
        )
    }
}
