// +-------------------------------------------------------------------------
//
//   taskmgr-rs - KDE Plasma Wayland 窗口兼容后端
//
//   文件:       crates/taskmgr-linux/src/wayland_kde.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；KWin 6.7.4；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   KDE plasma-window-management v18；X-KDE-Wayland-Interfaces
// --------------------------------------------------------------------------

//! 在标准 foreign-toplevel 和 wlroots 协议均不存在时适配 KDE Plasma。
//!
//! KWin 将此 shell 级接口限制给在已安装 desktop entry 中明确声明权限的应用；正式包
//! 必须安装项目提供的 desktop entry。协议自身声明可发生不兼容变更，因此它始终只是
//! 标准协议之后的兼容后端，并由独立集成测试覆盖。

use std::collections::BTreeMap;

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, ApplicationIdentity, ApplicationRow,
    ApplicationStatus, ApplicationsData, BackendError, ProcessIdentity, SnapshotData, WindowAction,
};
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::wl_registry;
use wayland_client::{Connection, Dispatch, EventQueue, QueueHandle};
use wayland_protocols_plasma::plasma_window_management::client::{
    org_kde_plasma_window::{self, OrgKdePlasmaWindow},
    org_kde_plasma_window_management::{
        self, OrgKdePlasmaWindowManagement, State as PlasmaWindowState,
    },
};

use crate::wayland::wayland_error;

pub(crate) struct KdeSession {
    connection: Connection,
    event_queue: EventQueue<KdeState>,
    _manager: OrgKdePlasmaWindowManagement,
    state: KdeState,
}

#[derive(Default)]
struct KdeState {
    windows: BTreeMap<u64, KdeWindow>,
}

struct KdeWindow {
    proxy: OrgKdePlasmaWindow,
    title: Option<String>,
    app_id: Option<String>,
    pid: Option<u32>,
    flags: u32,
    desktops: Vec<String>,
    ready: bool,
    closed: bool,
}

impl KdeSession {
    pub(crate) fn connect() -> Result<Self, BackendError> {
        let connection = Connection::connect_to_env()
            .map_err(|error| wayland_error("connect KDE Plasma window management", error))?;
        let (globals, mut event_queue) = registry_queue_init::<KdeState>(&connection)
            .map_err(|error| wayland_error("read KDE Plasma Wayland globals", error))?;
        let qh = event_queue.handle();
        let manager = globals
            .bind::<OrgKdePlasmaWindowManagement, _, _>(&qh, 13..=18, ())
            .map_err(|error| wayland_error("bind KDE Plasma window management", error))?;
        let mut state = KdeState::default();
        event_queue
            .roundtrip(&mut state)
            .map_err(|error| wayland_error("enumerate KDE Plasma windows", error))?;
        Ok(Self {
            connection,
            event_queue,
            _manager: manager,
            state,
        })
    }

    pub(crate) fn actions(&self) -> Vec<ActionKind> {
        vec![
            ActionKind::SwitchTo,
            ActionKind::BringToFront,
            ActionKind::Minimize,
            ActionKind::Maximize,
            ActionKind::EndTask,
        ]
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        self.event_queue
            .roundtrip(&mut self.state)
            .map_err(|error| wayland_error("refresh KDE Plasma windows", error))?;
        let current_pid = std::process::id();
        let mut rows = self
            .state
            .windows
            .iter()
            .filter(|(_, window)| {
                window.ready
                    && !window.closed
                    && window.pid != Some(current_pid)
                    && !has_flag(window.flags, PlasmaWindowState::Skiptaskbar)
            })
            .map(|(native_id, window)| {
                let process = window.pid.and_then(process_identity);
                let row_error = window.pid.filter(|_| process.is_none()).map(|pid| {
                    BackendError::internal(
                        "KDE Plasma window identity",
                        format!("could not validate process start time for PID {pid}"),
                    )
                });
                ApplicationRow {
                    identity: ApplicationIdentity {
                        native_id: *native_id,
                        process,
                    },
                    title: window
                        .title
                        .clone()
                        .or_else(|| window.app_id.clone())
                        .filter(|value| !value.is_empty())
                        .unwrap_or_else(|| "Untitled KDE Wayland window".to_string()),
                    status: ApplicationStatus::Running,
                    window_station: None,
                    desktop: (!window.desktops.is_empty()).then(|| window.desktops.join(", ")),
                    icon_png: None,
                    large_icon_png: None,
                    allowed_actions: actions_for_flags(window.flags),
                    row_error,
                }
            })
            .collect::<Vec<_>>();
        rows.sort_by_key(|row| row.title.to_lowercase());
        Ok(SnapshotData::Applications(ApplicationsData { rows }))
    }

    pub(crate) fn execute(&mut self, request: ActionRequest) -> ActionResult {
        let ActionRequest::Window {
            identity,
            operation,
        } = request
        else {
            return ActionResult::unsupported("the requested operation is not a window action");
        };
        let Some(window) = self
            .state
            .windows
            .get(&identity.native_id)
            .filter(|window| !window.closed)
        else {
            return ActionResult::failed(BackendError::internal(
                "KDE Plasma window action",
                "the selected window no longer exists",
            ));
        };
        if let Some(expected) = &identity.process
            && window.pid.and_then(process_identity).as_ref() != Some(expected)
        {
            return ActionResult::failed(BackendError::internal(
                "KDE Plasma window action",
                "the selected window process identity changed",
            ));
        }

        let supported = actions_for_flags(window.flags);
        let action = action_kind(operation);
        if !supported.contains(&action) {
            return ActionResult::unsupported("the compositor disabled this window action");
        }
        match operation {
            WindowAction::SwitchTo | WindowAction::BringToFront => {
                set_flag(&window.proxy, PlasmaWindowState::Active, true)
            }
            WindowAction::Minimize => set_flag(&window.proxy, PlasmaWindowState::Minimized, true),
            WindowAction::Maximize => set_flag(&window.proxy, PlasmaWindowState::Maximized, true),
            WindowAction::Close => window.proxy.close(),
        }
        match self.connection.flush() {
            Ok(()) => ActionResult::succeeded(),
            Err(error) => ActionResult::failed(wayland_error("flush KDE window action", error)),
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for KdeState {
    fn event(
        _: &mut Self,
        _: &wl_registry::WlRegistry,
        _: wl_registry::Event,
        _: &GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<OrgKdePlasmaWindowManagement, ()> for KdeState {
    fn event(
        state: &mut Self,
        manager: &OrgKdePlasmaWindowManagement,
        event: org_kde_plasma_window_management::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let org_kde_plasma_window_management::Event::WindowWithUuid { uuid, .. } = event {
            let native_id = stable_identifier(&uuid);
            let proxy = manager.get_window_by_uuid(uuid.clone(), qh, native_id);
            state.windows.insert(
                native_id,
                KdeWindow {
                    proxy,
                    title: None,
                    app_id: None,
                    pid: None,
                    flags: 0,
                    desktops: Vec::new(),
                    ready: false,
                    closed: false,
                },
            );
        }
    }
}

impl Dispatch<OrgKdePlasmaWindow, u64> for KdeState {
    fn event(
        state: &mut Self,
        _: &OrgKdePlasmaWindow,
        event: org_kde_plasma_window::Event,
        native_id: &u64,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(window) = state.windows.get_mut(native_id) else {
            return;
        };
        match event {
            org_kde_plasma_window::Event::TitleChanged { title } => {
                window.title = Some(title);
            }
            org_kde_plasma_window::Event::AppIdChanged { app_id } => {
                window.app_id = Some(app_id);
            }
            org_kde_plasma_window::Event::StateChanged { flags } => window.flags = flags,
            org_kde_plasma_window::Event::PidChanged { pid } => window.pid = Some(pid),
            org_kde_plasma_window::Event::VirtualDesktopEntered { id } => {
                if !window.desktops.contains(&id) {
                    window.desktops.push(id);
                }
            }
            org_kde_plasma_window::Event::VirtualDesktopLeft { is: id } => {
                window.desktops.retain(|desktop| desktop != &id);
            }
            org_kde_plasma_window::Event::InitialState => window.ready = true,
            org_kde_plasma_window::Event::Unmapped => window.closed = true,
            _ => {}
        }
    }
}

fn actions_for_flags(flags: u32) -> Vec<ActionKind> {
    let mut actions = vec![ActionKind::SwitchTo, ActionKind::BringToFront];
    if has_flag(flags, PlasmaWindowState::Minimizable) {
        actions.push(ActionKind::Minimize);
    }
    if has_flag(flags, PlasmaWindowState::Maximizable) {
        actions.push(ActionKind::Maximize);
    }
    if has_flag(flags, PlasmaWindowState::Closeable) {
        actions.push(ActionKind::EndTask);
    }
    actions
}

const fn action_kind(operation: WindowAction) -> ActionKind {
    match operation {
        WindowAction::SwitchTo => ActionKind::SwitchTo,
        WindowAction::BringToFront => ActionKind::BringToFront,
        WindowAction::Minimize => ActionKind::Minimize,
        WindowAction::Maximize => ActionKind::Maximize,
        WindowAction::Close => ActionKind::EndTask,
    }
}

fn has_flag(flags: u32, flag: PlasmaWindowState) -> bool {
    flags & u32::from(flag) != 0
}

fn set_flag(window: &OrgKdePlasmaWindow, flag: PlasmaWindowState, enabled: bool) {
    let bit = u32::from(flag);
    window.set_state(bit, if enabled { bit } else { 0 });
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

fn stable_identifier(value: &str) -> u64 {
    let mut hash = 0xcbf2_9ce4_8422_2325_u64;
    for byte in value.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::{actions_for_flags, stable_identifier};
    use taskmgr_core::ActionKind;
    use wayland_protocols_plasma::plasma_window_management::client::org_kde_plasma_window_management::State;

    #[test]
    fn derives_actions_from_compositor_window_flags() {
        let flags = u32::from(State::Minimizable) | u32::from(State::Closeable);
        assert_eq!(
            actions_for_flags(flags),
            vec![
                ActionKind::SwitchTo,
                ActionKind::BringToFront,
                ActionKind::Minimize,
                ActionKind::EndTask,
            ]
        );
    }

    #[test]
    fn uuid_identifier_is_stable() {
        assert_eq!(stable_identifier("uuid-1"), stable_identifier("uuid-1"));
        assert_ne!(stable_identifier("uuid-1"), stable_identifier("uuid-2"));
    }
}
