// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 原生资源与错误边界
//
//   文件:       crates/taskmgr-windows/src/native.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Win32 HANDLE；CloseHandle；GetLastError
// --------------------------------------------------------------------------

//! 集中管理 Windows 内核句柄所有权和结构化 Win32 错误。
//!
//! 每个成功返回的 `HANDLE` 立即进入唯一所有者；析构只调用一次 `CloseHandle`。

use std::io;

use taskmgr_core::BackendError;
use windows_sys::Win32::Foundation::{
    CloseHandle, ERROR_GEN_FAILURE, GetLastError, HANDLE, INVALID_HANDLE_VALUE,
};

pub(crate) struct OwnedHandle(HANDLE);

impl OwnedHandle {
    /// # Safety
    ///
    /// `raw` 必须是当前调用者拥有、并应由 `CloseHandle` 释放的新句柄。
    pub(crate) unsafe fn from_raw(raw: HANDLE) -> Option<Self> {
        (!raw.is_null() && raw != INVALID_HANDLE_VALUE).then_some(Self(raw))
    }

    pub(crate) const fn as_raw(&self) -> HANDLE {
        self.0
    }
}

impl Drop for OwnedHandle {
    fn drop(&mut self) {
        // SAFETY: `OwnedHandle` is the unique owner of this valid kernel handle.
        unsafe {
            let _ = CloseHandle(self.0);
        }
    }
}

pub(crate) fn last_error(context: impl Into<String>) -> BackendError {
    // SAFETY: GetLastError has no preconditions and is read immediately after the failed call.
    let code = unsafe { GetLastError() };
    error_from_code(context, if code == 0 { ERROR_GEN_FAILURE } else { code })
}

pub(crate) fn error_from_code(context: impl Into<String>, code: u32) -> BackendError {
    BackendError {
        domain: "win32".to_string(),
        code: i64::from(code),
        context: context.into(),
        message: io::Error::from_raw_os_error(code as i32).to_string(),
    }
}

pub(crate) const fn filetime_to_u64(value: windows_sys::Win32::Foundation::FILETIME) -> u64 {
    ((value.dwHighDateTime as u64) << 32) | value.dwLowDateTime as u64
}

pub(crate) fn wide_slice_to_string(value: &[u16]) -> String {
    let length = value
        .iter()
        .position(|character| *character == 0)
        .unwrap_or(value.len());
    String::from_utf16_lossy(&value[..length])
}
