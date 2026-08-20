// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 桌面窗口生命周期控制器
//
//   文件:       flutter_app/lib/app/app_window_controller.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter desktop 系统标题栏；window_manager 0.5.2；tray_manager 0.5.3
// --------------------------------------------------------------------------

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../src/native_bridge/third_party/taskmgr_core.dart';

int trayIconLevelForCpu(int? cpuPercent) {
  final usage = (cpuPercent ?? 0).clamp(0, 100);
  final level = usage * 12 ~/ 100;
  return level >= 12 ? 11 : level;
}

abstract interface class AppWindowController {
  Future<void> setAlwaysOnTop(bool enabled);

  Future<void> minimize();

  Future<Availability> initializeTray({
    required String restoreLabel,
    required String exitLabel,
    required String alwaysOnTopLabel,
    required bool alwaysOnTop,
  });

  Future<void> updateTray({required int? cpuPercent, required String tooltip});

  Future<void> setHideWhenMinimized(bool enabled);

  void dispose();
}

final class NoopAppWindowController implements AppWindowController {
  const NoopAppWindowController();

  @override
  Future<void> minimize() => Future<void>.value();

  @override
  Future<void> setAlwaysOnTop(bool enabled) => Future<void>.value();

  @override
  Future<Availability> initializeTray({
    required String restoreLabel,
    required String exitLabel,
    required String alwaysOnTopLabel,
    required bool alwaysOnTop,
  }) => Future<Availability>.value(Availability.unsupported);

  @override
  Future<void> updateTray({
    required int? cpuPercent,
    required String tooltip,
  }) => Future<void>.value();

  @override
  Future<void> setHideWhenMinimized(bool enabled) => Future<void>.value();

  @override
  void dispose() {}
}

final class DesktopAppWindowController
    with WindowListener, TrayListener
    implements AppWindowController {
  DesktopAppWindowController({
    required this.onGeometryChanged,
    required this.onAlwaysOnTopChanged,
    required this.onExitRequested,
  });

  final Future<void> Function(WindowGeometry geometry) onGeometryChanged;
  final Future<void> Function(bool enabled) onAlwaysOnTopChanged;
  final Future<void> Function() onExitRequested;

  Timer? _geometryTimer;
  Timer? _trayClickTimer;
  late WindowGeometry _lastNormalGeometry;
  bool _initialized = false;
  bool _disposed = false;
  bool _trayListenerRegistered = false;
  bool _trayRegistered = false;
  bool _hideWhenMinimized = false;
  bool _alwaysOnTop = false;
  bool _windowVisible = true;
  String _restoreLabel = '';
  String _exitLabel = '';
  String _alwaysOnTopLabel = '';

  Future<void> initialize(UiSettings settings) async {
    final geometry = settings.window;
    _alwaysOnTop = settings.alwaysOnTop;
    _lastNormalGeometry = WindowGeometry(
      x: _supportsGlobalPosition ? geometry.x : null,
      y: _supportsGlobalPosition ? geometry.y : null,
      width: geometry.width,
      height: geometry.height,
      maximized: false,
    );
    await windowManager.ensureInitialized();

    final restorePosition = await _canRestorePosition(geometry);
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(geometry.width, geometry.height),
        center: !restorePosition,
        alwaysOnTop: settings.alwaysOnTop,
      ),
    );
    if (restorePosition) {
      await windowManager.setBounds(
        Rect.fromLTWH(
          geometry.x!,
          geometry.y!,
          geometry.width,
          geometry.height,
        ),
      );
    }
    if (geometry.maximized) {
      await windowManager.maximize();
    }
    windowManager.addListener(this);
    _initialized = true;
  }

  Future<void> show() async {
    if (!_initialized || _disposed) {
      return;
    }
    await windowManager.show();
    await windowManager.focus();
    _windowVisible = true;
    if (_trayRegistered) {
      await _refreshTrayMenu();
    }
  }

  @override
  Future<void> setAlwaysOnTop(bool enabled) async {
    if (_initialized && !_disposed) {
      await windowManager.setAlwaysOnTop(enabled);
      _alwaysOnTop = enabled;
      if (_trayRegistered) {
        await _refreshTrayMenu();
      }
    }
  }

  @override
  Future<void> minimize() async {
    if (_initialized && !_disposed) {
      await windowManager.minimize();
    }
  }

  @override
  Future<Availability> initializeTray({
    required String restoreLabel,
    required String exitLabel,
    required String alwaysOnTopLabel,
    required bool alwaysOnTop,
  }) async {
    if (!_initialized ||
        _disposed ||
        (!Platform.isWindows && !Platform.isLinux)) {
      return Availability.unsupported;
    }
    if (_trayRegistered) {
      return Platform.isWindows ? Availability.supported : Availability.partial;
    }
    _restoreLabel = restoreLabel;
    _exitLabel = exitLabel;
    _alwaysOnTopLabel = alwaysOnTopLabel;
    _alwaysOnTop = alwaysOnTop;
    try {
      trayManager.addListener(this);
      _trayListenerRegistered = true;
      await trayManager.setIcon(_trayIconPath(0));
      _trayRegistered = true;
      if (_disposed) {
        await _destroyTray();
        return Availability.unsupported;
      }
      await _setTrayMenu();
      if (_disposed) {
        await _destroyTray();
        return Availability.unsupported;
      }
      return Platform.isWindows ? Availability.supported : Availability.partial;
    } catch (_) {
      await _destroyTray();
      return Availability.unsupported;
    }
  }

  @override
  Future<void> updateTray({
    required int? cpuPercent,
    required String tooltip,
  }) async {
    if (!_trayRegistered || _disposed) {
      return;
    }
    final level = trayIconLevelForCpu(cpuPercent);
    await trayManager.setIcon(_trayIconPath(level));
    if (Platform.isWindows) {
      await trayManager.setToolTip(tooltip);
    }
  }

  @override
  Future<void> setHideWhenMinimized(bool enabled) async {
    if (enabled && (!Platform.isWindows || !_trayRegistered)) {
      throw UnsupportedError(
        'Hiding to the notification area requires a verified Windows tray icon.',
      );
    }
    _hideWhenMinimized = enabled;
  }

  @override
  void onWindowResize() => _scheduleGeometryCapture();

  @override
  void onWindowResized() => _scheduleGeometryCapture();

  @override
  void onWindowMove() => _scheduleGeometryCapture();

  @override
  void onWindowMoved() => _scheduleGeometryCapture();

  @override
  void onWindowMaximize() => _scheduleGeometryCapture();

  @override
  void onWindowUnmaximize() => _scheduleGeometryCapture();

  @override
  void onWindowMinimize() {
    _scheduleGeometryCapture();
    if (_hideWhenMinimized) {
      unawaited(_hideMinimizedWindow());
    }
  }

  @override
  void onWindowRestore() {
    _windowVisible = true;
    _scheduleGeometryCapture();
    if (_trayRegistered) {
      unawaited(_refreshTrayMenu());
    }
  }

  void _scheduleGeometryCapture() {
    if (_disposed) {
      return;
    }
    _geometryTimer?.cancel();
    _geometryTimer = Timer(const Duration(milliseconds: 350), _captureGeometry);
  }

  Future<void> _captureGeometry() async {
    if (_disposed || !_initialized) {
      return;
    }
    try {
      final maximized = await windowManager.isMaximized();
      if (!maximized && !await windowManager.isMinimized()) {
        final bounds = await windowManager.getBounds();
        _lastNormalGeometry = WindowGeometry(
          x: _supportsGlobalPosition ? bounds.left : null,
          y: _supportsGlobalPosition ? bounds.top : null,
          width: bounds.width,
          height: bounds.height,
          maximized: false,
        );
      }
      final normal = _lastNormalGeometry;
      await onGeometryChanged(
        WindowGeometry(
          x: normal.x,
          y: normal.y,
          width: normal.width,
          height: normal.height,
          maximized: maximized,
        ),
      );
    } catch (_) {
      // A transient compositor/window teardown race must not overwrite the last
      // trustworthy geometry or interfere with backend shutdown.
    }
  }

  Future<bool> _canRestorePosition(WindowGeometry geometry) async {
    if (!_supportsGlobalPosition) {
      return false;
    }
    final x = geometry.x;
    final y = geometry.y;
    if (x == null || y == null) {
      return false;
    }
    try {
      final titleRegion = Rect.fromLTWH(
        x,
        y,
        geometry.width.clamp(1, 120),
        geometry.height.clamp(1, 40),
      );
      final displays = await screenRetriever.getAllDisplays();
      return displays.any((display) {
        final position = display.visiblePosition ?? Offset.zero;
        final size = display.visibleSize ?? display.size;
        return Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        ).overlaps(titleRegion);
      });
    } catch (_) {
      return false;
    }
  }

  bool get _supportsGlobalPosition {
    if (!Platform.isLinux) {
      return true;
    }
    final forcedBackend = Platform.environment['GDK_BACKEND']?.toLowerCase();
    if (forcedBackend?.contains('x11') == true) {
      return true;
    }
    if (forcedBackend?.contains('wayland') == true) {
      return false;
    }
    return Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() !=
            'wayland' &&
        Platform.environment['WAYLAND_DISPLAY'] == null;
  }

  Future<void> _hideMinimizedWindow() async {
    if (_disposed || !_trayRegistered) {
      return;
    }
    _windowVisible = false;
    try {
      // Publish the recovery command before removing the taskbar entry. If the
      // tray menu cannot be updated, leave the minimized window reachable.
      await _setTrayMenu();
      await windowManager.hide();
    } catch (_) {
      _windowVisible = true;
      _hideWhenMinimized = false;
      await _refreshTrayMenu();
    }
  }

  Future<void> _restoreFromTray() async {
    if (_disposed || !_initialized) {
      return;
    }
    await windowManager.show();
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.focus();
    _windowVisible = true;
    await _refreshTrayMenu();
  }

  Future<void> _setTrayMenu() async {
    if (!_trayRegistered || _disposed) {
      return;
    }
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          if (!_windowVisible) MenuItem(key: 'restore', label: _restoreLabel),
          MenuItem(key: 'exit', label: _exitLabel),
          MenuItem.separator(),
          MenuItem.checkbox(
            key: 'always_on_top',
            label: _alwaysOnTopLabel,
            checked: _alwaysOnTop,
          ),
        ],
      ),
    );
  }

  Future<void> _refreshTrayMenu() async {
    try {
      await _setTrayMenu();
    } catch (_) {
      // Window actions must remain usable even if the desktop tray host exits.
    }
  }

  String _trayIconPath(int level) {
    final suffix = level.toString().padLeft(2, '0');
    final extension = Platform.isWindows ? 'ico' : 'png';
    return 'assets/tray/cpu-usage-level-$suffix.$extension';
  }

  @override
  void onTrayIconMouseDown() {
    if (!Platform.isWindows || _disposed) {
      return;
    }
    if (_trayClickTimer?.isActive == true) {
      _trayClickTimer?.cancel();
      _trayClickTimer = null;
      unawaited(_restoreFromTray());
      return;
    }
    _trayClickTimer = Timer(const Duration(milliseconds: 500), () {
      _trayClickTimer = null;
    });
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isWindows && _trayRegistered && !_disposed) {
      unawaited(_showTrayContextMenu());
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'restore':
        unawaited(_restoreFromTray());
      case 'exit':
        unawaited(onExitRequested());
      case 'always_on_top':
        unawaited(_toggleAlwaysOnTopFromTray());
    }
  }

  Future<void> _toggleAlwaysOnTopFromTray() async {
    final enabled = !_alwaysOnTop;
    await setAlwaysOnTop(enabled);
    await onAlwaysOnTopChanged(enabled);
  }

  Future<void> _showTrayContextMenu() async {
    try {
      await trayManager.popUpContextMenu();
    } catch (_) {
      // The Windows notification area may be restarting.
    }
  }

  Future<void> _destroyTray() async {
    _trayClickTimer?.cancel();
    _trayClickTimer = null;
    if (_trayListenerRegistered) {
      trayManager.removeListener(this);
      _trayListenerRegistered = false;
    }
    if (_trayRegistered) {
      try {
        await trayManager.destroy();
      } catch (_) {
        // The desktop plugin may already be shutting down.
      }
      _trayRegistered = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _geometryTimer?.cancel();
    unawaited(_destroyTray());
    if (_initialized) {
      windowManager.removeListener(this);
    }
  }
}
