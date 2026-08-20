// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 新建任务启动器
//
//   文件:       crates/taskmgr-windows/src/launch.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   ShellExecuteW；Windows Shell 文件关联
// --------------------------------------------------------------------------

//! 使用 Windows Shell 打开程序、文件夹、文档或 URI，不调用 `cmd.exe`。

use std::path::Path;
use std::ptr::{null, null_mut};

use taskmgr_core::{ActionResult, BackendError};
use windows_sys::Win32::UI::Shell::ShellExecuteW;
use windows_sys::Win32::UI::WindowsAndMessaging::SW_SHOWNORMAL;

pub(crate) fn run(command_line: &str) -> ActionResult {
    let (target, parameters) = match split_target_and_parameters(command_line) {
        Ok(parts) => parts,
        Err(error) => return ActionResult::failed(error),
    };
    let target = wide_null(&target);
    let parameters = parameters.map(|value| wide_null(&value));
    let parameters_pointer = parameters.as_ref().map_or(null(), |value| value.as_ptr());

    // SAFETY: all optional pointers are null, and the target/parameter UTF-16 buffers remain
    // alive and NUL-terminated for the duration of the synchronous ShellExecuteW call.
    let result = unsafe {
        ShellExecuteW(
            null_mut(),
            null(),
            target.as_ptr(),
            parameters_pointer,
            null(),
            SW_SHOWNORMAL,
        )
    } as isize;
    if result > 32 {
        ActionResult::succeeded()
    } else {
        ActionResult::failed(shell_error(result as i64))
    }
}

fn split_target_and_parameters(input: &str) -> Result<(String, Option<String>), BackendError> {
    let input = input.trim();
    if input.is_empty() {
        return Err(command_line_error(
            "enter a program, document, folder, or URI",
        ));
    }
    if Path::new(input).exists() {
        return Ok((input.to_string(), None));
    }
    if let Some(remainder) = input.strip_prefix('"') {
        let Some(closing) = remainder.find('"') else {
            return Err(command_line_error(
                "the command line contains an unfinished quote",
            ));
        };
        let target = &remainder[..closing];
        if target.is_empty() {
            return Err(command_line_error("the task name cannot be empty"));
        }
        let parameters = remainder[closing + 1..].trim();
        return Ok((
            target.to_string(),
            (!parameters.is_empty()).then(|| parameters.to_string()),
        ));
    }
    let split = input
        .char_indices()
        .find_map(|(index, character)| character.is_whitespace().then_some(index));
    let Some(split) = split else {
        return Ok((input.to_string(), None));
    };
    let target = input[..split].to_string();
    let parameters = input[split..].trim();
    Ok((
        target,
        (!parameters.is_empty()).then(|| parameters.to_string()),
    ))
}

fn wide_null(value: &str) -> Vec<u16> {
    value.encode_utf16().chain(std::iter::once(0)).collect()
}

fn command_line_error(message: impl Into<String>) -> BackendError {
    BackendError {
        domain: "command_line".to_string(),
        code: 1,
        context: "parse run command".to_string(),
        message: message.into(),
    }
}

fn shell_error(code: i64) -> BackendError {
    let message = match code {
        0 => "the operating system is out of memory or resources",
        2 => "the specified file was not found",
        3 => "the specified path was not found",
        5 => "access to the specified file was denied",
        8 => "there was not enough memory to complete the operation",
        26 => "a sharing violation occurred",
        27 => "the file association is incomplete or invalid",
        28 => "the DDE transaction timed out",
        29 => "the DDE transaction failed",
        30 => "another DDE transaction is busy",
        31 => "no application is associated with the specified file type",
        32 => "a required dynamic-link library was not found",
        _ => "Windows Shell could not open the requested task",
    };
    BackendError {
        domain: "shell_execute".to_string(),
        code,
        context: "ShellExecuteW".to_string(),
        message: message.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::split_target_and_parameters;

    #[test]
    fn splits_quoted_executable_and_preserves_parameter_text() {
        assert_eq!(
            split_target_and_parameters(
                "\"C:\\Program Files\\Tool\\tool.exe\" --name \"two words\""
            )
            .expect("valid command line"),
            (
                "C:\\Program Files\\Tool\\tool.exe".to_string(),
                Some("--name \"two words\"".to_string())
            )
        );
    }

    #[test]
    fn rejects_empty_and_unfinished_input() {
        assert!(split_target_and_parameters("   ").is_err());
        assert!(split_target_and_parameters("\"unfinished").is_err());
    }
}
