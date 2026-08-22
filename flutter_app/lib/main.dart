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
import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app_window_controller.dart';
import 'app/backend_controller.dart';
import 'app/task_manager_app.dart';
import 'l10n/app_localizations.dart';
import 'src/native_bridge/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final controller = await BackendController.create();
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    controller.reportUiError(details.exception, details.stack);
    if (previousFlutterError != null) {
      previousFlutterError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final previousPlatformError = dispatcher.onError;
  dispatcher.onError = (error, stackTrace) {
    controller.reportUiError(error, stackTrace);
    return previousPlatformError?.call(error, stackTrace) ?? false;
  };
  AppWindowController appWindow = const NoopAppWindowController();
  final desktopWindow = DesktopAppWindowController(
    onGeometryChanged: controller.setWindowGeometry,
    onAlwaysOnTopChanged: (enabled) =>
        controller.setUiPreferences(alwaysOnTop: enabled),
    onExitRequested: () async {
      try {
        await controller.close();
      } finally {
        await ServicesBinding.instance.exitApplication(AppExitType.required);
      }
    },
  );
  final settings = controller.value.settings;
  if (settings != null) {
    try {
      final windowLocale = basicLocaleListResolution(
        WidgetsBinding.instance.platformDispatcher.locales,
        AppLocalizations.supportedLocales,
      );
      final windowTitle = (await AppLocalizations.delegate.load(windowLocale))
          .appTitle;
      await desktopWindow.initialize(settings, title: windowTitle);
      appWindow = desktopWindow;
    } catch (error, stackTrace) {
      desktopWindow.dispose();
      controller.reportUiError(error, stackTrace);
    }
  }
  runApp(TaskManagerApp(controller: controller, windowController: appWindow));
  if (appWindow case final DesktopAppWindowController desktopWindow) {
    unawaited(desktopWindow.show());
  }
}
