// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Wayland foreign-toplevel 应用程序后端
//
//   文件:       crates/taskmgr-linux/src/wayland.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   ext-foreign-toplevel-list-v1；wlr-foreign-toplevel-management-unstable-v1 v3；KDE Plasma Wayland
// --------------------------------------------------------------------------

//! 优先使用标准 staging 协议枚举窗口；随后降级到 wlroots、KDE Plasma 协议。

use std::collections::BTreeMap;

use taskmgr_core::{
    ActionKind, ActionRequest, ActionResult, ApplicationIdentity, ApplicationRow,
    ApplicationStatus, ApplicationsData, Availability, BackendError, SnapshotData, WindowAction,
};
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::{wl_registry, wl_seat};
use wayland_client::{Connection, Dispatch, EventQueue, Proxy, QueueHandle};
use wayland_protocols::ext::foreign_toplevel_list::v1::client::{
    ext_foreign_toplevel_handle_v1::{self, ExtForeignToplevelHandleV1},
    ext_foreign_toplevel_list_v1::{self, ExtForeignToplevelListV1},
};
use wayland_protocols_wlr::foreign_toplevel::v1::client::{
    zwlr_foreign_toplevel_handle_v1::{self, ZwlrForeignToplevelHandleV1},
    zwlr_foreign_toplevel_manager_v1::{self, ZwlrForeignToplevelManagerV1},
};

use crate::wayland_kde::KdeSession;

const EXT_INTERFACE: &str = "ext_foreign_toplevel_list_v1";
const WLR_INTERFACE: &str = "zwlr_foreign_toplevel_manager_v1";
const KDE_INTERFACE: &str = "org_kde_plasma_window_management";

pub struct WaylandApplications {
    backend: WaylandBackend,
}

enum WaylandBackend {
    Ext(ExtSession),
    Wlr(WlrSession),
    Kde(KdeSession),
}

impl WaylandApplications {
    pub fn connect() -> Result<Option<Self>, BackendError> {
        let protocols = advertised_protocols()?;
        let candidates = protocol_candidates(&protocols);
        let mut failures = Vec::new();
        for candidate in candidates {
            let backend = match candidate {
                ForeignToplevelProtocol::Ext => ExtSession::connect().map(WaylandBackend::Ext),
                ForeignToplevelProtocol::Wlr => WlrSession::connect().map(WaylandBackend::Wlr),
                ForeignToplevelProtocol::Kde => KdeSession::connect().map(WaylandBackend::Kde),
            };
            match backend {
                Ok(backend) => return Ok(Some(Self { backend })),
                Err(error) => failures.push(format!("{}: {}", error.context, error.message)),
            }
        }
        if failures.is_empty() {
            Ok(None)
        } else {
            Err(BackendError {
                domain: "wayland".to_string(),
                code: -1,
                context: "connect foreign-toplevel protocol".to_string(),
                message: failures.join("; "),
            })
        }
    }

    pub fn capability(&self) -> (Availability, Vec<ActionKind>, Option<String>) {
        match &self.backend {
            WaylandBackend::Ext(_) => (
                Availability::Partial,
                Vec::new(),
                Some(
                    "Wayland ext-foreign-toplevel-list-v1 (enumeration; compositor exposes no control requests)"
                        .to_string(),
                ),
            ),
            WaylandBackend::Wlr(session) => (
                Availability::Supported,
                session.actions(),
                Some("Wayland wlroots foreign-toplevel-management v1".to_string()),
            ),
            WaylandBackend::Kde(session) => (
                Availability::Supported,
                session.actions(),
                Some(
                    "KDE Plasma window management compatibility protocol (declared in the installed desktop entry)"
                        .to_string(),
                ),
            ),
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        match &mut self.backend {
            WaylandBackend::Ext(session) => session.sample(),
            WaylandBackend::Wlr(session) => session.sample(),
            WaylandBackend::Kde(session) => session.sample(),
        }
    }

    pub fn execute(&mut self, request: ActionRequest) -> ActionResult {
        match &mut self.backend {
            WaylandBackend::Ext(_) => ActionResult::unsupported(
                "ext-foreign-toplevel-list-v1 intentionally provides enumeration only",
            ),
            WaylandBackend::Wlr(session) => session.execute(request),
            WaylandBackend::Kde(session) => session.execute(request),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ForeignToplevelProtocol {
    Ext,
    Wlr,
    Kde,
}

fn protocol_candidates(protocols: &[String]) -> Vec<ForeignToplevelProtocol> {
    let mut candidates = Vec::with_capacity(2);
    if protocols.iter().any(|name| name == EXT_INTERFACE) {
        candidates.push(ForeignToplevelProtocol::Ext);
    }
    if protocols.iter().any(|name| name == WLR_INTERFACE) {
        candidates.push(ForeignToplevelProtocol::Wlr);
    }
    if protocols.iter().any(|name| name == KDE_INTERFACE) {
        candidates.push(ForeignToplevelProtocol::Kde);
    }
    candidates
}

#[derive(Default)]
struct RegistryProbe;

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for RegistryProbe {
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

fn advertised_protocols() -> Result<Vec<String>, BackendError> {
    let connection = Connection::connect_to_env()
        .map_err(|error| wayland_error("connect to Wayland compositor", error))?;
    let (globals, _) = registry_queue_init::<RegistryProbe>(&connection)
        .map_err(|error| wayland_error("read Wayland globals", error))?;
    Ok(globals
        .contents()
        .clone_list()
        .into_iter()
        .map(|global| global.interface)
        .collect())
}

struct ExtSession {
    _connection: Connection,
    event_queue: EventQueue<ExtState>,
    _list: ExtForeignToplevelListV1,
    state: ExtState,
}

#[derive(Default)]
struct ExtState {
    windows: BTreeMap<u32, ExtWindow>,
}

struct ExtWindow {
    _proxy: ExtForeignToplevelHandleV1,
    identifier: Option<String>,
    title: Option<String>,
    app_id: Option<String>,
    ready: bool,
    closed: bool,
}

impl ExtSession {
    fn connect() -> Result<Self, BackendError> {
        let connection = Connection::connect_to_env()
            .map_err(|error| wayland_error("connect ext foreign-toplevel", error))?;
        let (globals, mut event_queue) = registry_queue_init::<ExtState>(&connection)
            .map_err(|error| wayland_error("read ext Wayland globals", error))?;
        let qh = event_queue.handle();
        let list = globals
            .bind::<ExtForeignToplevelListV1, _, _>(&qh, 1..=1, ())
            .map_err(|error| wayland_error("bind ext-foreign-toplevel-list-v1", error))?;
        let mut state = ExtState::default();
        event_queue
            .roundtrip(&mut state)
            .map_err(|error| wayland_error("enumerate ext foreign toplevels", error))?;
        Ok(Self {
            _connection: connection,
            event_queue,
            _list: list,
            state,
        })
    }

    fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        self.event_queue
            .roundtrip(&mut self.state)
            .map_err(|error| wayland_error("refresh ext foreign toplevels", error))?;
        let mut rows = self
            .state
            .windows
            .iter()
            .filter(|(_, window)| window.ready && !window.closed)
            .map(|(proxy_id, window)| {
                let title = window
                    .title
                    .clone()
                    .or_else(|| window.app_id.clone())
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| "Untitled Wayland window".to_string());
                ApplicationRow {
                    identity: ApplicationIdentity {
                        native_id: window
                            .identifier
                            .as_deref()
                            .map(stable_identifier)
                            .unwrap_or_else(|| u64::from(*proxy_id)),
                        process: None,
                    },
                    title,
                    status: ApplicationStatus::Running,
                    window_station: None,
                    desktop: None,
                    icon_png: None,
                    large_icon_png: None,
                    allowed_actions: Vec::new(),
                    row_error: window.identifier.is_none().then(|| {
                        BackendError::internal(
                            "ext foreign toplevel",
                            "compositor did not provide the required stable identifier",
                        )
                    }),
                }
            })
            .collect::<Vec<_>>();
        rows.sort_by_key(|row| row.title.to_lowercase());
        Ok(SnapshotData::Applications(ApplicationsData { rows }))
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for ExtState {
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

impl Dispatch<ExtForeignToplevelListV1, ()> for ExtState {
    fn event(
        state: &mut Self,
        _: &ExtForeignToplevelListV1,
        event: ext_foreign_toplevel_list_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let ext_foreign_toplevel_list_v1::Event::Toplevel { toplevel } = event {
            state.windows.insert(
                toplevel.id().protocol_id(),
                ExtWindow {
                    _proxy: toplevel,
                    identifier: None,
                    title: None,
                    app_id: None,
                    ready: false,
                    closed: false,
                },
            );
        }
    }

    wayland_client::event_created_child!(
        ExtState,
        ExtForeignToplevelListV1,
        [ext_foreign_toplevel_list_v1::EVT_TOPLEVEL_OPCODE => (ExtForeignToplevelHandleV1, ())]
    );
}

impl Dispatch<ExtForeignToplevelHandleV1, ()> for ExtState {
    fn event(
        state: &mut Self,
        proxy: &ExtForeignToplevelHandleV1,
        event: ext_foreign_toplevel_handle_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(window) = state.windows.get_mut(&proxy.id().protocol_id()) else {
            return;
        };
        match event {
            ext_foreign_toplevel_handle_v1::Event::Title { title } => {
                window.title = Some(title);
            }
            ext_foreign_toplevel_handle_v1::Event::AppId { app_id } => {
                window.app_id = Some(app_id);
            }
            ext_foreign_toplevel_handle_v1::Event::Identifier { identifier } => {
                window.identifier = Some(identifier);
            }
            ext_foreign_toplevel_handle_v1::Event::Done => window.ready = true,
            ext_foreign_toplevel_handle_v1::Event::Closed => window.closed = true,
            _ => {}
        }
    }
}

struct WlrSession {
    connection: Connection,
    event_queue: EventQueue<WlrState>,
    _manager: ZwlrForeignToplevelManagerV1,
    seat: Option<wl_seat::WlSeat>,
    state: WlrState,
}

#[derive(Default)]
struct WlrState {
    windows: BTreeMap<u32, WlrWindow>,
}

struct WlrWindow {
    proxy: ZwlrForeignToplevelHandleV1,
    title: Option<String>,
    app_id: Option<String>,
    ready: bool,
    closed: bool,
}

impl WlrSession {
    fn connect() -> Result<Self, BackendError> {
        let connection = Connection::connect_to_env()
            .map_err(|error| wayland_error("connect wlroots foreign-toplevel", error))?;
        let (globals, mut event_queue) = registry_queue_init::<WlrState>(&connection)
            .map_err(|error| wayland_error("read wlroots Wayland globals", error))?;
        let qh = event_queue.handle();
        let manager = globals
            .bind::<ZwlrForeignToplevelManagerV1, _, _>(&qh, 1..=3, ())
            .map_err(|error| wayland_error("bind wlroots foreign-toplevel", error))?;
        let seat = globals.bind::<wl_seat::WlSeat, _, _>(&qh, 1..=1, ()).ok();
        let mut state = WlrState::default();
        event_queue
            .roundtrip(&mut state)
            .map_err(|error| wayland_error("enumerate wlroots foreign toplevels", error))?;
        Ok(Self {
            connection,
            event_queue,
            _manager: manager,
            seat,
            state,
        })
    }

    fn actions(&self) -> Vec<ActionKind> {
        let mut actions = vec![
            ActionKind::Minimize,
            ActionKind::Maximize,
            ActionKind::EndTask,
        ];
        if self.seat.is_some() {
            actions.splice(0..0, [ActionKind::SwitchTo, ActionKind::BringToFront]);
        }
        actions
    }

    fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        self.event_queue
            .roundtrip(&mut self.state)
            .map_err(|error| wayland_error("refresh wlroots foreign toplevels", error))?;
        let actions = self.actions();
        let mut rows = self
            .state
            .windows
            .iter()
            .filter(|(_, window)| window.ready && !window.closed)
            .map(|(id, window)| ApplicationRow {
                identity: ApplicationIdentity {
                    native_id: u64::from(*id),
                    process: None,
                },
                title: window
                    .title
                    .clone()
                    .or_else(|| window.app_id.clone())
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| "Untitled Wayland window".to_string()),
                status: ApplicationStatus::Running,
                window_station: None,
                desktop: None,
                icon_png: None,
                large_icon_png: None,
                allowed_actions: actions.clone(),
                row_error: None,
            })
            .collect::<Vec<_>>();
        rows.sort_by_key(|row| row.title.to_lowercase());
        Ok(SnapshotData::Applications(ApplicationsData { rows }))
    }

    fn execute(&mut self, request: ActionRequest) -> ActionResult {
        let ActionRequest::Window {
            identity,
            operation,
        } = request
        else {
            return ActionResult::unsupported("the requested operation is not a window action");
        };
        let Ok(id) = u32::try_from(identity.native_id) else {
            return ActionResult::failed(BackendError::internal(
                "wlroots window action",
                "window identifier is out of range",
            ));
        };
        let Some(window) = self.state.windows.get(&id).filter(|window| !window.closed) else {
            return ActionResult::failed(BackendError::internal(
                "wlroots window action",
                "the selected window no longer exists",
            ));
        };
        match operation {
            WindowAction::SwitchTo | WindowAction::BringToFront => {
                let Some(seat) = &self.seat else {
                    return ActionResult::unsupported(
                        "the compositor did not expose a seat for activation",
                    );
                };
                window.proxy.activate(seat);
            }
            WindowAction::Minimize => window.proxy.set_minimized(),
            WindowAction::Maximize => window.proxy.set_maximized(),
            WindowAction::Close => window.proxy.close(),
        }
        match self.connection.flush() {
            Ok(()) => ActionResult::succeeded(),
            Err(error) => ActionResult::failed(wayland_error("flush window action", error)),
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for WlrState {
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

impl Dispatch<wl_seat::WlSeat, ()> for WlrState {
    fn event(
        _: &mut Self,
        _: &wl_seat::WlSeat,
        _: wl_seat::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrForeignToplevelManagerV1, ()> for WlrState {
    fn event(
        state: &mut Self,
        _: &ZwlrForeignToplevelManagerV1,
        event: zwlr_foreign_toplevel_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let zwlr_foreign_toplevel_manager_v1::Event::Toplevel { toplevel } = event {
            state.windows.insert(
                toplevel.id().protocol_id(),
                WlrWindow {
                    proxy: toplevel,
                    title: None,
                    app_id: None,
                    ready: false,
                    closed: false,
                },
            );
        }
    }

    wayland_client::event_created_child!(
        WlrState,
        ZwlrForeignToplevelManagerV1,
        [zwlr_foreign_toplevel_manager_v1::EVT_TOPLEVEL_OPCODE => (ZwlrForeignToplevelHandleV1, ())]
    );
}

impl Dispatch<ZwlrForeignToplevelHandleV1, ()> for WlrState {
    fn event(
        state: &mut Self,
        proxy: &ZwlrForeignToplevelHandleV1,
        event: zwlr_foreign_toplevel_handle_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(window) = state.windows.get_mut(&proxy.id().protocol_id()) else {
            return;
        };
        match event {
            zwlr_foreign_toplevel_handle_v1::Event::Title { title } => {
                window.title = Some(title);
            }
            zwlr_foreign_toplevel_handle_v1::Event::AppId { app_id } => {
                window.app_id = Some(app_id);
            }
            zwlr_foreign_toplevel_handle_v1::Event::Done => window.ready = true,
            zwlr_foreign_toplevel_handle_v1::Event::Closed => window.closed = true,
            _ => {}
        }
    }
}

fn stable_identifier(value: &str) -> u64 {
    let mut hash = 0xcbf2_9ce4_8422_2325_u64;
    for byte in value.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

pub(crate) fn wayland_error(context: &str, error: impl std::fmt::Display) -> BackendError {
    BackendError {
        domain: "wayland".to_string(),
        code: -1,
        context: context.to_string(),
        message: error.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{ForeignToplevelProtocol, protocol_candidates, stable_identifier};

    #[test]
    fn stable_identifier_distinguishes_window_tokens() {
        assert_eq!(stable_identifier("window-1"), stable_identifier("window-1"));
        assert_ne!(stable_identifier("window-1"), stable_identifier("window-2"));
    }

    #[test]
    fn standard_protocol_wins_over_wlroots_fallback() {
        let protocols = vec![
            "org_kde_plasma_window_management".to_string(),
            "zwlr_foreign_toplevel_manager_v1".to_string(),
            "ext_foreign_toplevel_list_v1".to_string(),
        ];
        assert_eq!(
            protocol_candidates(&protocols),
            vec![
                ForeignToplevelProtocol::Ext,
                ForeignToplevelProtocol::Wlr,
                ForeignToplevelProtocol::Kde,
            ]
        );
    }
}
