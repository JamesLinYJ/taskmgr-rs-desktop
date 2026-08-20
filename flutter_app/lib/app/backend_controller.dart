// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 后端生命周期控制器
//
//   文件:       flutter_app/lib/app/backend_controller.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter ValueNotifier；Dart Stream；项目 FRB 协议 v1
// --------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../src/native_bridge/api.dart' as native;
import '../src/native_bridge/third_party/taskmgr_core.dart';
import 'backend_state.dart';

/// 接收 Rust 不可变快照，并只替换相应页面的数据引用。
class BackendController extends ValueNotifier<BackendState> {
  BackendController._(super.value);

  native.BackendHandle? _handle;
  StreamSubscription<native.BridgeBackendEvent>? _subscription;
  bool _isPreview = false;
  Future<ActionResult?> Function(native.BridgeActionRequest request)?
  _previewAction;

  static Future<BackendController> create() async {
    UiSettings settings;
    String? warning;
    try {
      final loaded = await native.loadSettings();
      settings = loaded.settings;
      warning = loaded.warning?.message;
    } catch (error) {
      settings = await UiSettings.default_();
      warning = error.toString();
    }

    final controller = BackendController._(
      BackendState(
        activePage: settings.activePage,
        updateSpeed: settings.updateSpeed,
        settings: settings,
        errorText: warning,
      ),
    );
    try {
      final handle = await native.startBackend(
        options: BackendOptions(
          updateSpeed: settings.updateSpeed,
          activePage: settings.activePage,
          includePrivilegedDetails: false,
        ),
      );
      controller._handle = handle;
      controller._subscription = native
          .watchBackend(handle: handle)
          .listen(controller._acceptEvent, onError: controller._acceptError);
    } catch (error) {
      controller.value = controller.value.copyWith(
        loading: false,
        errorText: error.toString(),
      );
    }
    return controller;
  }

  @visibleForTesting
  factory BackendController.preview(
    BackendState state, {
    Future<ActionResult?> Function(native.BridgeActionRequest request)?
    onExecute,
  }) {
    return BackendController._(state)
      .._isPreview = true
      .._previewAction = onExecute;
  }

  void _acceptError(Object error, StackTrace stackTrace) {
    value = value.copyWith(loading: false, errorText: error.toString());
  }

  void _acceptEvent(native.BridgeBackendEvent event) {
    final next = switch (event) {
      native.BridgeBackendEvent_Capabilities(:final field0) => value.copyWith(
        loading: false,
        capabilities: field0,
      ),
      native.BridgeBackendEvent_Applications(:final meta, :final data) =>
        value
            .copyWith(loading: false, applications: data)
            .withSnapshotMeta(PageId.applications, meta),
      native.BridgeBackendEvent_Processes(:final meta, :final data) =>
        value
            .copyWith(loading: false, processes: data)
            .withSnapshotMeta(PageId.processes, meta),
      native.BridgeBackendEvent_Performance(:final meta, :final data) =>
        value
            .copyWith(loading: false, performance: data)
            .withSnapshotMeta(PageId.performance, meta),
      native.BridgeBackendEvent_Cpu(:final meta, :final data) =>
        value
            .copyWith(loading: false, cpu: data)
            .withSnapshotMeta(PageId.cpu, meta),
      native.BridgeBackendEvent_Gpu(:final meta, :final data) =>
        value
            .copyWith(loading: false, gpu: data)
            .withSnapshotMeta(PageId.gpu, meta),
      native.BridgeBackendEvent_Network(:final meta, :final data) =>
        value
            .copyWith(loading: false, network: data)
            .withSnapshotMeta(PageId.network, meta),
      native.BridgeBackendEvent_Users(:final meta, :final data) =>
        value
            .copyWith(loading: false, users: data)
            .withSnapshotMeta(PageId.users, meta),
      native.BridgeBackendEvent_PageUnavailable(:final page, :final meta) =>
        value.withSnapshotMeta(page, meta),
      native.BridgeBackendEvent_PrivilegeChanged() => value,
    };
    value = next;
  }

  Future<void> selectPage(PageId page) async {
    value = value.copyWith(
      activePage: page,
      settings: _copySettings(value.settings, activePage: page),
    );
    await _pushOptions();
    await _saveSettings();
    final handle = _handle;
    if (handle != null) {
      await native.requestRefresh(handle: handle, page: page);
    }
  }

  Future<void> setUpdateSpeed(UpdateSpeed speed) async {
    value = value.copyWith(
      updateSpeed: speed,
      settings: _copySettings(value.settings, updateSpeed: speed),
    );
    await _pushOptions();
    await _saveSettings();
  }

  Future<void> setUiPreferences({
    bool? alwaysOnTop,
    bool? minimizeOnUse,
    bool? confirmations,
    bool? hideWhenMinimized,
    bool? showKernelTimes,
    bool? oneGraphPerCpu,
    ApplicationViewMode? applicationViewMode,
    WindowGeometry? window,
    List<ColumnLayout>? processColumns,
  }) async {
    final current = value.settings;
    if (current == null) {
      return;
    }
    final settings = UiSettings(
      schemaVersion: current.schemaVersion,
      locale: current.locale,
      activePage: value.activePage,
      updateSpeed: value.updateSpeed,
      alwaysOnTop: alwaysOnTop ?? current.alwaysOnTop,
      minimizeOnUse: minimizeOnUse ?? current.minimizeOnUse,
      confirmations: confirmations ?? current.confirmations,
      hideWhenMinimized: hideWhenMinimized ?? current.hideWhenMinimized,
      showKernelTimes: showKernelTimes ?? current.showKernelTimes,
      oneGraphPerCpu: oneGraphPerCpu ?? current.oneGraphPerCpu,
      applicationViewMode: applicationViewMode ?? current.applicationViewMode,
      window: window ?? current.window,
      processColumns: processColumns ?? current.processColumns,
    );
    value = value.copyWith(settings: settings);
    await _saveSettings();
  }

  Future<void> setWindowGeometry(WindowGeometry geometry) {
    return setUiPreferences(window: geometry);
  }

  Future<void> refresh([PageId? page]) async {
    final handle = _handle;
    if (handle != null) {
      await native.requestRefresh(handle: handle, page: page);
    }
  }

  Future<ActionResult?> execute(native.BridgeActionRequest request) async {
    if (_previewAction case final action?) {
      return action(request);
    }
    final handle = _handle;
    if (handle == null) {
      return null;
    }
    return native.executeAction(handle: handle, request: request);
  }

  void reportUiError(Object error) {
    value = value.copyWith(errorText: error.toString());
  }

  Future<void> _pushOptions() async {
    final handle = _handle;
    if (handle == null) {
      return;
    }
    await native.updateOptions(
      handle: handle,
      options: BackendOptions(
        updateSpeed: value.updateSpeed,
        activePage: value.activePage,
        includePrivilegedDetails: false,
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (_isPreview) {
      return;
    }
    final settings = value.settings;
    if (settings == null) {
      return;
    }
    try {
      await native.saveSettings(settings: settings);
    } catch (error) {
      value = value.copyWith(errorText: error.toString());
    }
  }

  UiSettings? _copySettings(
    UiSettings? current, {
    PageId? activePage,
    UpdateSpeed? updateSpeed,
  }) {
    if (current == null) {
      return null;
    }
    return UiSettings(
      schemaVersion: current.schemaVersion,
      locale: current.locale,
      activePage: activePage ?? current.activePage,
      updateSpeed: updateSpeed ?? current.updateSpeed,
      alwaysOnTop: current.alwaysOnTop,
      minimizeOnUse: current.minimizeOnUse,
      confirmations: current.confirmations,
      hideWhenMinimized: current.hideWhenMinimized,
      showKernelTimes: current.showKernelTimes,
      oneGraphPerCpu: current.oneGraphPerCpu,
      applicationViewMode: current.applicationViewMode,
      window: current.window,
      processColumns: current.processColumns,
    );
  }

  Future<void> close() async {
    await _subscription?.cancel();
    final handle = _handle;
    _handle = null;
    if (handle != null) {
      await native.shutdownBackend(handle: handle);
    }
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
