// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GNOME Shell 只读窗口提供器
//
//   文件:       packaging/linux/gnome-shell-extension/window-provider@org.taskmgr_rs.TaskManager/extension.js
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；GNOME Shell 51.beta；GJS
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   GNOME Shell Extension API；D-Bus Specification；项目 WindowProvider1 协议
// --------------------------------------------------------------------------

import Gio from 'gi://Gio';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const PROTOCOL_VERSION = 1;
const OBJECT_PATH = '/org/taskmgr_rs/WindowProvider';
const MAX_WINDOWS = 4096;
const MAX_TITLE_CODE_UNITS = 4096;
const MAX_IDENTIFIER_CODE_UNITS = 1024;
const MAX_SNAPSHOT_CODE_UNITS = 1_000_000;

const InterfaceXml = `
<node>
  <interface name="org.taskmgr_rs.WindowProvider1">
    <method name="GetVersion">
      <arg name="version" direction="out" type="u"/>
    </method>
    <method name="GetWindows">
      <arg name="snapshot_json" direction="out" type="s"/>
    </method>
  </interface>
</node>`;

class WindowProvider {
    constructor() {
        this._generation = 0;
        this._windowTracker = Shell.WindowTracker.get_default();
    }

    GetVersion() {
        return PROTOCOL_VERSION;
    }

    GetWindows() {
        this._generation = (this._generation + 1) % Number.MAX_SAFE_INTEGER;
        const visibleWindows = global.get_window_actors()
            .map(actor => actor.meta_window)
            .filter(window => window && !window.skip_taskbar);
        if (visibleWindows.length > MAX_WINDOWS)
            throw new Error(`Window count exceeds the ${MAX_WINDOWS} entry safety limit`);

        const windows = visibleWindows.map(window => this._serializeWindow(window));
        const snapshot = JSON.stringify({
            protocol_version: PROTOCOL_VERSION,
            generation: this._generation,
            windows,
        });
        // A JavaScript UTF-16 code unit occupies at most four UTF-8 bytes. This preflight keeps
        // the D-Bus string below the Rust client's independent 4 MiB byte limit.
        if (snapshot.length > MAX_SNAPSHOT_CODE_UNITS)
            throw new Error('Window metadata exceeds the snapshot safety limit');
        return snapshot;
    }

    _serializeWindow(window) {
        const app = this._windowTracker.get_window_app(window);
        const appInfo = app?.get_app_info() ?? null;
        const icon = appInfo?.get_icon() ?? null;
        let iconName = null;
        if (icon instanceof Gio.ThemedIcon)
            [iconName] = icon.get_names();

        const [title, titleTruncated] = boundedText(
            window.get_title(),
            MAX_TITLE_CODE_UNITS,
        );
        const [appId, appIdTruncated] = boundedText(
            app?.get_id() ?? window.get_gtk_application_id(),
            MAX_IDENTIFIER_CODE_UNITS,
        );
        const [wmClass, wmClassTruncated] = boundedText(
            window.get_wm_class(),
            MAX_IDENTIFIER_CODE_UNITS,
        );
        const [safeIconName, iconNameTruncated] = boundedText(
            iconName,
            MAX_IDENTIFIER_CODE_UNITS,
        );
        const pid = window.get_pid();
        const workspace = window.get_workspace();
        const workspaceIndex = workspace?.index() ?? -1;
        return {
            id: window.get_stable_sequence(),
            title: title ?? '',
            app_id: appId,
            wm_class: wmClass,
            icon_name: safeIconName,
            pid: pid > 0 ? pid : null,
            workspace: workspaceIndex >= 0 ? workspaceIndex : null,
            skip_taskbar: Boolean(window.skip_taskbar),
            truncated_fields: titleTruncated || appIdTruncated ||
                wmClassTruncated || iconNameTruncated,
        };
    }
}

function boundedText(value, maximumCodeUnits) {
    if (typeof value !== 'string')
        return [null, false];
    if (value.length <= maximumCodeUnits)
        return [value, false];
    return [value.slice(0, maximumCodeUnits), true];
}

export default class TaskManagerWindowProviderExtension extends Extension {
    enable() {
        this._provider = new WindowProvider();
        this._dbus = Gio.DBusExportedObject.wrapJSObject(
            InterfaceXml,
            this._provider,
        );
        this._dbus.export(Gio.DBus.session, OBJECT_PATH);
    }

    disable() {
        this._dbus?.unexport();
        this._dbus = null;
        this._provider = null;
    }
}
