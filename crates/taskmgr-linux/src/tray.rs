// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux 通知区域能力探测
//
//   文件:       crates/taskmgr-linux/src/tray.rs
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   D-Bus Specification；StatusNotifierItem Specification
// --------------------------------------------------------------------------

//! 只有会话总线上真实存在 StatusNotifierWatcher 时才启用 Flutter AppIndicator。
//! 这避免在不提供托盘宿主的 GNOME Wayland 会话中触发废弃的 GtkStatusIcon 回退。

use std::time::Duration;

use taskmgr_core::Availability;
use zbus::blocking::fdo::DBusProxy;
use zbus::names::BusName;

const STATUS_NOTIFIER_WATCHER: &str = "org.kde.StatusNotifierWatcher";
const METHOD_TIMEOUT: Duration = Duration::from_millis(500);

pub(crate) fn availability() -> Availability {
    let Ok(connection) = zbus::blocking::connection::Builder::session()
        .and_then(|builder| builder.method_timeout(METHOD_TIMEOUT).build())
    else {
        return Availability::Unsupported;
    };
    let Ok(proxy) = DBusProxy::new(&connection) else {
        return Availability::Unsupported;
    };
    let Ok(name) = BusName::try_from(STATUS_NOTIFIER_WATCHER) else {
        return Availability::Unsupported;
    };
    if proxy.name_has_owner(name).unwrap_or(false) {
        // Registration and menus are available, but host lifetime is outside this process.
        Availability::Partial
    } else {
        Availability::Unsupported
    }
}
