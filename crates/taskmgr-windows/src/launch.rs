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
//   参考标准:   IShellDispatch；ShellAboutW；ShellExecuteW；Windows Shell 文件关联
// --------------------------------------------------------------------------

//! 使用 Windows Shell 打开系统“运行”对话框，或启动程序、文件夹、文档和 URI。

use std::mem::size_of;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::ptr::{null, null_mut};

use taskmgr_core::{ActionResult, BackendError, diagnostics};
use windows::Win32::System::Com::{
    CLSCTX_ALL, COINIT_APARTMENTTHREADED, CoCreateInstance, CoInitializeEx, CoUninitialize,
};
use windows::Win32::UI::Shell::{IShellDispatch, Shell};
use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
use windows_sys::Win32::System::Threading::GetCurrentProcessId;
use windows_sys::Win32::UI::Controls::Dialogs::{
    CommDlgExtendedError, GetSaveFileNameW, OFN_EXPLORER, OFN_PATHMUSTEXIST, OPENFILENAMEW,
};
use windows_sys::Win32::UI::Shell::{ShellAboutW, ShellExecuteW};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    GetForegroundWindow, GetWindowThreadProcessId, IMAGE_ICON, LR_DEFAULTSIZE, LR_SHARED,
    LoadImageW, SW_SHOWNORMAL,
};

const APPLICATION_ICON_RESOURCE: usize = 101;

struct ComApartment;

impl ComApartment {
    fn initialize() -> Result<Self, i32> {
        // SAFETY: this guard balances every successful initialization, including S_FALSE,
        // with CoUninitialize on the same backend worker thread.
        let result = unsafe { CoInitializeEx(None, COINIT_APARTMENTTHREADED) };
        if result.is_ok() {
            Ok(Self)
        } else {
            Err(result.0)
        }
    }
}

impl Drop for ComApartment {
    fn drop(&mut self) {
        // SAFETY: construction only succeeds after this thread has acquired one COM
        // initialization reference.
        unsafe { CoUninitialize() };
    }
}

pub(crate) fn show_system_run_dialog() -> ActionResult {
    match try_show_system_run_dialog() {
        Ok(()) => ActionResult::succeeded(),
        Err(code) => ActionResult::failed(BackendError {
            domain: "windows_shell".to_string(),
            code: i64::from(code),
            context: "IShellDispatch::FileRun".to_string(),
            message: format!(
                "Windows could not display the system Run dialog (HRESULT 0x{:08X})",
                code as u32
            ),
        }),
    }
}

pub(crate) fn show_system_about_dialog(title: &str) -> ActionResult {
    let title = title.trim();
    if title.is_empty() {
        return ActionResult::failed(BackendError::internal(
            "ShellAboutW",
            "the About dialog title must not be empty",
        ));
    }
    let title = wide_null(title);
    // SAFETY: null requests the current executable module. The returned module is borrowed and
    // remains loaded for the process lifetime. LR_SHARED likewise returns a system-owned icon
    // that must not be destroyed by this DLL.
    let module = unsafe { GetModuleHandleW(null()) };
    let icon = if module.is_null() {
        null_mut()
    } else {
        // SAFETY: resource 101 is IDI_APP_ICON in the Flutter runner. MAKEINTRESOURCE is the
        // integer-valued pointer convention documented for LoadImageW.
        unsafe {
            LoadImageW(
                module,
                APPLICATION_ICON_RESOURCE as *const u16,
                IMAGE_ICON,
                0,
                0,
                LR_DEFAULTSIZE | LR_SHARED,
            )
        }
    };
    // The backend runs on a worker thread, so GetActiveWindow cannot find the Flutter window.
    // Use the foreground window only when it belongs to this process; otherwise ShellAboutW's
    // documented null-parent behavior avoids attaching the modal dialog to another application.
    let parent = current_process_foreground_window();
    // SAFETY: title is NUL-terminated and remains alive for the synchronous call. parent may be
    // null by contract; icon is either null or the borrowed LR_SHARED application resource.
    let shown = unsafe { ShellAboutW(parent, title.as_ptr(), null(), icon) };
    if shown != 0 {
        ActionResult::succeeded()
    } else {
        ActionResult::failed(last_shell_error("ShellAboutW"))
    }
}

pub(crate) fn open_diagnostic_folder() -> ActionResult {
    let Some(directory) = diagnostics::session_directory() else {
        return ActionResult::failed(BackendError::internal(
            "open diagnostic folder",
            "the diagnostic session directory is unavailable",
        ));
    };
    shell_open_path(&directory, "open diagnostic folder")
}

pub(crate) fn save_diagnostic_bundle() -> ActionResult {
    let destination = match choose_diagnostic_bundle_destination() {
        Ok(Some(path)) => path,
        Ok(None) => return ActionResult::succeeded(),
        Err(error) => return ActionResult::failed(error),
    };
    match diagnostics::export_bundle(&destination) {
        Ok(()) => ActionResult::succeeded(),
        Err(message) => ActionResult::failed(BackendError {
            domain: "diagnostics".to_string(),
            code: 1,
            context: "export diagnostic bundle".to_string(),
            message,
        }),
    }
}

pub(crate) fn restart_with_detailed_diagnostics() -> ActionResult {
    let executable = match std::env::current_exe() {
        Ok(path) => path,
        Err(error) => {
            return ActionResult::failed(BackendError::io(
                "resolve current executable for diagnostic restart",
                &error,
            ));
        }
    };
    match Command::new(executable)
        .args(diagnostics::detailed_restart_arguments())
        .spawn()
    {
        Ok(_) => ActionResult::succeeded(),
        Err(error) => ActionResult::failed(BackendError::io(
            "restart with detailed diagnostics",
            &error,
        )),
    }
}

fn choose_diagnostic_bundle_destination() -> Result<Option<PathBuf>, BackendError> {
    const MAX_PATH_UNITS: usize = 32_768;
    let mut buffer = vec![0u16; MAX_PATH_UNITS];
    let default_name = wide_null(&diagnostics::default_bundle_name());
    let copy_length = default_name.len().min(buffer.len());
    buffer[..copy_length].copy_from_slice(&default_name[..copy_length]);
    let filter = wide_double_null(&[
        "Diagnostic bundle (*.zip)",
        "*.zip",
        "All files (*.*)",
        "*.*",
    ]);
    let title = wide_null("Save Diagnostic Bundle");
    let extension = wide_null("zip");
    let mut dialog = OPENFILENAMEW {
        lStructSize: size_of::<OPENFILENAMEW>() as u32,
        hwndOwner: current_process_foreground_window(),
        lpstrFilter: filter.as_ptr(),
        lpstrFile: buffer.as_mut_ptr(),
        nMaxFile: buffer.len() as u32,
        lpstrTitle: title.as_ptr(),
        Flags: OFN_EXPLORER | OFN_PATHMUSTEXIST,
        lpstrDefExt: extension.as_ptr(),
        ..unsafe { std::mem::zeroed() }
    };
    // SAFETY: dialog and all UTF-16 buffers stay live and writable for the synchronous call.
    if unsafe { GetSaveFileNameW(&mut dialog) } != 0 {
        let length = buffer
            .iter()
            .position(|unit| *unit == 0)
            .unwrap_or(buffer.len());
        return Ok(Some(PathBuf::from(String::from_utf16_lossy(
            &buffer[..length],
        ))));
    }
    // SAFETY: this value-only query must immediately follow the common-dialog failure.
    let error = unsafe { CommDlgExtendedError() };
    if error == 0 {
        Ok(None)
    } else {
        Err(BackendError {
            domain: "common_dialog".to_string(),
            code: i64::from(error),
            context: "GetSaveFileNameW diagnostic bundle".to_string(),
            message: format!("the diagnostic Save dialog failed (0x{error:08X})"),
        })
    }
}

fn shell_open_path(path: &Path, context: &str) -> ActionResult {
    let verb = wide_null("open");
    let path = wide_null(&path.to_string_lossy());
    // SAFETY: verb/path are NUL-terminated for this synchronous call; the parent is either null
    // or a verified top-level window belonging to this process.
    let result = unsafe {
        ShellExecuteW(
            current_process_foreground_window(),
            verb.as_ptr(),
            path.as_ptr(),
            null(),
            null(),
            SW_SHOWNORMAL,
        )
    } as isize;
    if result > 32 {
        ActionResult::succeeded()
    } else {
        let mut error = shell_error(result as i64);
        error.context = context.to_string();
        ActionResult::failed(error)
    }
}

fn current_process_foreground_window() -> windows_sys::Win32::Foundation::HWND {
    // The backend worker has no active window. A foreground HWND is accepted only after its PID
    // is verified against this process, so a dialog is never parented to another application.
    let foreground = unsafe { GetForegroundWindow() };
    let mut foreground_pid = 0u32;
    if !foreground.is_null() {
        // SAFETY: foreground is borrowed and foreground_pid is a live writable output.
        unsafe { GetWindowThreadProcessId(foreground, &mut foreground_pid) };
    }
    // SAFETY: GetCurrentProcessId has no pointer or ownership preconditions.
    if foreground_pid == unsafe { GetCurrentProcessId() } {
        foreground
    } else {
        null_mut()
    }
}

fn try_show_system_run_dialog() -> Result<(), i32> {
    let _apartment = ComApartment::initialize()?;
    // SAFETY: COM is initialized for this thread and Shell is the documented local Shell
    // automation class implementing IShellDispatch.
    let shell: IShellDispatch =
        unsafe { CoCreateInstance(&Shell, None, CLSCTX_ALL) }.map_err(|error| error.code().0)?;
    // SAFETY: FileRun has no parameters and displays the system-owned Run dialog.
    unsafe { shell.FileRun() }.map_err(|error| error.code().0)
}

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

fn wide_double_null(values: &[&str]) -> Vec<u16> {
    let mut output = Vec::new();
    for value in values {
        output.extend(value.encode_utf16());
        output.push(0);
    }
    output.push(0);
    output
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

fn last_shell_error(context: &str) -> BackendError {
    // SAFETY: read immediately after the failing Shell call on the same thread.
    let code = unsafe { windows_sys::Win32::Foundation::GetLastError() };
    BackendError {
        domain: "win32".to_string(),
        code: i64::from(code),
        context: context.to_string(),
        message: format!("Windows Shell could not display the dialog (Win32 error {code})"),
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
