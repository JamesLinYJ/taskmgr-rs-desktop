// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 用户会话采集与动作
//
//   文件:       crates/taskmgr-windows/src/users.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Windows Terminal Services API；WTSINFOW；WTSSendMessageW
// --------------------------------------------------------------------------

//! 枚举终端服务会话并以 `SessionId + LogonTime` 作为动作身份。
//!
//! 所有 WTS 返回缓冲区由 `WTSFreeMemory` 唯一释放；断开、注销和发送消息前会再次查询
//! 登录时间，无法验证的会话只展示而不暴露动作。

use std::ffi::c_void;
use std::mem::size_of;
use std::ptr::null_mut;
use std::slice;

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, BackendError, SnapshotData, UserAction, UserSession,
    UserSessionIdentity, UsersData,
};
use windows_sys::Win32::Foundation::ERROR_INVALID_DATA;
use windows_sys::Win32::System::RemoteDesktop::{
    WTS_CONNECTSTATE_CLASS, WTS_CURRENT_SERVER_HANDLE, WTSActive, WTSClientName, WTSConnected,
    WTSDisconnectSession, WTSDisconnected, WTSDown, WTSEnumerateSessionsW, WTSFreeMemory, WTSINFOW,
    WTSIdle, WTSInit, WTSListen, WTSLogoffSession, WTSQuerySessionInformationW, WTSReset,
    WTSSendMessageW, WTSSessionInfo, WTSShadow, WTSUserName,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{MB_ICONINFORMATION, MB_OK};

use crate::native::{error_from_code, last_error};

pub(crate) fn sample() -> Result<SnapshotData, BackendError> {
    let mut raw_sessions = null_mut();
    let mut count = 0u32;
    // SAFETY: successful enumeration returns one WTS-owned array transferred to this function.
    if unsafe {
        WTSEnumerateSessionsW(
            WTS_CURRENT_SERVER_HANDLE,
            0,
            1,
            &mut raw_sessions,
            &mut count,
        )
    } == 0
    {
        return Err(last_error("WTSEnumerateSessionsW"));
    }
    // SAFETY: the successful result, including a possible empty allocation, is owned here.
    let memory = unsafe { WtsMemory::from_raw(raw_sessions.cast()) };
    if count > 0 && memory.is_none() {
        return Err(error_from_code(
            "WTSEnumerateSessionsW result",
            ERROR_INVALID_DATA,
        ));
    }
    let entries = if count == 0 {
        &[][..]
    } else {
        // SAFETY: WTS reports `count` contiguous WTS_SESSION_INFOW records in this allocation.
        unsafe { slice::from_raw_parts(raw_sessions, count as usize) }
    };
    let mut sessions = Vec::with_capacity(entries.len());
    for entry in entries {
        let user = match query_session_string(entry.SessionId, WTSUserName) {
            Ok(user) if !user.is_empty() => user,
            _ => continue,
        };
        let info = query_session_info(entry.SessionId).ok();
        let login_time = info
            .as_ref()
            .and_then(|info| u64::try_from(info.LogonTime).ok())
            .filter(|value| *value > 0);
        let idle_seconds = info.as_ref().and_then(|info| {
            (info.CurrentTime >= info.LastInputTime && info.LastInputTime > 0)
                .then(|| u64::try_from((info.CurrentTime - info.LastInputTime) / 10_000_000).ok())
                .flatten()
        });
        let identity = UserSessionIdentity {
            id: entry.SessionId.to_string(),
            login_time,
        };
        let allowed_actions = login_time.map_or_else(Vec::new, |_| {
            vec![
                ActionKind::DisconnectSession,
                ActionKind::LogoffSession,
                ActionKind::SendMessage,
            ]
        });
        let session_name = unsafe { wide_pointer_to_string(entry.pWinStationName) };
        let client_name = query_session_string(entry.SessionId, WTSClientName)
            .ok()
            .filter(|value| !value.is_empty());
        sessions.push(UserSession {
            identity,
            user_name: user,
            session: (!session_name.is_empty()).then_some(session_name),
            client_name,
            state: session_state(entry.State).to_string(),
            idle_seconds,
            allowed_actions,
            row_error: info.is_none().then(|| {
                BackendError::unsupported(
                    "WTS session identity",
                    "the session is visible but its logon time could not be verified",
                )
            }),
        });
    }
    drop(memory);
    sessions.sort_by(|left, right| {
        left.user_name
            .to_lowercase()
            .cmp(&right.user_name.to_lowercase())
            .then_with(|| left.identity.id.cmp(&right.identity.id))
    });
    Ok(SnapshotData::Users(UsersData { sessions }))
}

pub(crate) fn execute(request: ActionRequest) -> ActionResult {
    let ActionRequest::UserSession {
        identity,
        operation,
        title,
        message,
    } = request
    else {
        return ActionResult::unsupported("the requested operation is not a user-session action");
    };
    let result = execute_verified(&identity, operation, title.as_deref(), message.as_deref());
    match result {
        Ok(()) => ActionResult::succeeded(),
        Err(error) => ActionResult::failed(error),
    }
}

fn execute_verified(
    identity: &UserSessionIdentity,
    operation: UserAction,
    title: Option<&str>,
    message: Option<&str>,
) -> Result<(), BackendError> {
    let session_id = identity.id.parse::<u32>().map_err(|_| {
        BackendError::internal(
            "validate WTS session identity",
            "invalid Windows session id",
        )
    })?;
    let Some(expected_login_time) = identity.login_time else {
        return Err(BackendError::internal(
            "validate WTS session identity",
            "an unverified session cannot receive actions",
        ));
    };
    let info = query_session_info(session_id)?;
    if u64::try_from(info.LogonTime).ok() != Some(expected_login_time) {
        return Err(BackendError::internal(
            "validate WTS session identity",
            "the selected session identity changed",
        ));
    }
    let succeeded = match operation {
        UserAction::Disconnect => unsafe {
            WTSDisconnectSession(WTS_CURRENT_SERVER_HANDLE, session_id, 0)
        },
        UserAction::Logoff => unsafe { WTSLogoffSession(WTS_CURRENT_SERVER_HANDLE, session_id, 0) },
        UserAction::SendMessage => {
            let title = title.unwrap_or_default().encode_utf16().collect::<Vec<_>>();
            let message = message
                .unwrap_or_default()
                .encode_utf16()
                .collect::<Vec<_>>();
            let title_bytes = u32::try_from(title.len().saturating_mul(size_of::<u16>()))
                .map_err(|_| BackendError::internal("WTSSendMessageW", "title is too long"))?;
            let message_bytes = u32::try_from(message.len().saturating_mul(size_of::<u16>()))
                .map_err(|_| BackendError::internal("WTSSendMessageW", "message is too long"))?;
            let mut response = 0;
            // SAFETY: UTF-16 buffers remain alive for the synchronous call; lengths are bytes.
            unsafe {
                WTSSendMessageW(
                    WTS_CURRENT_SERVER_HANDLE,
                    session_id,
                    title.as_ptr(),
                    title_bytes,
                    message.as_ptr(),
                    message_bytes,
                    MB_OK | MB_ICONINFORMATION,
                    0,
                    &mut response,
                    0,
                )
            }
        }
    };
    if succeeded == 0 {
        return Err(last_error("Windows Terminal Services action"));
    }
    Ok(())
}

fn query_session_info(session_id: u32) -> Result<WTSINFOW, BackendError> {
    let mut buffer = null_mut();
    let mut bytes = 0u32;
    // SAFETY: successful query transfers one WTS allocation to this function.
    if unsafe {
        WTSQuerySessionInformationW(
            WTS_CURRENT_SERVER_HANDLE,
            session_id,
            WTSSessionInfo,
            &mut buffer,
            &mut bytes,
        )
    } == 0
    {
        return Err(last_error("WTSQuerySessionInformationW WTSSessionInfo"));
    }
    // SAFETY: ownership of the returned allocation is transferred immediately.
    let memory = unsafe { WtsMemory::from_raw(buffer.cast()) }
        .ok_or_else(|| error_from_code("WTS session info buffer", ERROR_INVALID_DATA))?;
    if bytes < size_of::<WTSINFOW>() as u32 {
        return Err(error_from_code("WTS session info size", ERROR_INVALID_DATA));
    }
    // SAFETY: the buffer contains at least one WTSINFOW; read_unaligned avoids alignment assumptions.
    let info = unsafe { std::ptr::read_unaligned(memory.0.cast::<WTSINFOW>()) };
    if info.SessionId != session_id {
        return Err(error_from_code(
            "WTS session id mismatch",
            ERROR_INVALID_DATA,
        ));
    }
    Ok(info)
}

fn query_session_string(session_id: u32, class: i32) -> Result<String, BackendError> {
    let mut buffer = null_mut();
    let mut bytes = 0u32;
    // SAFETY: successful query transfers one WTS allocation to this function.
    if unsafe {
        WTSQuerySessionInformationW(
            WTS_CURRENT_SERVER_HANDLE,
            session_id,
            class,
            &mut buffer,
            &mut bytes,
        )
    } == 0
    {
        return Err(last_error("WTSQuerySessionInformationW string"));
    }
    // SAFETY: ownership of any non-null successful result is transferred immediately.
    let memory = unsafe { WtsMemory::from_raw(buffer.cast()) };
    if bytes == 0 {
        return Ok(String::new());
    }
    let memory = memory.ok_or_else(|| error_from_code("WTS string buffer", ERROR_INVALID_DATA))?;
    if bytes < size_of::<u16>() as u32 || !bytes.is_multiple_of(size_of::<u16>() as u32) {
        return Err(error_from_code("WTS string size", ERROR_INVALID_DATA));
    }
    // SAFETY: reported byte length is an integral number of UTF-16 code units in this allocation.
    let values = unsafe { slice::from_raw_parts(memory.0.cast::<u16>(), bytes as usize / 2) };
    let length = values
        .iter()
        .position(|value| *value == 0)
        .ok_or_else(|| error_from_code("WTS string terminator", ERROR_INVALID_DATA))?;
    Ok(String::from_utf16_lossy(&values[..length]))
}

unsafe fn wide_pointer_to_string(pointer: *const u16) -> String {
    if pointer.is_null() {
        return String::new();
    }
    let mut length = 0usize;
    // SAFETY: WTS_SESSION_INFOW guarantees a null-terminated string within its owned allocation.
    while unsafe { *pointer.add(length) } != 0 {
        length += 1;
    }
    // SAFETY: the preceding scan found the terminator, so the range is initialized and readable.
    String::from_utf16_lossy(unsafe { slice::from_raw_parts(pointer, length) })
}

const fn session_state(state: WTS_CONNECTSTATE_CLASS) -> &'static str {
    if state == WTSActive {
        "Active"
    } else if state == WTSConnected {
        "Connected"
    } else if state == WTSDisconnected {
        "Disconnected"
    } else if state == WTSIdle {
        "Idle"
    } else if state == WTSListen {
        "Listen"
    } else if state == WTSReset {
        "Reset"
    } else if state == WTSDown {
        "Down"
    } else if state == WTSInit {
        "Initializing"
    } else if state == WTSShadow {
        "Shadow"
    } else {
        "Unknown"
    }
}

struct WtsMemory(*mut c_void);

impl WtsMemory {
    /// # Safety
    ///
    /// `raw` must be null or a fresh allocation returned by a WTS API.
    unsafe fn from_raw(raw: *mut c_void) -> Option<Self> {
        (!raw.is_null()).then_some(Self(raw))
    }
}

impl Drop for WtsMemory {
    fn drop(&mut self) {
        // SAFETY: self uniquely owns the original WTS allocation.
        unsafe { WTSFreeMemory(self.0) };
    }
}
