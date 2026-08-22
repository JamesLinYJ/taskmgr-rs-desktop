// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 顶层应用窗口采集与动作
//
//   文件:       crates/taskmgr-windows/src/applications.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   EnumWindows；IsWow64Process2；WM_GETICON；GDI DIB；TileWindows/CascadeWindows
// --------------------------------------------------------------------------

//! 枚举当前交互桌面的无 owner 可见顶层窗口，并在每次动作前重新验证窗口与进程身份。
//!
//! 回调上下文只在同步 `EnumWindows` 调用期间有效；不会把 `HWND` 暴露到公共模型之外。

use std::collections::{HashMap, HashSet};
use std::mem::size_of;
use std::ptr::{null, null_mut};
use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, ApplicationIdentity, ApplicationRow,
    ApplicationStatus, ApplicationsData, BackendError, ProcessIdentity, SnapshotData, WindowAction,
    WindowArrangement,
};
use windows_sys::Win32::Foundation::{ERROR_INVALID_DATA, FILETIME, HANDLE, HWND, LPARAM};
use windows_sys::Win32::Graphics::Gdi::{
    BI_RGB, BITMAPINFO, BITMAPINFOHEADER, CreateCompatibleDC, CreateDIBSection, DIB_RGB_COLORS,
    DeleteDC, DeleteObject, HBITMAP, HDC, HGDIOBJ, SelectObject,
};
use windows_sys::Win32::System::StationsAndDesktops::{
    GetProcessWindowStation, GetThreadDesktop, GetUserObjectInformationW, UOI_NAME,
};
use windows_sys::Win32::System::SystemInformation::{
    IMAGE_FILE_MACHINE_AMD64, IMAGE_FILE_MACHINE_ARM, IMAGE_FILE_MACHINE_ARM64,
    IMAGE_FILE_MACHINE_ARMNT, IMAGE_FILE_MACHINE_I386, IMAGE_FILE_MACHINE_IA64,
    IMAGE_FILE_MACHINE_THUMB, IMAGE_FILE_MACHINE_UNKNOWN,
};
use windows_sys::Win32::System::Threading::{
    GetCurrentProcessId, GetCurrentThreadId, GetProcessTimes, IsWow64Process2, OpenProcess,
    PROCESS_QUERY_LIMITED_INFORMATION,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    CascadeWindows, CopyIcon, DI_NORMAL, DestroyIcon, DrawIconEx, EnumWindows, GCL_HICON,
    GCL_HICONSM, GW_OWNER, GetClassLongPtrW, GetDesktopWindow, GetSystemMetrics, GetWindow,
    GetWindowTextLengthW, GetWindowTextW, GetWindowThreadProcessId, HICON, IsHungAppWindow,
    IsIconic, IsWindow, IsWindowVisible, MDITILE_HORIZONTAL, MDITILE_VERTICAL, PostMessageW,
    SM_CXICON, SM_CXSMICON, SM_CYICON, SM_CYSMICON, SMTO_ABORTIFHUNG, SMTO_NORMAL, SW_MAXIMIZE,
    SW_MINIMIZE, SW_RESTORE, SendMessageTimeoutW, SetForegroundWindow, ShowWindow, TileWindows,
    WM_CLOSE, WM_GETICON,
};
use windows_sys::core::BOOL;

use crate::native::{OwnedHandle, error_from_code, filetime_to_u64, last_error};

pub(crate) struct ApplicationsSampler {
    desktop_names: Option<(String, String)>,
    icon_cache: HashMap<IconIdentity, WindowIconPngs>,
    bitness_by_process: HashMap<ProcessIdentity, bool>,
}

impl ApplicationsSampler {
    pub(crate) fn new() -> Self {
        Self {
            desktop_names: None,
            icon_cache: HashMap::new(),
            bitness_by_process: HashMap::new(),
        }
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        if self.desktop_names.is_none() {
            self.desktop_names = current_desktop_names().ok();
        }
        let mut context = EnumerationContext {
            rows: Vec::with_capacity(64),
            identities: HashMap::with_capacity(64),
            current_pid: unsafe { GetCurrentProcessId() },
            window_station: self
                .desktop_names
                .as_ref()
                .map(|(station, _)| station.clone()),
            desktop: self
                .desktop_names
                .as_ref()
                .map(|(_, desktop)| desktop.clone()),
            icon_cache: std::mem::take(&mut self.icon_cache),
            seen_icon_identities: HashSet::with_capacity(64),
            bitness_by_process: std::mem::take(&mut self.bitness_by_process),
            seen_processes: HashSet::with_capacity(64),
        };
        // SAFETY: `context` lives for the complete synchronous enumeration and the callback never
        // retains its pointer. The callback catches per-window failures by skipping that window.
        let succeeded = unsafe {
            EnumWindows(
                Some(enumerate_window),
                (&mut context as *mut EnumerationContext) as LPARAM,
            )
        };
        let EnumerationContext {
            mut rows,
            mut icon_cache,
            seen_icon_identities,
            mut bitness_by_process,
            seen_processes,
            ..
        } = context;
        icon_cache.retain(|identity, _| seen_icon_identities.contains(identity));
        bitness_by_process.retain(|identity, _| seen_processes.contains(identity));
        self.icon_cache = icon_cache;
        self.bitness_by_process = bitness_by_process;
        if succeeded == 0 {
            return Err(last_error("EnumWindows applications sampling"));
        }
        rows.sort_by_key(|row| row.title.to_lowercase());
        Ok(SnapshotData::Applications(ApplicationsData { rows }))
    }

    pub(crate) fn execute(&mut self, request: ActionRequest) -> ActionResult {
        let outcome = match request {
            ActionRequest::Window {
                identity,
                operation,
            } => execute_window_action(&identity, operation),
            ActionRequest::ArrangeWindows {
                identities,
                arrangement,
            } => execute_window_arrangement(&identities, arrangement),
            _ => {
                return ActionResult::unsupported(
                    "the requested operation is not a Windows window action",
                );
            }
        };
        match outcome {
            Ok(()) => ActionResult::succeeded(),
            Err(error) => ActionResult::failed(error),
        }
    }
}

struct EnumerationContext {
    rows: Vec<ApplicationRow>,
    identities: HashMap<u32, Option<ProcessIdentity>>,
    current_pid: u32,
    window_station: Option<String>,
    desktop: Option<String>,
    icon_cache: HashMap<IconIdentity, WindowIconPngs>,
    seen_icon_identities: HashSet<IconIdentity>,
    bitness_by_process: HashMap<ProcessIdentity, bool>,
    seen_processes: HashSet<ProcessIdentity>,
}

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
struct IconIdentity {
    native_id: u64,
    process: ProcessIdentity,
    is_hung: bool,
}

#[derive(Clone, Debug, Default)]
struct WindowIconPngs {
    small: Option<Vec<u8>>,
    large: Option<Vec<u8>>,
}

unsafe extern "system" fn enumerate_window(hwnd: HWND, lparam: LPARAM) -> BOOL {
    // SAFETY: EnumWindows invokes this callback synchronously with our live context pointer.
    let context = unsafe { &mut *(lparam as *mut EnumerationContext) };
    // SAFETY: each queried HWND is supplied by EnumWindows and is only used during the callback.
    if unsafe {
        IsWindowVisible(hwnd) == 0 || !GetWindow(hwnd, GW_OWNER).is_null() || IsWindow(hwnd) == 0
    } {
        return 1;
    }
    let title = unsafe { window_title(hwnd) };
    if title.is_empty() || title.eq_ignore_ascii_case("Program Manager") {
        return 1;
    }
    let mut pid = 0u32;
    // SAFETY: output points to initialized stack storage and HWND remains valid for this callback.
    if unsafe { GetWindowThreadProcessId(hwnd, &mut pid) } == 0
        || pid == 0
        || pid == context.current_pid
    {
        return 1;
    }
    let process = context
        .identities
        .entry(pid)
        .or_insert_with(|| query_process_identity(pid).ok())
        .clone();
    let Some(process) = process else {
        return 1;
    };
    context.seen_processes.insert(process.clone());
    let mut row_error = None;
    let show_32_bit_suffix = if let Some(cached) = context.bitness_by_process.get(&process).copied()
    {
        Some(cached)
    } else {
        match query_process_needs_32_bit_suffix(&process) {
            Ok(detected) => {
                context.bitness_by_process.insert(process.clone(), detected);
                Some(detected)
            }
            Err(error) => {
                row_error = Some(error);
                None
            }
        }
    };
    let is_hung = unsafe { IsHungAppWindow(hwnd) } != 0;
    let icon_identity = IconIdentity {
        native_id: hwnd as usize as u64,
        process: process.clone(),
        is_hung,
    };
    context.seen_icon_identities.insert(icon_identity.clone());
    let icons = context
        .icon_cache
        .entry(icon_identity)
        .or_insert_with(|| window_icons_png(hwnd, is_hung))
        .clone();
    context.rows.push(ApplicationRow {
        identity: ApplicationIdentity {
            native_id: hwnd as usize as u64,
            process: Some(process),
        },
        title,
        show_32_bit_suffix,
        status: if is_hung {
            ApplicationStatus::NotResponding
        } else {
            ApplicationStatus::Running
        },
        window_station: context.window_station.clone(),
        desktop: context.desktop.clone(),
        icon_png: icons.small,
        large_icon_png: icons.large,
        allowed_actions: vec![
            ActionKind::SwitchTo,
            ActionKind::BringToFront,
            ActionKind::Minimize,
            ActionKind::Maximize,
            ActionKind::EndTask,
        ],
        row_error,
    });
    1
}

unsafe fn window_title(hwnd: HWND) -> String {
    // SAFETY: caller supplies an HWND from EnumWindows; buffers stay allocated for the calls.
    let length = unsafe { GetWindowTextLengthW(hwnd) };
    let Ok(length) = usize::try_from(length) else {
        return String::new();
    };
    if length == 0 {
        return String::new();
    }
    let Some(capacity) = length.checked_add(1) else {
        return String::new();
    };
    let Ok(capacity_i32) = i32::try_from(capacity) else {
        return String::new();
    };
    let mut buffer = vec![0u16; capacity];
    // SAFETY: buffer has `capacity_i32` UTF-16 elements and remains valid for the call.
    let actual = unsafe { GetWindowTextW(hwnd, buffer.as_mut_ptr(), capacity_i32) };
    let Ok(actual) = usize::try_from(actual.max(0)) else {
        return String::new();
    };
    String::from_utf16_lossy(&buffer[..actual.min(length)])
}

const ICON_FETCH_TIMEOUT_MS: u32 = 100;
const ICON_SMALL: usize = 0;
const ICON_BIG: usize = 1;
const ICON_SMALL2: usize = 2;

fn window_icons_png(hwnd: HWND, is_hung: bool) -> WindowIconPngs {
    let (small, large) = copy_window_icons(hwnd, is_hung);
    // SAFETY: these metrics have no pointer arguments and are read on the sampling worker.
    let small_width = unsafe { GetSystemMetrics(SM_CXSMICON) }.max(1);
    // SAFETY: same as above.
    let small_height = unsafe { GetSystemMetrics(SM_CYSMICON) }.max(1);
    // SAFETY: same as above.
    let large_width = unsafe { GetSystemMetrics(SM_CXICON) }.max(1);
    // SAFETY: same as above.
    let large_height = unsafe { GetSystemMetrics(SM_CYICON) }.max(1);
    WindowIconPngs {
        small: small.and_then(|icon| encode_icon_png(&icon, small_width, small_height)),
        large: large.and_then(|icon| encode_icon_png(&icon, large_width, large_height)),
    }
}

fn encode_icon_png(icon: &OwnedIcon, width: i32, height: i32) -> Option<Vec<u8>> {
    let black = render_icon_composite(icon.as_raw(), width, height, 0)?;
    let white = render_icon_composite(icon.as_raw(), width, height, u8::MAX)?;
    let rgba = recover_rgba_from_composites(&black, &white)?;
    encode_rgba_png(width as u32, height as u32, &rgba)
}

fn copy_window_icons(hwnd: HWND, is_hung: bool) -> (Option<OwnedIcon>, Option<OwnedIcon>) {
    let (small2, big) = if is_hung {
        (null_mut(), null_mut())
    } else {
        (
            query_window_icon(hwnd, ICON_SMALL2),
            query_window_icon(hwnd, ICON_BIG),
        )
    };
    let small = if is_hung || (!small2.is_null() && !big.is_null()) {
        null_mut()
    } else {
        query_window_icon(hwnd, ICON_SMALL)
    };
    let class_small = if small2.is_null() && small.is_null() {
        // SAFETY: the live HWND was supplied by EnumWindows; class icons are borrowed values.
        (unsafe { GetClassLongPtrW(hwnd, GCL_HICONSM) }) as HICON
    } else {
        null_mut()
    };
    let class_large = if big.is_null() {
        // SAFETY: same as above, querying the class large icon.
        (unsafe { GetClassLongPtrW(hwnd, GCL_HICON) }) as HICON
    } else {
        null_mut()
    };
    let small_source = [small2, small, big, class_small, class_large]
        .into_iter()
        .find(|icon| !icon.is_null())
        .unwrap_or(null_mut());
    let large_source = [big, small, small2, class_large, class_small]
        .into_iter()
        .find(|icon| !icon.is_null())
        .unwrap_or(null_mut());
    (
        copy_icon_source(small_source),
        copy_icon_source(large_source),
    )
}

fn copy_icon_source(source: HICON) -> Option<OwnedIcon> {
    if source.is_null() {
        return None;
    }
    // SAFETY: the non-null source is borrowed and CopyIcon returns a new caller-owned icon.
    unsafe { OwnedIcon::from_raw(CopyIcon(source)) }
}

fn query_window_icon(hwnd: HWND, icon_type: usize) -> HICON {
    let mut result = 0usize;
    // SAFETY: no pointers cross the target process; the bounded timeout prevents a hung window
    // from indefinitely delaying the Rust sampling worker.
    unsafe {
        let _ = SendMessageTimeoutW(
            hwnd,
            WM_GETICON,
            icon_type,
            0,
            SMTO_NORMAL | SMTO_ABORTIFHUNG,
            ICON_FETCH_TIMEOUT_MS,
            &mut result,
        );
    }
    result as HICON
}

fn render_icon_composite(icon: HICON, width: i32, height: i32, background: u8) -> Option<Vec<u8>> {
    // SAFETY: the surface owns every GDI object it creates and restores the selected bitmap in
    // Drop. Dimensions come from positive system metrics.
    let surface = unsafe { DibSurface::new(width, height, background) }?;
    // SAFETY: the copied icon and surface remain live for this synchronous draw.
    if unsafe {
        DrawIconEx(
            surface.dc,
            0,
            0,
            icon,
            width,
            height,
            0,
            null_mut(),
            DI_NORMAL,
        )
    } == 0
    {
        return None;
    }
    // SAFETY: CreateDIBSection supplied `byte_len` writable bytes owned by `surface`.
    Some(unsafe { std::slice::from_raw_parts(surface.bits, surface.byte_len) }.to_vec())
}

fn recover_rgba_from_composites(black: &[u8], white: &[u8]) -> Option<Vec<u8>> {
    if black.len() != white.len() || !black.len().is_multiple_of(4) {
        return None;
    }
    let mut rgba = Vec::with_capacity(black.len());
    for (black_pixel, white_pixel) in black.chunks_exact(4).zip(white.chunks_exact(4)) {
        let background_delta = (u32::from(white_pixel[0].saturating_sub(black_pixel[0]))
            + u32::from(white_pixel[1].saturating_sub(black_pixel[1]))
            + u32::from(white_pixel[2].saturating_sub(black_pixel[2]))
            + 1)
            / 3;
        let alpha = 255u32.saturating_sub(background_delta).min(255);
        let recover = |channel: u8| -> u8 {
            (u32::from(channel) * 255 + alpha / 2)
                .checked_div(alpha)
                .unwrap_or(0)
                .min(255) as u8
        };
        rgba.extend_from_slice(&[
            recover(black_pixel[2]),
            recover(black_pixel[1]),
            recover(black_pixel[0]),
            alpha as u8,
        ]);
    }
    Some(rgba)
}

fn encode_rgba_png(width: u32, height: u32, rgba: &[u8]) -> Option<Vec<u8>> {
    let expected = usize::try_from(width)
        .ok()?
        .checked_mul(usize::try_from(height).ok()?)?
        .checked_mul(4)?;
    if rgba.len() != expected {
        return None;
    }
    let mut output = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut output, width, height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header().ok()?;
        writer.write_image_data(rgba).ok()?;
    }
    Some(output)
}

struct OwnedIcon(HICON);

impl OwnedIcon {
    /// # Safety
    ///
    /// `raw` must be a newly owned icon that is released with `DestroyIcon`.
    unsafe fn from_raw(raw: HICON) -> Option<Self> {
        (!raw.is_null()).then_some(Self(raw))
    }

    const fn as_raw(&self) -> HICON {
        self.0
    }
}

impl Drop for OwnedIcon {
    fn drop(&mut self) {
        // SAFETY: this wrapper uniquely owns the successful CopyIcon result.
        unsafe {
            let _ = DestroyIcon(self.0);
        }
    }
}

struct DibSurface {
    dc: HDC,
    bitmap: HBITMAP,
    previous: HGDIOBJ,
    bits: *mut u8,
    byte_len: usize,
}

impl DibSurface {
    /// # Safety
    ///
    /// `width` and `height` must be positive dimensions small enough for a GDI DIB allocation.
    unsafe fn new(width: i32, height: i32, background: u8) -> Option<Self> {
        let pixel_count = usize::try_from(width)
            .ok()?
            .checked_mul(usize::try_from(height).ok()?)?;
        let byte_len = pixel_count.checked_mul(4)?;
        let size_image = u32::try_from(byte_len).ok()?;
        let info = BITMAPINFO {
            bmiHeader: BITMAPINFOHEADER {
                biSize: size_of::<BITMAPINFOHEADER>() as u32,
                biWidth: width,
                biHeight: -height,
                biPlanes: 1,
                biBitCount: 32,
                biCompression: BI_RGB,
                biSizeImage: size_image,
                ..BITMAPINFOHEADER::default()
            },
            ..BITMAPINFO::default()
        };
        // SAFETY: a null source DC creates a compatible memory DC owned by this function.
        let dc = unsafe { CreateCompatibleDC(null_mut()) };
        if dc.is_null() {
            return None;
        }
        let mut bits = null_mut();
        // SAFETY: `info` and the bits output pointer remain valid for the complete call.
        let bitmap =
            unsafe { CreateDIBSection(dc, &info, DIB_RGB_COLORS, &mut bits, null_mut(), 0) };
        if bitmap.is_null() || bits.is_null() {
            // SAFETY: `dc` is the fresh unshared memory DC created above.
            unsafe {
                let _ = DeleteDC(dc);
            }
            return None;
        }
        // SAFETY: both handles are valid and owned locally.
        let previous = unsafe { SelectObject(dc, bitmap as HGDIOBJ) };
        if previous.is_null() {
            // SAFETY: the failed selection leaves the bitmap unselected and both objects owned.
            unsafe {
                let _ = DeleteObject(bitmap as HGDIOBJ);
                let _ = DeleteDC(dc);
            }
            return None;
        }
        // SAFETY: the DIB exposes exactly `byte_len` bytes and is selected into our private DC.
        unsafe {
            std::slice::from_raw_parts_mut(bits.cast::<u8>(), byte_len).fill(background);
        }
        Some(Self {
            dc,
            bitmap,
            previous,
            bits: bits.cast(),
            byte_len,
        })
    }
}

impl Drop for DibSurface {
    fn drop(&mut self) {
        // SAFETY: the previous object belongs to this DC; restoring it makes the owned bitmap safe
        // to delete before deleting the private memory DC.
        unsafe {
            let _ = SelectObject(self.dc, self.previous);
            let _ = DeleteObject(self.bitmap as HGDIOBJ);
            let _ = DeleteDC(self.dc);
        }
    }
}

fn query_process_identity(pid: u32) -> Result<ProcessIdentity, BackendError> {
    // SAFETY: OpenProcess receives scalar arguments and returns a fresh owned handle on success.
    let raw = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) };
    // SAFETY: ownership of the successful handle is transferred immediately.
    let handle = unsafe { OwnedHandle::from_raw(raw) }
        .ok_or_else(|| last_error("OpenProcess for application identity"))?;
    query_identity_from_handle(pid, handle.as_raw())
}

fn query_process_needs_32_bit_suffix(identity: &ProcessIdentity) -> Result<bool, BackendError> {
    // SAFETY: OpenProcess receives scalar arguments and returns a fresh owned handle on success.
    let raw = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, identity.pid) };
    // SAFETY: ownership of the successful handle is transferred immediately.
    let handle = unsafe { OwnedHandle::from_raw(raw) }
        .ok_or_else(|| last_error("OpenProcess for application bitness"))?;
    let actual = query_identity_from_handle(identity.pid, handle.as_raw())?;
    if actual != *identity {
        return Err(BackendError::internal(
            "validate process identity for application bitness",
            "the application process identity changed before its architecture was queried",
        ));
    }
    process_needs_32_bit_suffix_handle(handle.as_raw())
}

pub(crate) fn process_needs_32_bit_suffix_handle(handle: HANDLE) -> Result<bool, BackendError> {
    let mut process_machine = IMAGE_FILE_MACHINE_UNKNOWN;
    let mut native_machine = IMAGE_FILE_MACHINE_UNKNOWN;
    // SAFETY: the caller owns a live query handle and both machine values are writable outputs.
    if unsafe { IsWow64Process2(handle, &mut process_machine, &mut native_machine) } == 0 {
        return Err(last_error("IsWow64Process2 for application bitness"));
    }
    process_machine_needs_32_bit_suffix(process_machine, native_machine).ok_or_else(|| {
        error_from_code(
            "interpret IsWow64Process2 application machine types",
            ERROR_INVALID_DATA,
        )
    })
}

fn process_machine_needs_32_bit_suffix(process_machine: u16, native_machine: u16) -> Option<bool> {
    let effective_machine = if process_machine == IMAGE_FILE_MACHINE_UNKNOWN {
        native_machine
    } else {
        process_machine
    };
    let process_is_32_bit = match effective_machine {
        IMAGE_FILE_MACHINE_I386
        | IMAGE_FILE_MACHINE_ARM
        | IMAGE_FILE_MACHINE_ARMNT
        | IMAGE_FILE_MACHINE_THUMB => true,
        IMAGE_FILE_MACHINE_AMD64 | IMAGE_FILE_MACHINE_ARM64 | IMAGE_FILE_MACHINE_IA64 => false,
        _ => return None,
    };
    let native_is_64_bit = match native_machine {
        IMAGE_FILE_MACHINE_AMD64 | IMAGE_FILE_MACHINE_ARM64 | IMAGE_FILE_MACHINE_IA64 => true,
        IMAGE_FILE_MACHINE_I386
        | IMAGE_FILE_MACHINE_ARM
        | IMAGE_FILE_MACHINE_ARMNT
        | IMAGE_FILE_MACHINE_THUMB => false,
        _ => return None,
    };
    Some(process_is_32_bit && native_is_64_bit)
}

pub(crate) fn query_identity_from_handle(
    pid: u32,
    handle: windows_sys::Win32::Foundation::HANDLE,
) -> Result<ProcessIdentity, BackendError> {
    let mut creation = FILETIME::default();
    let mut exit = FILETIME::default();
    let mut kernel = FILETIME::default();
    let mut user = FILETIME::default();
    // SAFETY: the handle remains valid for this synchronous query and all outputs are writable.
    if unsafe { GetProcessTimes(handle, &mut creation, &mut exit, &mut kernel, &mut user) } == 0 {
        return Err(last_error("GetProcessTimes for process identity"));
    }
    Ok(ProcessIdentity {
        pid,
        start_time: filetime_to_u64(creation),
    })
}

fn execute_window_action(
    identity: &ApplicationIdentity,
    operation: WindowAction,
) -> Result<(), BackendError> {
    let hwnd = validate_window_identity(identity)?;
    match operation {
        WindowAction::SwitchTo | WindowAction::BringToFront => {
            // SAFETY: HWND and its process identity were revalidated immediately above.
            unsafe {
                let _ = ShowWindow(hwnd, SW_RESTORE);
                if SetForegroundWindow(hwnd) == 0 {
                    return Err(last_error("SetForegroundWindow"));
                }
            }
        }
        WindowAction::Minimize => unsafe {
            let _ = ShowWindow(hwnd, SW_MINIMIZE);
        },
        WindowAction::Maximize => unsafe {
            let _ = ShowWindow(hwnd, SW_MAXIMIZE);
        },
        WindowAction::Close => {
            // SAFETY: posting WM_CLOSE does not transfer pointer ownership.
            if unsafe { PostMessageW(hwnd, WM_CLOSE, 0, 0) } == 0 {
                return Err(last_error("PostMessageW WM_CLOSE"));
            }
        }
    }
    Ok(())
}

fn validate_window_identity(identity: &ApplicationIdentity) -> Result<HWND, BackendError> {
    let hwnd = identity.native_id as usize as HWND;
    if hwnd.is_null() || unsafe { IsWindow(hwnd) } == 0 {
        return Err(BackendError::internal(
            "validate Windows window action",
            "the selected window no longer exists",
        ));
    }
    let mut current_pid = 0u32;
    if unsafe { GetWindowThreadProcessId(hwnd, &mut current_pid) } == 0 {
        return Err(last_error("GetWindowThreadProcessId before window action"));
    }
    let Some(expected_process) = &identity.process else {
        return Err(BackendError::internal(
            "validate Windows window action",
            "the selected window has no verified process identity",
        ));
    };
    if current_pid != expected_process.pid
        || query_process_identity(current_pid).as_ref() != Ok(expected_process)
    {
        return Err(BackendError::internal(
            "validate Windows window action",
            "the selected window process identity changed",
        ));
    }
    Ok(hwnd)
}

fn execute_window_arrangement(
    identities: &[ApplicationIdentity],
    arrangement: WindowArrangement,
) -> Result<(), BackendError> {
    let mut windows = Vec::with_capacity(identities.len());
    for identity in identities {
        let window = validate_window_identity(identity)?;
        if !windows.contains(&window) {
            windows.push(window);
        }
    }
    if windows.is_empty() {
        return Err(BackendError::internal(
            "arrange Windows windows",
            "at least one verified window is required",
        ));
    }
    let count = u32::try_from(windows.len()).map_err(|_| {
        BackendError::internal(
            "arrange Windows windows",
            "the selected window count is out of range",
        )
    })?;
    for window in &windows {
        // SAFETY: every HWND was revalidated above and is used synchronously.
        if unsafe { IsIconic(*window) } != 0 {
            unsafe {
                let _ = ShowWindow(*window, SW_RESTORE);
            }
        }
    }
    // SAFETY: `windows` remains live for the complete synchronous User32 call. The desktop HWND
    // is borrowed, and no RECT override is provided.
    let arranged = unsafe {
        match arrangement {
            WindowArrangement::TileHorizontally => TileWindows(
                GetDesktopWindow(),
                MDITILE_HORIZONTAL,
                null(),
                count,
                windows.as_ptr(),
            ),
            WindowArrangement::TileVertically => TileWindows(
                GetDesktopWindow(),
                MDITILE_VERTICAL,
                null(),
                count,
                windows.as_ptr(),
            ),
            WindowArrangement::Cascade => {
                CascadeWindows(GetDesktopWindow(), 0, null(), count, windows.as_ptr())
            }
        }
    };
    if arranged == 0 {
        return Err(BackendError::internal(
            "arrange Windows windows",
            "User32 did not arrange any verified windows",
        ));
    }
    Ok(())
}

fn current_desktop_names() -> Result<(String, String), BackendError> {
    // SAFETY: both functions return borrowed handles owned by the calling process/thread.
    let station = unsafe { GetProcessWindowStation() };
    // SAFETY: GetCurrentThreadId has no preconditions and the returned desktop is borrowed.
    let desktop = unsafe { GetThreadDesktop(GetCurrentThreadId()) };
    if station.is_null() || desktop.is_null() {
        return Err(last_error("query current Windows desktop handles"));
    }
    Ok((
        user_object_name(station as HANDLE)?,
        user_object_name(desktop as HANDLE)?,
    ))
}

fn user_object_name(handle: HANDLE) -> Result<String, BackendError> {
    let mut bytes = 0u32;
    // SAFETY: documented size probe with a null output buffer; borrowed handle stays valid.
    unsafe {
        let _ = GetUserObjectInformationW(handle, UOI_NAME, null_mut(), 0, &mut bytes);
    }
    if bytes == 0 || !bytes.is_multiple_of(size_of::<u16>() as u32) {
        return Err(last_error("GetUserObjectInformationW name size"));
    }
    let mut buffer = vec![0u16; bytes as usize / size_of::<u16>()];
    // SAFETY: buffer has exactly the byte capacity reported by the size probe.
    if unsafe {
        GetUserObjectInformationW(
            handle,
            UOI_NAME,
            buffer.as_mut_ptr().cast(),
            bytes,
            &mut bytes,
        )
    } == 0
    {
        return Err(last_error("GetUserObjectInformationW name"));
    }
    let length = buffer
        .iter()
        .position(|unit| *unit == 0)
        .unwrap_or(buffer.len());
    Ok(String::from_utf16_lossy(&buffer[..length]))
}

#[cfg(test)]
mod tests {
    use super::{
        encode_rgba_png, process_machine_needs_32_bit_suffix, recover_rgba_from_composites,
    };
    use windows_sys::Win32::System::SystemInformation::{
        IMAGE_FILE_MACHINE_AMD64, IMAGE_FILE_MACHINE_ARM64, IMAGE_FILE_MACHINE_ARMNT,
        IMAGE_FILE_MACHINE_I386, IMAGE_FILE_MACHINE_UNKNOWN,
    };

    #[test]
    fn suffix_is_only_needed_for_a_32_bit_process_on_a_64_bit_machine() {
        assert_eq!(
            process_machine_needs_32_bit_suffix(IMAGE_FILE_MACHINE_I386, IMAGE_FILE_MACHINE_AMD64),
            Some(true)
        );
        assert_eq!(
            process_machine_needs_32_bit_suffix(IMAGE_FILE_MACHINE_ARMNT, IMAGE_FILE_MACHINE_ARM64),
            Some(true)
        );
        assert_eq!(
            process_machine_needs_32_bit_suffix(
                IMAGE_FILE_MACHINE_UNKNOWN,
                IMAGE_FILE_MACHINE_AMD64
            ),
            Some(false)
        );
        assert_eq!(
            process_machine_needs_32_bit_suffix(
                IMAGE_FILE_MACHINE_UNKNOWN,
                IMAGE_FILE_MACHINE_I386
            ),
            Some(false)
        );
        assert_eq!(
            process_machine_needs_32_bit_suffix(0xffff, IMAGE_FILE_MACHINE_ARM64),
            None
        );
    }

    #[test]
    fn reconstructs_alpha_from_black_and_white_icon_draws() {
        let black = [
            0, 0, 0, 255, // opaque black
            0, 0, 0, 255, // transparent
            0, 0, 128, 255, // half-transparent red
        ];
        let white = [
            0, 0, 0, 255, // opaque black
            255, 255, 255, 255, // transparent
            127, 127, 255, 255, // half-transparent red
        ];

        let rgba = recover_rgba_from_composites(&black, &white).unwrap();

        assert_eq!(
            rgba,
            [
                0, 0, 0, 255, // opaque black
                0, 0, 0, 0, // transparent
                255, 0, 0, 128, // half-transparent red
            ]
        );
        assert!(encode_rgba_png(3, 1, &rgba).is_some());
    }

    #[test]
    fn rejects_mismatched_composite_and_png_lengths() {
        assert!(recover_rgba_from_composites(&[0; 4], &[0; 8]).is_none());
        assert!(encode_rgba_png(2, 1, &[0; 4]).is_none());
    }
}
