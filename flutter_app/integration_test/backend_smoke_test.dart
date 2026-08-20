// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter/Rust 桌面集成冒烟测试
//
//   文件:       flutter_app/integration_test/backend_smoke_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter integration_test；flutter_rust_bridge 2.12
// --------------------------------------------------------------------------

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/frb_generated.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts the native backend and renders the desktop shell', (
    tester,
  ) async {
    await RustLib.init();
    final controller = await BackendController.create();

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pump(const Duration(seconds: 2));

    final applicationCapability = controller.value.capabilities?.pages
        .where((page) => page.page == PageId.applications)
        .firstOrNull;
    expect(
      applicationCapability?.availability,
      isNot(Availability.unsupported),
      reason: applicationCapability?.detail ?? controller.value.errorText,
    );
    if (Platform.environment['XDG_SESSION_TYPE'] == 'wayland') {
      expect(
        applicationCapability?.detail,
        anyOf(contains('Wayland'), contains('KDE Plasma')),
      );
    }
    final expectedWindowTitle =
        Platform.environment['TASKMGR_EXPECT_WINDOW_TITLE'];
    if (expectedWindowTitle != null) {
      expect(
        controller.value.applications?.rows.any(
          (row) => row.title.contains(expectedWindowTitle),
        ),
        isTrue,
        reason: 'the Wayland backend did not enumerate the fixture window',
      );
    }
    expect(find.byType(DesktopTabs<PageId>), findsOneWidget);
  });
}
