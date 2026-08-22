// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 提权白名单 helper
//
//   文件:       crates/taskmgr-helper/src/main.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   polkit pkexec；Windows UAC；Linux pidfd；项目 helper 协议 v1
// --------------------------------------------------------------------------

//! 执行一个经版本和 nonce 验证的白名单动作。
//!
//! 正式包通过受限 pipe/socket 传入本协议；该进程不会解析 shell 命令或任意路径。

use std::io::{Read, Write};

use serde::{Deserialize, Serialize};
use taskmgr_core::{ActionRequest, ActionResult, BackendError, PROTOCOL_VERSION, PlatformProvider};

const MAX_REQUEST_BYTES: u64 = 65_536;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct HelperRequest {
    protocol_version: u16,
    nonce: String,
    action: ActionRequest,
}

#[derive(Serialize)]
struct HelperResponse {
    protocol_version: u16,
    nonce: String,
    result: ActionResult,
}

fn main() {
    let code = run().unwrap_or_else(|error| {
        let response = HelperResponse {
            protocol_version: PROTOCOL_VERSION,
            nonce: String::new(),
            result: ActionResult::failed(error),
        };
        let _ = serde_json::to_writer(std::io::stdout().lock(), &response);
        2
    });
    std::process::exit(code);
}

fn run() -> Result<i32, BackendError> {
    if std::env::args_os().nth(1).as_deref() != Some(std::ffi::OsStr::new("--stdio-single-request"))
    {
        return Err(BackendError::internal(
            "helper startup",
            "the helper must be launched by the taskmgr-rs broker",
        ));
    }
    let mut bytes = Vec::new();
    std::io::stdin()
        .take(MAX_REQUEST_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| BackendError::io("read helper request", &error))?;
    if bytes.len() as u64 > MAX_REQUEST_BYTES {
        return Err(BackendError::internal(
            "helper request",
            "request exceeds the protocol size limit",
        ));
    }
    let request: HelperRequest = serde_json::from_slice(&bytes).map_err(|error| BackendError {
        domain: "helper_protocol".to_string(),
        code: 1,
        context: "decode helper request".to_string(),
        message: error.to_string(),
    })?;
    validate_request(&request)?;
    let mut provider = platform_provider();
    let result = provider.execute_action(request.action);
    let response = HelperResponse {
        protocol_version: PROTOCOL_VERSION,
        nonce: request.nonce,
        result,
    };
    let stdout = std::io::stdout();
    let mut stdout = stdout.lock();
    serde_json::to_writer(&mut stdout, &response).map_err(|error| BackendError {
        domain: "helper_protocol".to_string(),
        code: 2,
        context: "encode helper response".to_string(),
        message: error.to_string(),
    })?;
    stdout
        .write_all(b"\n")
        .map_err(|error| BackendError::io("write helper response", &error))?;
    Ok(0)
}

fn validate_request(request: &HelperRequest) -> Result<(), BackendError> {
    if request.protocol_version != PROTOCOL_VERSION {
        return Err(BackendError::internal(
            "helper protocol",
            "protocol version does not match the GUI",
        ));
    }
    if request.nonce.len() != 64 || !request.nonce.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(BackendError::internal(
            "helper protocol",
            "nonce must contain exactly 64 hexadecimal characters",
        ));
    }
    if !is_whitelisted(&request.action) {
        return Err(BackendError::internal(
            "helper protocol",
            "requested action is not in the helper whitelist",
        ));
    }
    Ok(())
}

fn is_whitelisted(action: &ActionRequest) -> bool {
    is_whitelisted_with_handle_bound_affinity(action, cfg!(windows))
}

fn is_whitelisted_with_handle_bound_affinity(
    action: &ActionRequest,
    allow_handle_bound_affinity: bool,
) -> bool {
    matches!(
        action,
        ActionRequest::EndProcess { .. }
            | ActionRequest::SetPriority { .. }
            | ActionRequest::UserSession { .. }
    ) || (allow_handle_bound_affinity && matches!(action, ActionRequest::SetAffinity { .. }))
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
    compile_error!("taskmgr-rs helper supports only Windows and Linux");
}

#[cfg(test)]
mod tests {
    use taskmgr_core::{
        ActionRequest, ApplicationIdentity, ProcessIdentity, WindowAction, WindowArrangement,
    };

    use super::{
        HelperRequest, PROTOCOL_VERSION, is_whitelisted, is_whitelisted_with_handle_bound_affinity,
        validate_request,
    };

    fn process_action() -> ActionRequest {
        ActionRequest::EndProcess {
            identity: ProcessIdentity {
                pid: 42,
                start_time: 7,
            },
            include_descendants: false,
        }
    }

    fn request(action: ActionRequest) -> HelperRequest {
        HelperRequest {
            protocol_version: PROTOCOL_VERSION,
            nonce: "ab".repeat(32),
            action,
        }
    }

    #[test]
    fn accepts_only_the_current_protocol_and_a_256_bit_hex_nonce() {
        assert!(validate_request(&request(process_action())).is_ok());

        let mut wrong_version = request(process_action());
        wrong_version.protocol_version = PROTOCOL_VERSION + 1;
        assert!(validate_request(&wrong_version).is_err());

        let mut short_nonce = request(process_action());
        short_nonce.nonce.pop();
        assert!(validate_request(&short_nonce).is_err());

        let mut non_hex_nonce = request(process_action());
        non_hex_nonce.nonce.replace_range(0..1, "z");
        assert!(validate_request(&non_hex_nonce).is_err());
    }

    #[test]
    fn linux_helper_policy_rejects_pid_only_scheduling_mutations() {
        let identity = ProcessIdentity {
            pid: 42,
            start_time: 7,
        };
        let nice = ActionRequest::SetNice {
            identity: identity.clone(),
            nice: 0,
        };
        let affinity = ActionRequest::SetAffinity {
            identity,
            logical_processors: vec![0],
        };

        assert!(!is_whitelisted_with_handle_bound_affinity(&nice, false));
        assert!(!is_whitelisted_with_handle_bound_affinity(&affinity, false));
        assert!(!is_whitelisted_with_handle_bound_affinity(&nice, true));
        assert!(is_whitelisted_with_handle_bound_affinity(&affinity, true));
        assert!(is_whitelisted_with_handle_bound_affinity(
            &process_action(),
            false
        ));

        if cfg!(target_os = "linux") {
            assert!(validate_request(&request(nice)).is_err());
            assert!(validate_request(&request(affinity)).is_err());
        } else if cfg!(windows) {
            assert!(validate_request(&request(nice)).is_err());
            assert!(validate_request(&request(affinity)).is_ok());
        }
    }

    #[test]
    fn rejects_nonprivileged_ui_actions_outside_the_helper_whitelist() {
        let window_action = ActionRequest::Window {
            identity: ApplicationIdentity {
                native_id: 1,
                process: None,
            },
            operation: WindowAction::Close,
        };
        assert!(!is_whitelisted(&window_action));
        assert!(validate_request(&request(window_action)).is_err());

        let arrangement_action = ActionRequest::ArrangeWindows {
            identities: vec![ApplicationIdentity {
                native_id: 1,
                process: None,
            }],
            arrangement: WindowArrangement::Cascade,
        };
        assert!(!is_whitelisted(&arrangement_action));
        assert!(validate_request(&request(arrangement_action)).is_err());

        let run_action = ActionRequest::RunTask {
            command_line: "program --argument".to_string(),
        };
        assert!(!is_whitelisted(&run_action));
        assert!(validate_request(&request(run_action)).is_err());

        assert!(!is_whitelisted(&ActionRequest::ShowRunDialog));
        assert!(validate_request(&request(ActionRequest::ShowRunDialog)).is_err());

        let about_action = ActionRequest::ShowAboutDialog {
            title: "Task Manager".to_string(),
        };
        assert!(!is_whitelisted(&about_action));
        assert!(validate_request(&request(about_action)).is_err());
    }

    #[test]
    fn rejects_unknown_top_level_protocol_fields() {
        let json = r#"{
            "protocol_version": 1,
            "nonce": "abababababababababababababababababababababababababababababababab",
            "action": {
                "action": "end_process",
                "identity": { "pid": 42, "start_time": 7 },
                "include_descendants": false
            },
            "command": "not-allowed"
        }"#;
        assert!(serde_json::from_str::<HelperRequest>(json).is_err());
    }
}
