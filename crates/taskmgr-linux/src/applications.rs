// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux 应用程序后端选择
//
//   文件:       crates/taskmgr-linux/src/applications.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Wayland ext-foreign-toplevel-list-v1；wlroots/KDE foreign-toplevel；EWMH 1.5
// --------------------------------------------------------------------------

//! 按 Wayland 标准协议、wlroots 扩展、X11/EWMH 的顺序选择窗口后端。

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, Availability, BackendError, SnapshotData,
};

use crate::wayland::WaylandApplications;
use crate::x11::X11Applications;

pub struct ApplicationsProvider {
    backend: ApplicationsBackend,
}

enum ApplicationsBackend {
    Wayland(WaylandApplications),
    X11 {
        provider: X11Applications,
        wayland_failure: Option<String>,
    },
    Unavailable {
        detail: String,
    },
}

impl ApplicationsProvider {
    pub fn new() -> Self {
        let wayland_requested = std::env::var_os("WAYLAND_DISPLAY").is_some()
            || std::env::var_os("WAYLAND_SOCKET").is_some()
            || std::env::var("XDG_SESSION_TYPE")
                .is_ok_and(|kind| kind.eq_ignore_ascii_case("wayland"));
        let x11 = X11Applications::new();
        if wayland_requested {
            match WaylandApplications::connect() {
                Ok(Some(provider)) => {
                    return Self {
                        backend: ApplicationsBackend::Wayland(provider),
                    };
                }
                Ok(None) => {
                    let detail = "Wayland compositor exposes no supported foreign-toplevel protocol (ext, wlroots, or KDE Plasma)".to_string();
                    if x11.is_available() {
                        return Self {
                            backend: ApplicationsBackend::X11 {
                                provider: x11,
                                wayland_failure: Some(detail),
                            },
                        };
                    }
                    return Self {
                        backend: ApplicationsBackend::Unavailable { detail },
                    };
                }
                Err(error) => {
                    if x11.is_available() {
                        return Self {
                            backend: ApplicationsBackend::X11 {
                                provider: x11,
                                wayland_failure: Some(error.message),
                            },
                        };
                    }
                    return Self {
                        backend: ApplicationsBackend::Unavailable {
                            detail: error.message,
                        },
                    };
                }
            }
        }
        if x11.is_available() {
            Self {
                backend: ApplicationsBackend::X11 {
                    provider: x11,
                    wayland_failure: None,
                },
            }
        } else {
            Self {
                backend: ApplicationsBackend::Unavailable {
                    detail: "no Wayland or X11 display is available".to_string(),
                },
            }
        }
    }

    pub fn capability(&self) -> (Availability, Vec<ActionKind>, Option<String>) {
        match &self.backend {
            ApplicationsBackend::Wayland(provider) => provider.capability(),
            ApplicationsBackend::X11 {
                provider,
                wayland_failure,
            } => {
                let (mut availability, actions, x11_detail) = provider.capability();
                if wayland_failure.is_some() {
                    availability = Availability::Partial;
                }
                let detail = match (wayland_failure, x11_detail) {
                    (Some(failure), Some(x11)) => {
                        Some(format!("Wayland unavailable ({failure}); using {x11}"))
                    }
                    (Some(failure), None) => {
                        Some(format!("Wayland unavailable ({failure}); using X11 EWMH"))
                    }
                    (None, detail) => detail,
                };
                (availability, actions, detail)
            }
            ApplicationsBackend::Unavailable { detail } => {
                (Availability::Unsupported, Vec::new(), Some(detail.clone()))
            }
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        match &mut self.backend {
            ApplicationsBackend::Wayland(provider) => provider.sample(),
            ApplicationsBackend::X11 { provider, .. } => provider.sample(),
            ApplicationsBackend::Unavailable { detail } => {
                Err(BackendError::unsupported("applications", detail.clone()))
            }
        }
    }

    pub fn execute(&mut self, request: ActionRequest) -> ActionResult {
        match &mut self.backend {
            ApplicationsBackend::Wayland(provider) => provider.execute(request),
            ApplicationsBackend::X11 { provider, .. } => provider.execute(request),
            ApplicationsBackend::Unavailable { detail } => {
                ActionResult::unsupported(detail.clone())
            }
        }
    }
}

impl Default for ApplicationsProvider {
    fn default() -> Self {
        Self::new()
    }
}
