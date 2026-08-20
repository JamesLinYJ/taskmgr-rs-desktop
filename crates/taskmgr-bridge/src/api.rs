// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter Rust Bridge API
//
//   文件:       crates/taskmgr-bridge/src/api.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1；FRB 2.12.0
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   flutter_rust_bridge 2.12；Dart Stream；项目 FRB 协议 v1
// --------------------------------------------------------------------------

//! 将类型安全的异步事件流和动作接口暴露给 Flutter。

use std::sync::Arc;

use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
pub use taskmgr_core::{
    ActionResult, BackendOptions, PageId, PrivilegeResult, SettingsLoadResult, UiSettings,
};
use taskmgr_core::{BackendRuntime, PlatformProvider, SettingsStore};

#[derive(Clone, Debug)]
#[frb(non_opaque)]
pub enum BridgeBackendEvent {
    Capabilities(taskmgr_core::PlatformCapabilities),
    Applications {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::ApplicationsData,
    },
    Processes {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::ProcessesData,
    },
    Performance {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::PerformanceData,
    },
    Cpu {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::CpuData,
    },
    Gpu {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::GpuData,
    },
    Network {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::NetworkData,
    },
    Users {
        meta: taskmgr_core::SnapshotMeta,
        data: taskmgr_core::UsersData,
    },
    PageUnavailable {
        page: taskmgr_core::PageId,
        meta: taskmgr_core::SnapshotMeta,
    },
    PrivilegeChanged(taskmgr_core::PrivilegeResult),
}

impl From<taskmgr_core::BackendEvent> for BridgeBackendEvent {
    fn from(event: taskmgr_core::BackendEvent) -> Self {
        match event {
            taskmgr_core::BackendEvent::Capabilities(value) => Self::Capabilities(value),
            taskmgr_core::BackendEvent::Applications(value) => Self::Applications {
                meta: value.meta,
                data: value.data,
            },
            taskmgr_core::BackendEvent::Processes(value) => Self::Processes {
                meta: value.meta,
                data: value.data,
            },
            taskmgr_core::BackendEvent::Performance(value) => {
                let taskmgr_core::PageSnapshot { meta, data } = *value;
                Self::Performance { meta, data }
            }
            taskmgr_core::BackendEvent::Cpu(value) => Self::Cpu {
                meta: value.meta,
                data: value.data,
            },
            taskmgr_core::BackendEvent::Gpu(value) => Self::Gpu {
                meta: value.meta,
                data: value.data,
            },
            taskmgr_core::BackendEvent::Network(value) => Self::Network {
                meta: value.meta,
                data: value.data,
            },
            taskmgr_core::BackendEvent::Users(value) => Self::Users {
                meta: value.meta,
                data: value.data,
            },
            taskmgr_core::BackendEvent::PageUnavailable { page, meta } => {
                Self::PageUnavailable { page, meta }
            }
            taskmgr_core::BackendEvent::PrivilegeChanged(value) => Self::PrivilegeChanged(value),
        }
    }
}

#[derive(Clone, Debug)]
pub enum BridgeActionRequest {
    RunTask {
        command_line: String,
    },
    EndProcess {
        identity: taskmgr_core::ProcessIdentity,
        include_descendants: bool,
    },
    SetPriority {
        identity: taskmgr_core::ProcessIdentity,
        priority: taskmgr_core::ProcessPriority,
    },
    SetNice {
        identity: taskmgr_core::ProcessIdentity,
        nice: i32,
    },
    SetAffinity {
        identity: taskmgr_core::ProcessIdentity,
        logical_processors: Vec<u32>,
    },
    OpenFileLocation {
        identity: taskmgr_core::ProcessIdentity,
    },
    Window {
        identity: taskmgr_core::ApplicationIdentity,
        operation: taskmgr_core::WindowAction,
    },
    ArrangeWindows {
        identities: Vec<taskmgr_core::ApplicationIdentity>,
        arrangement: taskmgr_core::WindowArrangement,
    },
    UserSession {
        identity: taskmgr_core::UserSessionIdentity,
        operation: taskmgr_core::UserAction,
        title: Option<String>,
        message: Option<String>,
    },
}

impl From<BridgeActionRequest> for taskmgr_core::ActionRequest {
    fn from(request: BridgeActionRequest) -> Self {
        match request {
            BridgeActionRequest::RunTask { command_line } => Self::RunTask { command_line },
            BridgeActionRequest::EndProcess {
                identity,
                include_descendants,
            } => Self::EndProcess {
                identity,
                include_descendants,
            },
            BridgeActionRequest::SetPriority { identity, priority } => {
                Self::SetPriority { identity, priority }
            }
            BridgeActionRequest::SetNice { identity, nice } => Self::SetNice { identity, nice },
            BridgeActionRequest::SetAffinity {
                identity,
                logical_processors,
            } => Self::SetAffinity {
                identity,
                logical_processors,
            },
            BridgeActionRequest::OpenFileLocation { identity } => {
                Self::OpenFileLocation { identity }
            }
            BridgeActionRequest::Window {
                identity,
                operation,
            } => Self::Window {
                identity,
                operation,
            },
            BridgeActionRequest::ArrangeWindows {
                identities,
                arrangement,
            } => Self::ArrangeWindows {
                identities,
                arrangement,
            },
            BridgeActionRequest::UserSession {
                identity,
                operation,
                title,
                message,
            } => Self::UserSession {
                identity,
                operation,
                title,
                message,
            },
        }
    }
}

#[frb(opaque)]
#[derive(Clone)]
pub struct BackendHandle {
    runtime: Arc<BackendRuntime>,
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn start_backend(options: BackendOptions) -> BackendHandle {
    BackendHandle {
        runtime: Arc::new(BackendRuntime::start(platform_provider(), options)),
    }
}

pub fn watch_backend(handle: &BackendHandle, sink: StreamSink<BridgeBackendEvent>) {
    let events = handle.runtime.events();
    let _ = std::thread::Builder::new()
        .name("taskmgr-frb-events".to_string())
        .spawn(move || {
            while let Ok(event) = events.recv() {
                if sink.add(event.into()).is_err() {
                    break;
                }
            }
        });
}

pub fn update_options(handle: &BackendHandle, options: BackendOptions) -> Result<(), String> {
    handle
        .runtime
        .update_options(options)
        .map_err(|error| error.to_string())
}

pub fn request_refresh(handle: &BackendHandle, page: Option<PageId>) -> Result<(), String> {
    handle
        .runtime
        .request_refresh(page)
        .map_err(|error| error.to_string())
}

pub fn open_privileged_session(handle: &BackendHandle) -> PrivilegeResult {
    handle.runtime.open_privileged_session()
}

pub fn execute_action(handle: &BackendHandle, request: BridgeActionRequest) -> ActionResult {
    handle.runtime.execute_action(request.into())
}

pub fn load_settings() -> Result<SettingsLoadResult, String> {
    SettingsStore::discover()
        .and_then(|store| store.load())
        .map_err(|error| error.to_string())
}

pub fn save_settings(settings: UiSettings) -> Result<(), String> {
    SettingsStore::discover()
        .and_then(|store| store.save(&settings))
        .map_err(|error| error.to_string())
}

pub fn shutdown_backend(handle: &BackendHandle) -> Result<(), String> {
    handle.runtime.shutdown().map_err(|error| error.to_string())
}

fn platform_provider() -> Box<dyn PlatformProvider> {
    #[cfg(target_os = "linux")]
    {
        Box::new(taskmgr_linux::LinuxProvider::new())
    }
    #[cfg(windows)]
    {
        Box::new(taskmgr_windows::WindowsProvider::new())
    }
    #[cfg(not(any(target_os = "linux", windows)))]
    compile_error!("taskmgr-rs supports only Windows and Linux");
}
