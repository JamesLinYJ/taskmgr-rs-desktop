// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 桌面应用入口
//
//   文件:       flutter_app/lib/main.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter desktop lifecycle；flutter_rust_bridge 2.12
// --------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app_window_controller.dart';
import 'app/backend_controller.dart';
import 'app/task_manager_app.dart';
import 'src/native_bridge/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final controller = await BackendController.create();
  AppWindowController appWindow = const NoopAppWindowController();
  final desktopWindow = DesktopAppWindowController(
    onGeometryChanged: controller.setWindowGeometry,
    onAlwaysOnTopChanged: (enabled) =>
        controller.setUiPreferences(alwaysOnTop: enabled),
    onExitRequested: () async {
      await controller.close();
      await SystemNavigator.pop();
    },
  );
  final settings = controller.value.settings;
  if (settings != null) {
    try {
      await desktopWindow.initialize(settings);
      appWindow = desktopWindow;
    } catch (error) {
      desktopWindow.dispose();
      controller.reportUiError(error);
    }
  }
  runApp(TaskManagerApp(controller: controller, windowController: appWindow));
  if (appWindow case final DesktopAppWindowController desktopWindow) {
    unawaited(desktopWindow.show());
  }
}
