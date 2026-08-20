// +-------------------------------------------------------------------------
//
//   taskmgr-rs - X11 EWMH 应用程序枚举与控制
//
//   文件:       crates/taskmgr-linux/src/x11.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   freedesktop.org Extended Window Manager Hints (EWMH) 1.5
// --------------------------------------------------------------------------

//! 使用 `_NET_CLIENT_LIST`、`_NET_WM_NAME`、`_NET_WM_PID`、`_NET_WM_ICON`
//! 和标准 client message。

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, ApplicationIdentity, ApplicationRow,
    ApplicationStatus, ApplicationsData, Availability, BackendError, ProcessIdentity, SnapshotData,
    WindowAction,
};
use x11rb::connection::Connection;
use x11rb::protocol::xproto::{
    Atom, AtomEnum, ClientMessageData, ClientMessageEvent, ConnectionExt, EventMask, Window,
};

struct Atoms {
    client_list: Atom,
    wm_name: Atom,
    utf8_string: Atom,
    wm_pid: Atom,
    wm_icon: Atom,
    active_window: Atom,
    close_window: Atom,
    wm_state: Atom,
    wm_state_hidden: Atom,
    wm_state_max_horz: Atom,
    wm_state_max_vert: Atom,
}

pub struct X11Applications {
    display_available: bool,
}

impl X11Applications {
    pub fn new() -> Self {
        Self {
            display_available: std::env::var_os("DISPLAY").is_some(),
        }
    }

    pub const fn is_available(&self) -> bool {
        self.display_available
    }

    pub fn capability(&self) -> (Availability, Vec<ActionKind>, Option<String>) {
        if self.display_available {
            (
                Availability::Supported,
                vec![
                    ActionKind::SwitchTo,
                    ActionKind::BringToFront,
                    ActionKind::Minimize,
                    ActionKind::Maximize,
                    ActionKind::EndTask,
                ],
                Some("X11 EWMH".to_string()),
            )
        } else {
            (
                Availability::Unsupported,
                Vec::new(),
                Some("no X11 display is available".to_string()),
            )
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        if !self.display_available {
            return Err(BackendError::unsupported(
                "applications",
                "no X11 display is available",
            ));
        }
        let (connection, screen_index) =
            x11rb::connect(None).map_err(|error| x11_error("connect to X11", error))?;
        let screen = &connection.setup().roots[screen_index];
        let atoms = Atoms::intern(&connection)?;
        let windows = connection
            .get_property(
                false,
                screen.root,
                atoms.client_list,
                AtomEnum::WINDOW,
                0,
                u32::MAX,
            )
            .map_err(|error| x11_error("request _NET_CLIENT_LIST", error))?
            .reply()
            .map_err(|error| x11_error("read _NET_CLIENT_LIST", error))?
            .value32()
            .map(Iterator::collect::<Vec<_>>)
            .unwrap_or_default();
        let mut rows = Vec::new();
        for window in windows {
            let title = window_title(&connection, &atoms, window)
                .unwrap_or_else(|| format!("0x{window:08X}"));
            let pid = window_pid(&connection, &atoms, window);
            let process = pid.and_then(process_identity);
            let (icon_png, large_icon_png) = window_icons_png(&connection, &atoms, window);
            rows.push(ApplicationRow {
                identity: ApplicationIdentity {
                    native_id: u64::from(window),
                    process,
                },
                title,
                status: ApplicationStatus::Running,
                window_station: None,
                desktop: None,
                icon_png,
                large_icon_png,
                allowed_actions: vec![
                    ActionKind::SwitchTo,
                    ActionKind::BringToFront,
                    ActionKind::Minimize,
                    ActionKind::Maximize,
                    ActionKind::EndTask,
                ],
                row_error: None,
            });
        }
        rows.sort_by_key(|row| row.title.to_lowercase());
        Ok(SnapshotData::Applications(ApplicationsData { rows }))
    }

    pub fn execute(&mut self, request: ActionRequest) -> ActionResult {
        let ActionRequest::Window {
            identity,
            operation,
        } = request
        else {
            return ActionResult::unsupported("the requested operation is not a window action");
        };
        let Ok(window) = u32::try_from(identity.native_id) else {
            return ActionResult::failed(BackendError::internal(
                "X11 window action",
                "window identifier is out of range",
            ));
        };
        if let Some(expected) = &identity.process
            && process_identity(expected.pid).as_ref() != Some(expected)
        {
            return ActionResult::failed(BackendError::internal(
                "X11 window action",
                "the window process identity changed",
            ));
        }
        match execute_window_action(window, operation) {
            Ok(()) => ActionResult::succeeded(),
            Err(error) => ActionResult::failed(error),
        }
    }
}

impl Default for X11Applications {
    fn default() -> Self {
        Self::new()
    }
}

impl Atoms {
    fn intern<C: Connection>(connection: &C) -> Result<Self, BackendError> {
        let atom = |name: &'static [u8]| -> Result<Atom, BackendError> {
            connection
                .intern_atom(false, name)
                .map_err(|error| x11_error("intern X11 atom", error))?
                .reply()
                .map(|reply| reply.atom)
                .map_err(|error| x11_error("read X11 atom", error))
        };
        Ok(Self {
            client_list: atom(b"_NET_CLIENT_LIST")?,
            wm_name: atom(b"_NET_WM_NAME")?,
            utf8_string: atom(b"UTF8_STRING")?,
            wm_pid: atom(b"_NET_WM_PID")?,
            wm_icon: atom(b"_NET_WM_ICON")?,
            active_window: atom(b"_NET_ACTIVE_WINDOW")?,
            close_window: atom(b"_NET_CLOSE_WINDOW")?,
            wm_state: atom(b"_NET_WM_STATE")?,
            wm_state_hidden: atom(b"_NET_WM_STATE_HIDDEN")?,
            wm_state_max_horz: atom(b"_NET_WM_STATE_MAXIMIZED_HORZ")?,
            wm_state_max_vert: atom(b"_NET_WM_STATE_MAXIMIZED_VERT")?,
        })
    }
}

fn window_title<C: Connection>(connection: &C, atoms: &Atoms, window: Window) -> Option<String> {
    let utf8 = connection
        .get_property(false, window, atoms.wm_name, atoms.utf8_string, 0, u32::MAX)
        .ok()?
        .reply()
        .ok()?;
    let title = String::from_utf8_lossy(&utf8.value)
        .trim_matches(char::from(0))
        .trim()
        .to_string();
    if !title.is_empty() {
        return Some(title);
    }
    let legacy = connection
        .get_property(
            false,
            window,
            AtomEnum::WM_NAME,
            AtomEnum::STRING,
            0,
            u32::MAX,
        )
        .ok()?
        .reply()
        .ok()?;
    let title = String::from_utf8_lossy(&legacy.value).trim().to_string();
    (!title.is_empty()).then_some(title)
}

fn window_pid<C: Connection>(connection: &C, atoms: &Atoms, window: Window) -> Option<u32> {
    connection
        .get_property(false, window, atoms.wm_pid, AtomEnum::CARDINAL, 0, 1)
        .ok()?
        .reply()
        .ok()?
        .value32()?
        .next()
}

const SMALL_ICON_EDGE: u32 = 16;
const LARGE_ICON_EDGE: u32 = 32;
const MAX_ICON_PROPERTY_CARDINALS: u32 = 1_048_576;
type IconScore = (u8, u32, u64);
type IconCandidate<'a> = (IconScore, u32, u32, &'a [u32]);

fn window_icons_png<C: Connection>(
    connection: &C,
    atoms: &Atoms,
    window: Window,
) -> (Option<Vec<u8>>, Option<Vec<u8>>) {
    let reply = connection
        .get_property(
            false,
            window,
            atoms.wm_icon,
            AtomEnum::CARDINAL,
            0,
            MAX_ICON_PROPERTY_CARDINALS,
        )
        .ok()
        .and_then(|cookie| cookie.reply().ok());
    let Some(reply) = reply else {
        return (None, None);
    };
    let Some(values) = reply.value32().map(Iterator::collect::<Vec<_>>) else {
        return (None, None);
    };
    (
        encode_selected_icon(&values, SMALL_ICON_EDGE),
        encode_selected_icon(&values, LARGE_ICON_EDGE),
    )
}

fn encode_selected_icon(values: &[u32], target_edge: u32) -> Option<Vec<u8>> {
    let (width, height, pixels) = select_argb_icon(values, target_edge)?;
    encode_rgba_png(width, height, &argb_to_rgba(pixels))
}

fn select_argb_icon(values: &[u32], target_edge: u32) -> Option<(u32, u32, &[u32])> {
    let mut offset = 0usize;
    let mut best: Option<IconCandidate<'_>> = None;
    while offset.checked_add(2)? <= values.len() {
        let width = values[offset];
        let height = values[offset + 1];
        offset += 2;
        let count = usize::try_from(width.checked_mul(height)?).ok()?;
        let end = offset.checked_add(count)?;
        if width == 0 || height == 0 || end > values.len() {
            break;
        }
        let edge = width.max(height);
        let score = (
            u8::from(width < target_edge || height < target_edge),
            edge.abs_diff(target_edge),
            u64::from(width) * u64::from(height),
        );
        if best.as_ref().is_none_or(|(current, ..)| score < *current) {
            best = Some((score, width, height, &values[offset..end]));
        }
        offset = end;
    }
    best.map(|(_, width, height, pixels)| (width, height, pixels))
}

fn argb_to_rgba(pixels: &[u32]) -> Vec<u8> {
    let mut rgba = Vec::with_capacity(pixels.len().saturating_mul(4));
    for pixel in pixels {
        rgba.extend_from_slice(&[
            (pixel >> 16) as u8,
            (pixel >> 8) as u8,
            *pixel as u8,
            (pixel >> 24) as u8,
        ]);
    }
    rgba
}

fn encode_rgba_png(width: u32, height: u32, rgba: &[u8]) -> Option<Vec<u8>> {
    let expected = usize::try_from(width)
        .ok()?
        .checked_mul(usize::try_from(height).ok()?)?
        .checked_mul(4)?;
    if expected != rgba.len() {
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

fn process_identity(pid: u32) -> Option<ProcessIdentity> {
    let stat = std::fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let close = stat.rfind(')')?;
    let start_time = stat[close + 1..].split_whitespace().nth(19)?.parse().ok()?;
    Some(ProcessIdentity { pid, start_time })
}

fn execute_window_action(window: Window, operation: WindowAction) -> Result<(), BackendError> {
    let (connection, screen_index) =
        x11rb::connect(None).map_err(|error| x11_error("connect to X11", error))?;
    let root = connection.setup().roots[screen_index].root;
    let atoms = Atoms::intern(&connection)?;
    match operation {
        WindowAction::SwitchTo | WindowAction::BringToFront => {
            send_client_message(
                &connection,
                root,
                window,
                atoms.active_window,
                [2, 0, 0, 0, 0],
            )?;
        }
        WindowAction::Close => {
            send_client_message(
                &connection,
                root,
                window,
                atoms.close_window,
                [0, 2, 0, 0, 0],
            )?;
        }
        WindowAction::Minimize => {
            send_client_message(
                &connection,
                root,
                window,
                atoms.wm_state,
                [1, atoms.wm_state_hidden, 0, 2, 0],
            )?;
        }
        WindowAction::Maximize => {
            send_client_message(
                &connection,
                root,
                window,
                atoms.wm_state,
                [1, atoms.wm_state_max_horz, atoms.wm_state_max_vert, 2, 0],
            )?;
        }
    }
    connection
        .flush()
        .map_err(|error| x11_error("flush X11 window action", error))
}

fn send_client_message<C: Connection>(
    connection: &C,
    root: Window,
    window: Window,
    message_type: Atom,
    data: [u32; 5],
) -> Result<(), BackendError> {
    let event = ClientMessageEvent::new(32, window, message_type, ClientMessageData::from(data));
    connection
        .send_event(
            false,
            root,
            EventMask::SUBSTRUCTURE_REDIRECT | EventMask::SUBSTRUCTURE_NOTIFY,
            event,
        )
        .map_err(|error| x11_error("send EWMH client message", error))?;
    Ok(())
}

fn x11_error(context: &str, error: impl std::fmt::Display) -> BackendError {
    BackendError {
        domain: "x11".to_string(),
        code: -1,
        context: context.to_string(),
        message: error.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{argb_to_rgba, encode_rgba_png, select_argb_icon};

    #[test]
    fn selects_the_closest_icon_without_upscaling_when_possible() {
        let mut values = vec![8, 8];
        values.extend(std::iter::repeat_n(0xFF11_2233, 8 * 8));
        values.extend([16, 16]);
        values.extend(std::iter::repeat_n(0x8044_5566, 16 * 16));
        values.extend([32, 32]);
        values.extend(std::iter::repeat_n(0xFF77_8899, 32 * 32));

        let (width, height, pixels) = select_argb_icon(&values, 16).unwrap();

        assert_eq!((width, height), (16, 16));
        assert_eq!(pixels[0], 0x8044_5566);
    }

    #[test]
    fn rejects_a_truncated_icon_without_reading_past_the_property() {
        assert!(select_argb_icon(&[16, 16, 0xFFFF_FFFF], 16).is_none());
    }

    #[test]
    fn converts_ewmh_argb_to_png_rgba_order() {
        let rgba = argb_to_rgba(&[0x8044_5566]);
        assert_eq!(rgba, [0x44, 0x55, 0x66, 0x80]);
        assert!(encode_rgba_png(1, 1, &rgba).is_some());
        assert!(encode_rgba_png(2, 1, &rgba).is_none());
    }
}
