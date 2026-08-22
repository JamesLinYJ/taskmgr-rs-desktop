// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GNOME Shell 只读窗口提供器
//
//   文件:       packaging/linux/gnome-shell-extension/window-provider@org.taskmgr_rs.TaskManager/extension.js
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x64；Node.js 25.8.1 静态验证；目标 GNOME Shell 45–51/GJS
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   GNOME Shell Extension API；D-Bus Specification；org.freedesktop.DBus 凭据接口；proc(5)；stat(2)；项目 WindowProvider1 协议
// --------------------------------------------------------------------------

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {authorizeCaller} from './authorization.js';

const PROTOCOL_VERSION = 1;
const OBJECT_PATH = '/org/taskmgr_rs/WindowProvider';
const MAX_WINDOWS = 4096;
const MAX_TITLE_CODE_UNITS = 4096;
const MAX_IDENTIFIER_CODE_UNITS = 1024;
const MAX_SNAPSHOT_CODE_UNITS = 1_000_000;
const MAX_PENDING_AUTHORIZATIONS = 16;
const AUTHORIZATION_QUERY_TIMEOUT_MS = 400;
const TRUSTED_EXECUTABLE = '/usr/lib/taskmgr-rs/taskmgr_rs';
const TRUSTED_PARENT_DIRECTORIES = ['/', '/usr', '/usr/lib', '/usr/lib/taskmgr-rs'];
const DBUS_DAEMON = 'org.freedesktop.DBus';
const DBUS_DAEMON_PATH = '/org/freedesktop/DBus';
const ACCESS_DENIED_ERROR =
    'org.taskmgr_rs.WindowProvider1.Error.AccessDenied';
const BUSY_ERROR = 'org.taskmgr_rs.WindowProvider1.Error.LimitsExceeded';
const PROVIDER_ERROR = 'org.taskmgr_rs.WindowProvider1.Error.Failed';
const FILE_ATTRIBUTES =
    'standard::type,unix::uid,unix::mode,unix::device,unix::inode';
const MAX_PROC_STAT_BYTES = 4096;
const PID_REPLY_TYPE = new GLib.VariantType('(u)');

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
        this._pendingAuthorizations = new Set();
        this._disabled = false;
    }

    GetVersionAsync(_parameters, invocation) {
        this._startAuthorizedCall(
            invocation,
            () => new GLib.Variant('(u)', [PROTOCOL_VERSION]),
        );
    }

    GetWindowsAsync(_parameters, invocation) {
        this._startAuthorizedCall(
            invocation,
            () => new GLib.Variant('(s)', [this._serializeSnapshot()]),
        );
    }

    _startAuthorizedCall(invocation, createReply) {
        if (this._disabled) {
            invocation.return_dbus_error(PROVIDER_ERROR, 'Window provider is disabled');
            return;
        }
        if (this._pendingAuthorizations.size >= MAX_PENDING_AUTHORIZATIONS) {
            invocation.return_dbus_error(
                BUSY_ERROR,
                'Too many concurrent window-provider authorization requests',
            );
            return;
        }

        const cancellable = new Gio.Cancellable();
        this._pendingAuthorizations.add(cancellable);
        void this._authorizeAndReply(invocation, cancellable, createReply);
    }

    async _authorizeAndReply(invocation, cancellable, createReply) {
        try {
            const sender = invocation.get_sender();
            const connection = invocation.get_connection();
            await authorizeCaller({
                sender,
                serviceUid: inspectFile(
                    '/proc/self',
                    Gio.FileQueryInfoFlags.NONE,
                ).uid,
                resolveSenderPid: uniqueName => resolveSenderPid(
                    connection,
                    uniqueName,
                    cancellable,
                ),
                inspectTrustedExecutable,
                inspectProcessExecutable,
            });
        } catch (_error) {
            invocation.return_dbus_error(
                ACCESS_DENIED_ERROR,
                'Window enumeration requires the protected system package at ' +
                    `${TRUSTED_EXECUTABLE}; portable and development builds are denied`,
            );
            this._pendingAuthorizations.delete(cancellable);
            return;
        }

        if (this._disabled || cancellable.is_cancelled()) {
            invocation.return_dbus_error(PROVIDER_ERROR, 'Window provider is disabled');
            this._pendingAuthorizations.delete(cancellable);
            return;
        }
        try {
            invocation.return_value(createReply());
        } catch (_error) {
            invocation.return_dbus_error(
                PROVIDER_ERROR,
                'The bounded window snapshot could not be produced',
            );
        } finally {
            this._pendingAuthorizations.delete(cancellable);
        }
    }

    _serializeSnapshot() {
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

    disable() {
        this._disabled = true;
        for (const cancellable of this._pendingAuthorizations)
            cancellable.cancel();
        this._pendingAuthorizations.clear();
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

function resolveSenderPid(connection, sender, cancellable) {
    return new Promise((resolve, reject) => {
        connection.call(
            DBUS_DAEMON,
            DBUS_DAEMON_PATH,
            DBUS_DAEMON,
            'GetConnectionUnixProcessID',
            new GLib.Variant('(s)', [sender]),
            PID_REPLY_TYPE,
            Gio.DBusCallFlags.NONE,
            AUTHORIZATION_QUERY_TIMEOUT_MS,
            cancellable,
            (source, result) => {
                try {
                    const reply = source.call_finish(result);
                    resolve(reply.get_child_value(0).get_uint32());
                } catch (error) {
                    reject(error);
                }
            },
        );
    });
}

function inspectTrustedExecutable() {
    return Promise.resolve({
        parentDirectories: TRUSTED_PARENT_DIRECTORIES.map(path =>
            inspectFile(path, Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS)),
        file: inspectFile(
            TRUSTED_EXECUTABLE,
            Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
        ),
    });
}

function inspectProcessExecutable(pid) {
    const executable = inspectFile(`/proc/${pid}/exe`, Gio.FileQueryInfoFlags.NONE);
    const process = inspectFile(
        `/proc/${pid}`,
        Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
    );
    return Promise.resolve({
        ...executable,
        processUid: process.uid,
        startTime: readProcStartTime(pid),
    });
}

function readProcStartTime(pid) {
    const [success, contents] = Gio.File.new_for_path(`/proc/${pid}/stat`)
        .load_contents(null);
    if (!success || contents.length > MAX_PROC_STAT_BYTES)
        throw new Error('caller procfs stat is unavailable or too large');
    const stat = new TextDecoder().decode(contents);
    const closing = stat.lastIndexOf(')');
    if (closing < 0)
        throw new Error('caller procfs stat has no command terminator');
    const fields = stat.slice(closing + 2).trim().split(/\s+/);
    const startTime = fields[19];
    if (typeof startTime !== 'string' || !/^[0-9]+$/.test(startTime))
        throw new Error('caller procfs stat has no valid start time');
    return startTime;
}

function inspectFile(path, flags) {
    const info = Gio.File.new_for_path(path).query_info(
        FILE_ATTRIBUTES,
        flags,
        null,
    );
    const fileType = info.get_file_type();
    let kind = 'other';
    if (fileType === Gio.FileType.REGULAR)
        kind = 'regular';
    else if (fileType === Gio.FileType.DIRECTORY)
        kind = 'directory';
    requireFileAttribute(info, 'unix::uid', Gio.FileAttributeType.UINT32);
    requireFileAttribute(info, 'unix::mode', Gio.FileAttributeType.UINT32);
    requireFileAttribute(info, 'unix::device', Gio.FileAttributeType.UINT32);
    requireFileAttribute(info, 'unix::inode', Gio.FileAttributeType.UINT64);
    const inode = info.get_attribute_as_string('unix::inode');
    if (typeof inode !== 'string' || !/^[0-9]+$/.test(inode))
        throw new Error('file metadata has no exact inode identity');
    return {
        kind,
        uid: info.get_attribute_uint32('unix::uid'),
        mode: info.get_attribute_uint32('unix::mode'),
        device: info.get_attribute_uint32('unix::device').toString(),
        // GJS exposes guint64 as a JavaScript Number, which would round inode
        // values above Number.MAX_SAFE_INTEGER. Ask GIO to format it exactly
        // on the native side and keep the identity as a decimal string.
        inode,
    };
}

function requireFileAttribute(info, attribute, expectedType) {
    if (!info.has_attribute(attribute) ||
        info.get_attribute_type(attribute) !== expectedType) {
        throw new Error(`file metadata is missing ${attribute}`);
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
        this._provider?.disable();
        this._dbus?.unexport();
        this._dbus = null;
        this._provider = null;
    }
}
