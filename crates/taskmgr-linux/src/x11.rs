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

use std::collections::HashSet;

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, ApplicationIdentity, ApplicationRow,
    ApplicationStatus, ApplicationsData, Availability, BackendError, ProcessIdentity, SnapshotData,
    WindowAction,
};
use x11rb::connection::Connection;
use x11rb::protocol::xproto::{
    Atom, AtomEnum, ClientMessageData, ClientMessageEvent, ConnectionExt, EventMask,
    GetPropertyReply, Window,
};
use x11rb::rust_connection::RustConnection;

use crate::desktop_icons::DesktopIconResolver;

const MAX_APPLICATION_WINDOWS: usize = 4_096;
const MAX_TITLE_PROPERTY_BYTES: usize = 16 * 1_024;
const MAX_WM_CLASS_PROPERTY_BYTES: usize = 4 * 1_024;
const MAX_ICON_PROPERTY_BYTES: usize = 1_024 * 1_024;
const MAX_SNAPSHOT_METADATA_BYTES: usize = 64 * 1_024 * 1_024;

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

struct SnapshotBudget {
    remaining_bytes: usize,
}

impl SnapshotBudget {
    const fn new(limit: usize) -> Self {
        Self {
            remaining_bytes: limit,
        }
    }

    fn property_long_length(
        &self,
        per_property_limit: usize,
        context: &str,
    ) -> Result<u32, BackendError> {
        let long_length = per_property_limit.min(self.remaining_bytes) / 4;
        if long_length == 0 {
            return Err(resource_limit(
                context,
                "the X11 snapshot metadata budget is exhausted",
            ));
        }
        u32::try_from(long_length).map_err(|_| {
            resource_limit(
                context,
                "the X11 property limit exceeds the protocol length field",
            )
        })
    }

    fn charge(&mut self, bytes: usize, context: &str) -> Result<(), BackendError> {
        let Some(remaining) = self.remaining_bytes.checked_sub(bytes) else {
            return Err(resource_limit(
                context,
                format!("the X11 snapshot metadata budget was exceeded by {bytes} bytes"),
            ));
        };
        self.remaining_bytes = remaining;
        Ok(())
    }
}

impl Default for SnapshotBudget {
    fn default() -> Self {
        Self::new(MAX_SNAPSHOT_METADATA_BYTES)
    }
}

pub struct X11Applications {
    connection: Option<RustConnection>,
    screen_index: usize,
    icons: Option<DesktopIconResolver>,
    unavailable_detail: String,
}

impl X11Applications {
    pub fn new() -> Self {
        if std::env::var_os("DISPLAY").is_none() {
            return Self {
                connection: None,
                screen_index: 0,
                icons: None,
                unavailable_detail: "no X11 display is available".to_string(),
            };
        }
        match x11rb::connect(None) {
            Ok((connection, screen_index)) => Self {
                connection: Some(connection),
                screen_index,
                icons: Some(DesktopIconResolver::discover()),
                unavailable_detail: String::new(),
            },
            Err(error) => Self {
                connection: None,
                screen_index: 0,
                icons: None,
                unavailable_detail: format!("X11 connection setup failed: {error}"),
            },
        }
    }

    pub fn is_available(&self) -> bool {
        self.connection.is_some()
    }

    pub fn capability(&self) -> (Availability, Vec<ActionKind>, Option<String>) {
        if self.is_available() {
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
                Some(self.unavailable_detail.clone()),
            )
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let Some(connection) = self.connection.as_ref() else {
            return Err(BackendError::unsupported(
                "applications",
                self.unavailable_detail.clone(),
            ));
        };
        let screen = &connection.setup().roots[self.screen_index];
        let atoms = Atoms::intern(connection)?;
        let mut budget = SnapshotBudget::default();
        let windows = client_windows(connection, &mut budget, screen.root, &atoms)?;
        let mut icons = self.icons.as_mut();
        let mut rows = Vec::with_capacity(windows.len());
        for window in windows {
            let mut row_error = None;
            let title = match window_title(connection, &atoms, window, &mut budget) {
                Ok(Some(title)) => title,
                Ok(None) => format!("0x{window:08X}"),
                Err(error) => {
                    append_row_error(&mut row_error, error);
                    format!("0x{window:08X}")
                }
            };
            let pid = window_pid(connection, &atoms, window);
            let process = pid.and_then(process_identity);
            let (mut icon_png, mut large_icon_png) =
                match window_icons_png(connection, &atoms, window, &mut budget) {
                    Ok(icons) => icons,
                    Err(error) => {
                        append_row_error(&mut row_error, error);
                        (None, None)
                    }
                };
            if icon_png.is_none()
                && large_icon_png.is_none()
                && let Some(icons) = icons.as_deref_mut()
            {
                match window_class_keys(connection, window, &mut budget) {
                    Ok(keys) => {
                        for key in keys {
                            let resolved = icons.resolve(None, Some(&key));
                            if resolved.small.is_some() || resolved.large.is_some() {
                                icon_png = resolved.small;
                                large_icon_png = resolved.large;
                                break;
                            }
                        }
                    }
                    Err(error) => append_row_error(&mut row_error, error),
                }
            }
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
                row_error,
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
        let Some(connection) = self.connection.as_ref() else {
            return ActionResult::unsupported(self.unavailable_detail.clone());
        };
        match execute_window_action(connection, self.screen_index, window, operation) {
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

fn client_windows<C: Connection>(
    connection: &C,
    budget: &mut SnapshotBudget,
    root: Window,
    atoms: &Atoms,
) -> Result<Vec<Window>, BackendError> {
    let reply = bounded_property(
        connection,
        budget,
        root,
        atoms.client_list,
        AtomEnum::WINDOW,
        MAX_APPLICATION_WINDOWS * std::mem::size_of::<Window>(),
        "read _NET_CLIENT_LIST",
    )?;
    if reply.format == 0 && reply.value.is_empty() {
        return Ok(Vec::new());
    }
    let windows = reply
        .value32()
        .ok_or_else(|| {
            resource_limit(
                "decode _NET_CLIENT_LIST",
                "the property is not a 32-bit WINDOW list",
            )
        })?
        .collect::<Vec<_>>();
    validate_client_windows(windows)
}

fn validate_client_windows(windows: Vec<Window>) -> Result<Vec<Window>, BackendError> {
    if windows.len() > MAX_APPLICATION_WINDOWS {
        return Err(resource_limit(
            "decode _NET_CLIENT_LIST",
            format!(
                "the client list contains {} windows; the limit is {MAX_APPLICATION_WINDOWS}",
                windows.len()
            ),
        ));
    }
    let mut unique = HashSet::with_capacity(windows.len());
    if windows.iter().any(|window| !unique.insert(*window)) {
        return Err(resource_limit(
            "decode _NET_CLIENT_LIST",
            "the client list contains duplicate window identifiers",
        ));
    }
    Ok(windows)
}

fn bounded_property<C: Connection, A: Into<Atom>>(
    connection: &C,
    budget: &mut SnapshotBudget,
    window: Window,
    property: Atom,
    property_type: A,
    per_property_limit: usize,
    context: &str,
) -> Result<GetPropertyReply, BackendError> {
    let long_length = budget.property_long_length(per_property_limit, context)?;
    let reply = connection
        .get_property(false, window, property, property_type, 0, long_length)
        .map_err(|error| x11_error(format!("request {context}"), error))?
        .reply()
        .map_err(|error| x11_error(context, error))?;
    budget.charge(reply.value.len(), context)?;
    require_complete_property(reply, context)
}

fn require_complete_property(
    reply: GetPropertyReply,
    context: &str,
) -> Result<GetPropertyReply, BackendError> {
    if reply.bytes_after != 0 {
        return Err(resource_limit(
            context,
            format!(
                "the X11 property exceeds its resource limit by {} bytes",
                reply.bytes_after
            ),
        ));
    }
    Ok(reply)
}

fn window_title<C: Connection>(
    connection: &C,
    atoms: &Atoms,
    window: Window,
    budget: &mut SnapshotBudget,
) -> Result<Option<String>, BackendError> {
    let utf8 = bounded_property(
        connection,
        budget,
        window,
        atoms.wm_name,
        atoms.utf8_string,
        MAX_TITLE_PROPERTY_BYTES,
        "read _NET_WM_NAME",
    )?;
    validate_text_format(&utf8, "decode _NET_WM_NAME")?;
    let title = String::from_utf8_lossy(&utf8.value)
        .trim_matches(char::from(0))
        .trim()
        .to_string();
    if !title.is_empty() {
        budget.charge(title.len(), "retain _NET_WM_NAME")?;
        return Ok(Some(title));
    }
    let legacy = bounded_property(
        connection,
        budget,
        window,
        AtomEnum::WM_NAME.into(),
        AtomEnum::STRING,
        MAX_TITLE_PROPERTY_BYTES,
        "read WM_NAME",
    )?;
    validate_text_format(&legacy, "decode WM_NAME")?;
    let title = String::from_utf8_lossy(&legacy.value).trim().to_string();
    if title.is_empty() {
        Ok(None)
    } else {
        budget.charge(title.len(), "retain WM_NAME")?;
        Ok(Some(title))
    }
}

fn validate_text_format(reply: &GetPropertyReply, context: &str) -> Result<(), BackendError> {
    if (reply.format == 0 && reply.value.is_empty()) || reply.format == 8 {
        Ok(())
    } else {
        Err(resource_limit(
            context,
            "the X11 text property is not an 8-bit string",
        ))
    }
}

fn window_class_keys<C: Connection>(
    connection: &C,
    window: Window,
    budget: &mut SnapshotBudget,
) -> Result<Vec<String>, BackendError> {
    let reply = bounded_property(
        connection,
        budget,
        window,
        AtomEnum::WM_CLASS.into(),
        AtomEnum::STRING,
        MAX_WM_CLASS_PROPERTY_BYTES,
        "read WM_CLASS",
    )?;
    validate_text_format(&reply, "decode WM_CLASS")?;
    Ok(decode_wm_class_keys(&reply.value))
}

fn decode_wm_class_keys(value: &[u8]) -> Vec<String> {
    // ICCCM WM_CLASS contains exactly two NUL-terminated STRING values: instance first,
    // class second. Prefer the stable class, while retaining the instance as a fallback.
    let mut fields = value
        .split(|byte| *byte == 0)
        .take(2)
        .map(|field| String::from_utf8_lossy(field).trim().to_string());
    let instance = fields.next().filter(|field| !field.is_empty());
    let class = fields.next().filter(|field| !field.is_empty());
    let mut keys = Vec::with_capacity(2);
    if let Some(class) = class {
        keys.push(class);
    }
    if let Some(instance) = instance
        && !keys.iter().any(|key| key.eq_ignore_ascii_case(&instance))
    {
        keys.push(instance);
    }
    keys
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
type IconScore = (u8, u32, u64);
type IconCandidate<'a> = (IconScore, u32, u32, &'a [u32]);
type EncodedIcons = (Option<Vec<u8>>, Option<Vec<u8>>);

fn window_icons_png<C: Connection>(
    connection: &C,
    atoms: &Atoms,
    window: Window,
    budget: &mut SnapshotBudget,
) -> Result<EncodedIcons, BackendError> {
    let reply = bounded_property(
        connection,
        budget,
        window,
        atoms.wm_icon,
        AtomEnum::CARDINAL,
        MAX_ICON_PROPERTY_BYTES,
        "read _NET_WM_ICON",
    )?;
    if reply.format == 0 && reply.value.is_empty() {
        return Ok((None, None));
    }
    let values = reply
        .value32()
        .ok_or_else(|| {
            resource_limit(
                "decode _NET_WM_ICON",
                "the property is not a 32-bit CARDINAL list",
            )
        })?
        .collect::<Vec<_>>();
    budget.charge(
        values.len() * std::mem::size_of::<u32>(),
        "copy _NET_WM_ICON",
    )?;
    let icons = (
        encode_selected_icon(&values, SMALL_ICON_EDGE),
        encode_selected_icon(&values, LARGE_ICON_EDGE),
    );
    let encoded_bytes = icons.0.as_ref().map_or(0, Vec::len) + icons.1.as_ref().map_or(0, Vec::len);
    budget.charge(encoded_bytes, "retain encoded X11 icons")?;
    Ok(icons)
}

fn encode_selected_icon(values: &[u32], target_edge: u32) -> Option<Vec<u8>> {
    let (width, height, pixels) = select_argb_icon(values, target_edge)?;
    let rgba = resize_argb_to_rgba(width, height, pixels, target_edge)?;
    encode_rgba_png(target_edge, target_edge, &rgba)
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

fn resize_argb_to_rgba(
    width: u32,
    height: u32,
    pixels: &[u32],
    target_edge: u32,
) -> Option<Vec<u8>> {
    if width == 0 || height == 0 || target_edge == 0 {
        return None;
    }
    let source_width = usize::try_from(width).ok()?;
    let source_height = usize::try_from(height).ok()?;
    let edge = usize::try_from(target_edge).ok()?;
    let output_len = edge.checked_mul(edge)?.checked_mul(4)?;
    let (scaled_width, scaled_height) = if width >= height {
        let scaled_height =
            usize::try_from((u64::from(height) * u64::from(target_edge) / u64::from(width)).max(1))
                .ok()?;
        (edge, scaled_height)
    } else {
        let scaled_width =
            usize::try_from((u64::from(width) * u64::from(target_edge) / u64::from(height)).max(1))
                .ok()?;
        (scaled_width, edge)
    };
    let offset_x = (edge - scaled_width) / 2;
    let offset_y = (edge - scaled_height) / 2;
    let mut rgba = vec![0; output_len];
    for target_y in 0..scaled_height {
        let source_y = target_y * source_height / scaled_height;
        for target_x in 0..scaled_width {
            let source_x = target_x * source_width / scaled_width;
            let source_index = source_y.checked_mul(source_width)?.checked_add(source_x)?;
            let pixel = *pixels.get(source_index)?;
            let target_index = (target_y + offset_y)
                .checked_mul(edge)?
                .checked_add(target_x + offset_x)?
                .checked_mul(4)?;
            rgba.get_mut(target_index..target_index + 4)?
                .copy_from_slice(&[
                    (pixel >> 16) as u8,
                    (pixel >> 8) as u8,
                    pixel as u8,
                    (pixel >> 24) as u8,
                ]);
        }
    }
    Some(rgba)
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

fn execute_window_action(
    connection: &RustConnection,
    screen_index: usize,
    window: Window,
    operation: WindowAction,
) -> Result<(), BackendError> {
    let root = connection.setup().roots[screen_index].root;
    let atoms = Atoms::intern(connection)?;
    match operation {
        WindowAction::SwitchTo | WindowAction::BringToFront => {
            send_client_message(
                connection,
                root,
                window,
                atoms.active_window,
                [2, 0, 0, 0, 0],
            )?;
        }
        WindowAction::Close => {
            send_client_message(
                connection,
                root,
                window,
                atoms.close_window,
                [0, 2, 0, 0, 0],
            )?;
        }
        WindowAction::Minimize => {
            send_client_message(
                connection,
                root,
                window,
                atoms.wm_state,
                [1, atoms.wm_state_hidden, 0, 2, 0],
            )?;
        }
        WindowAction::Maximize => {
            send_client_message(
                connection,
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

fn x11_error(context: impl Into<String>, error: impl std::fmt::Display) -> BackendError {
    BackendError {
        domain: "x11".to_string(),
        code: -1,
        context: context.into(),
        message: error.to_string(),
    }
}

fn resource_limit(context: impl Into<String>, message: impl Into<String>) -> BackendError {
    BackendError {
        domain: "resource_limit".to_string(),
        code: 1,
        context: context.into(),
        message: message.into(),
    }
}

fn append_row_error(slot: &mut Option<BackendError>, error: BackendError) {
    if let Some(existing) = slot {
        existing.message = format!("{}; {}: {}", existing.message, error.context, error.message);
    } else {
        *slot = Some(error);
    }
}

#[cfg(test)]
mod tests {
    use super::{
        GetPropertyReply, MAX_APPLICATION_WINDOWS, SnapshotBudget, decode_wm_class_keys,
        encode_rgba_png, encode_selected_icon, require_complete_property, resize_argb_to_rgba,
        select_argb_icon, validate_client_windows,
    };

    #[test]
    fn decodes_icccm_window_class_with_stable_class_first() {
        assert_eq!(
            decode_wm_class_keys(b"chatgpt (/tmp/profile)\0Chatgpt\0ignored"),
            ["Chatgpt", "chatgpt (/tmp/profile)"]
        );
        assert_eq!(decode_wm_class_keys(b"same\0SAME\0"), ["SAME"]);
        assert!(decode_wm_class_keys(b"\0\0").is_empty());
    }

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
        let rgba = resize_argb_to_rgba(1, 1, &[0x8044_5566], 1).unwrap();
        assert_eq!(rgba, [0x44, 0x55, 0x66, 0x80]);
        assert!(encode_rgba_png(1, 1, &rgba).is_some());
        assert!(encode_rgba_png(2, 1, &rgba).is_none());
    }

    #[test]
    fn preserves_non_square_icon_aspect_ratio_with_transparent_padding() {
        let rgba = resize_argb_to_rgba(2, 1, &[0xFFFF_0000, 0xFF00_FF00], 4).unwrap();

        assert!(rgba[..4 * 4].iter().all(|component| *component == 0));
        assert_eq!(&rgba[4 * 4..4 * 5], &[0xFF, 0x00, 0x00, 0xFF]);
        assert_eq!(&rgba[4 * 7..4 * 8], &[0x00, 0xFF, 0x00, 0xFF]);
        assert!(rgba[4 * 12..].iter().all(|component| *component == 0));
    }

    #[test]
    fn encodes_only_the_requested_icon_dimensions() {
        let mut values = vec![256, 256];
        values.extend(std::iter::repeat_n(0xFF11_2233, 256 * 256));

        let png = encode_selected_icon(&values, 16).unwrap();

        assert_eq!(&png[16..20], &16_u32.to_be_bytes());
        assert_eq!(&png[20..24], &16_u32.to_be_bytes());
    }

    #[test]
    fn rejects_duplicate_and_oversized_client_lists() {
        assert!(validate_client_windows(vec![1, 2, 1]).is_err());
        assert!(validate_client_windows(vec![0; MAX_APPLICATION_WINDOWS + 1]).is_err());
        assert_eq!(validate_client_windows(vec![1, 2, 3]).unwrap(), [1, 2, 3]);
    }

    #[test]
    fn snapshot_budget_bounds_property_reads_and_owned_copies() {
        let mut budget = SnapshotBudget::new(12);
        assert_eq!(budget.property_long_length(64, "test").unwrap(), 3);
        assert!(budget.charge(8, "test").is_ok());
        assert_eq!(budget.property_long_length(64, "test").unwrap(), 1);
        assert!(budget.charge(5, "test").is_err());
    }

    #[test]
    fn rejects_property_replies_with_unread_attacker_data() {
        let complete = GetPropertyReply {
            format: 8,
            value_len: 4,
            value: b"safe".to_vec(),
            ..GetPropertyReply::default()
        };
        assert!(require_complete_property(complete, "test").is_ok());

        let oversized = GetPropertyReply {
            format: 8,
            bytes_after: 1,
            value_len: 4,
            value: b"part".to_vec(),
            ..GetPropertyReply::default()
        };
        let error = require_complete_property(oversized, "test").unwrap_err();
        assert_eq!(error.domain, "resource_limit");
    }
}
