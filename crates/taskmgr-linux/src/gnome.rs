// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GNOME Shell 窗口提供器客户端
//
//   文件:       crates/taskmgr-linux/src/gnome.rs
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x64；x86_64-unknown-linux-gnu 交叉检查；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   D-Bus Specification；org.freedesktop.DBus 凭据接口；GNOME Shell Extension API；proc(5)；项目 WindowProvider1 协议
// --------------------------------------------------------------------------

//! 在 GNOME 未实现 foreign-toplevel 标准协议时，连接用户显式启用的只读 Shell 扩展。
//! 扩展只传递窗口元数据；本模块限制响应大小、验证协议版本与 PID 创建时间。

use serde::Deserialize;
use std::time::Duration;
use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, ApplicationIdentity, ApplicationRow,
    ApplicationStatus, ApplicationsData, Availability, BackendError, ProcessIdentity, SnapshotData,
};
use zbus::blocking::{Connection, Proxy};

use crate::desktop_icons::DesktopIconResolver;

const DESTINATION: &str = "org.gnome.Shell";
const OBJECT_PATH: &str = "/org/taskmgr_rs/WindowProvider";
const INTERFACE: &str = "org.taskmgr_rs.WindowProvider1";
const ACCESS_DENIED_ERROR: &str = "org.taskmgr_rs.WindowProvider1.Error.AccessDenied";
const PROTOCOL_VERSION: u32 = 1;
const MAX_RESPONSE_BYTES: usize = 4 * 1024 * 1024;
const MAX_WINDOWS: usize = 4096;
const MAX_TEXT_BYTES: usize = 16 * 1024;
const METHOD_TIMEOUT: Duration = Duration::from_secs(2);

pub(crate) struct GnomeSession {
    connection: Connection,
    icons: DesktopIconResolver,
}

impl GnomeSession {
    pub(crate) fn connect() -> Result<Option<Self>, BackendError> {
        if !is_gnome_session() {
            return Ok(None);
        }
        let connection = zbus::blocking::connection::Builder::session()
            .map_err(|error| gnome_error("connect to the session D-Bus", error))?
            .method_timeout(METHOD_TIMEOUT)
            .build()
            .map_err(|error| gnome_error("complete the session D-Bus handshake", error))?;
        let version = {
            let proxy = provider_proxy(&connection)?;
            match proxy.call::<_, _, u32>("GetVersion", &()) {
                Ok(version) => version,
                Err(error) if is_access_denied(&error) => {
                    return Err(gnome_error(
                        "authenticate the installed WindowProvider1 client",
                        error,
                    ));
                }
                Err(_) => return Ok(None),
            }
        };
        if version != PROTOCOL_VERSION {
            return Err(BackendError {
                domain: "gnome_shell_extension".to_string(),
                code: i64::from(version),
                context: "negotiate WindowProvider1".to_string(),
                message: format!(
                    "unsupported GNOME window provider protocol {version}; expected {PROTOCOL_VERSION}"
                ),
            });
        }
        Ok(Some(Self {
            connection,
            icons: DesktopIconResolver::discover(),
        }))
    }

    pub(crate) fn capability(&self) -> (Availability, Vec<ActionKind>, Option<String>) {
        (
            Availability::Partial,
            Vec::new(),
            Some(
                "GNOME Shell WindowProvider1 extension (user-enabled, read-only enumeration)"
                    .to_string(),
            ),
        )
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let proxy = provider_proxy(&self.connection)?;
        let payload = proxy
            .call::<_, _, String>("GetWindows", &())
            .map_err(|error| gnome_error("enumerate GNOME Shell windows", error))?;
        if payload.len() > MAX_RESPONSE_BYTES {
            return Err(BackendError {
                domain: "resource_limit".to_string(),
                code: 1,
                context: "decode GNOME window provider response".to_string(),
                message: format!(
                    "response is {} bytes; maximum is {MAX_RESPONSE_BYTES}",
                    payload.len()
                ),
            });
        }
        let snapshot: ProviderSnapshot =
            serde_json::from_str(&payload).map_err(|error| BackendError {
                domain: "gnome_shell_extension".to_string(),
                code: -1,
                context: "decode WindowProvider1 response".to_string(),
                message: error.to_string(),
            })?;
        if snapshot.protocol_version != PROTOCOL_VERSION {
            return Err(BackendError::internal(
                "decode WindowProvider1 response",
                format!(
                    "provider returned protocol {}; expected {PROTOCOL_VERSION}",
                    snapshot.protocol_version
                ),
            ));
        }
        if snapshot.truncated {
            return Err(resource_limit_error(
                "decode GNOME window list",
                "provider reported a truncated window snapshot",
            ));
        }
        if snapshot.windows.len() > MAX_WINDOWS {
            return Err(BackendError {
                domain: "resource_limit".to_string(),
                code: 1,
                context: "decode GNOME window list".to_string(),
                message: format!(
                    "provider returned {} windows; maximum is {MAX_WINDOWS}",
                    snapshot.windows.len()
                ),
            });
        }
        let current_pid = std::process::id();
        self.icons.begin_snapshot();
        let mut rows = Vec::with_capacity(snapshot.windows.len());
        for window in snapshot.windows {
            if window.skip_taskbar || window.pid == Some(current_pid) {
                continue;
            }
            validate_text("window title", &window.title)?;
            validate_optional_text("application ID", window.app_id.as_deref())?;
            validate_optional_text("WM class", window.wm_class.as_deref())?;
            validate_optional_text("icon name", window.icon_name.as_deref())?;
            let process = window.pid.and_then(process_identity);
            let row_error = if window.truncated_fields {
                Some(resource_limit_error(
                    "decode GNOME window metadata",
                    "one or more text fields exceeded the provider safety limit",
                ))
            } else {
                window.pid.filter(|_| process.is_none()).map(|pid| {
                    BackendError::internal(
                        "GNOME Shell window identity",
                        format!("could not validate process start time for PID {pid}"),
                    )
                })
            };
            let app_key = window.app_id.as_deref().or(window.wm_class.as_deref());
            let icons = self.icons.resolve(window.icon_name.as_deref(), app_key);
            rows.push(ApplicationRow {
                identity: ApplicationIdentity {
                    native_id: window.id,
                    process,
                },
                title: (!window.title.is_empty())
                    .then_some(window.title)
                    .or_else(|| window.app_id.clone())
                    .or(window.wm_class)
                    .unwrap_or_default(),
                show_32_bit_suffix: None,
                status: ApplicationStatus::Running,
                window_station: None,
                desktop: window.workspace.map(|index| (index + 1).to_string()),
                icon_png: icons.small,
                large_icon_png: icons.large,
                allowed_actions: Vec::new(),
                row_error,
            });
        }
        rows.sort_by_key(|row| row.title.to_lowercase());
        Ok(SnapshotData::Applications(ApplicationsData { rows }))
    }

    pub(crate) fn execute(&mut self, _: ActionRequest) -> ActionResult {
        ActionResult::unsupported("the GNOME window provider grants read-only enumeration")
    }
}

fn provider_proxy(connection: &Connection) -> Result<Proxy<'_>, BackendError> {
    Proxy::new(connection, DESTINATION, OBJECT_PATH, INTERFACE)
        .map_err(|error| gnome_error("create GNOME window provider proxy", error))
}

fn is_access_denied(error: &zbus::Error) -> bool {
    matches!(
        error,
        zbus::Error::MethodError(name, _, _) if name.as_str() == ACCESS_DENIED_ERROR
    )
}

pub(crate) fn is_gnome_session() -> bool {
    ["XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP"]
        .into_iter()
        .filter_map(|name| std::env::var(name).ok())
        .any(|value| {
            value
                .split([':', ';'])
                .any(|part| part.eq_ignore_ascii_case("gnome"))
        })
}

fn validate_optional_text(context: &str, value: Option<&str>) -> Result<(), BackendError> {
    match value {
        Some(value) => validate_text(context, value),
        None => Ok(()),
    }
}

fn validate_text(context: &str, value: &str) -> Result<(), BackendError> {
    if value.len() <= MAX_TEXT_BYTES {
        return Ok(());
    }
    Err(BackendError {
        domain: "resource_limit".to_string(),
        code: 1,
        context: format!("decode GNOME {context}"),
        message: format!("text is {} bytes; maximum is {MAX_TEXT_BYTES}", value.len()),
    })
}

fn process_identity(pid: u32) -> Option<ProcessIdentity> {
    let stat = std::fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let closing = stat.rfind(')')?;
    let start_time = stat[closing + 2..]
        .split_whitespace()
        .nth(19)?
        .parse()
        .ok()?;
    Some(ProcessIdentity { pid, start_time })
}

fn gnome_error(context: &str, error: impl std::fmt::Display) -> BackendError {
    BackendError {
        domain: "gnome_shell_extension".to_string(),
        code: -1,
        context: context.to_string(),
        message: error.to_string(),
    }
}

fn resource_limit_error(context: &str, message: impl Into<String>) -> BackendError {
    BackendError {
        domain: "resource_limit".to_string(),
        code: 1,
        context: context.to_string(),
        message: message.into(),
    }
}

#[derive(Deserialize)]
struct ProviderSnapshot {
    protocol_version: u32,
    #[allow(dead_code)]
    generation: u64,
    #[serde(default)]
    truncated: bool,
    windows: Vec<ProviderWindow>,
}

#[derive(Deserialize)]
struct ProviderWindow {
    id: u64,
    title: String,
    app_id: Option<String>,
    wm_class: Option<String>,
    icon_name: Option<String>,
    pid: Option<u32>,
    workspace: Option<u32>,
    skip_taskbar: bool,
    #[serde(default)]
    truncated_fields: bool,
}

#[cfg(test)]
mod tests {
    use super::{MAX_TEXT_BYTES, ProviderSnapshot, validate_text};

    #[test]
    fn decodes_the_versioned_provider_contract() {
        let snapshot: ProviderSnapshot = serde_json::from_str(
            r#"{"protocol_version":1,"generation":8,"windows":[{"id":42,"title":"Editor","app_id":"org.example.Editor","wm_class":null,"icon_name":"org.example.Editor","pid":123,"workspace":0,"skip_taskbar":false}]}"#,
        )
        .expect("provider snapshot");

        assert_eq!(snapshot.protocol_version, 1);
        assert_eq!(snapshot.windows[0].id, 42);
    }

    #[test]
    fn rejects_unbounded_provider_text() {
        assert!(validate_text("title", &"x".repeat(MAX_TEXT_BYTES)).is_ok());
        assert!(validate_text("title", &"x".repeat(MAX_TEXT_BYTES + 1)).is_err());
    }
}
