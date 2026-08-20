// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 七页桌面 UI golden 测试
//
//   文件:       flutter_app/test/desktop_pages_golden_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter golden test；docs/ui-baseline/layout-spec.yaml
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  for (final page in PageId.values) {
    testWidgets('desktop ${page.name} page matches its baseline', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = BackendController.preview(sampleState(page));

      await tester.pumpWidget(TaskManagerApp(controller: controller));
      await tester.pumpAndSettle();
      if (page == PageId.applications) {
        await _precacheApplicationIcons(tester);
      }

      await expectLater(
        find.byType(TaskManagerApp),
        matchesGoldenFile('goldens/desktop_${page.name}_800x600.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in <ApplicationViewMode>[
    ApplicationViewMode.largeIcons,
    ApplicationViewMode.smallIcons,
  ]) {
    testWidgets('desktop applications ${mode.name} view matches its baseline', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = BackendController.preview(
        sampleState(PageId.applications),
      );
      await controller.setUiPreferences(applicationViewMode: mode);

      await tester.pumpWidget(TaskManagerApp(controller: controller));
      await tester.pumpAndSettle();
      await _precacheApplicationIcons(tester);

      await expectLater(
        find.byType(TaskManagerApp),
        matchesGoldenFile(
          'goldens/desktop_applications_${mode.name}_800x600.png',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _precacheApplicationIcons(WidgetTester tester) async {
  final context = tester.element(find.byType(TaskManagerApp));
  await tester.runAsync(() async {
    await Future.wait(<Future<void>>[
      precacheImage(
        const AssetImage('assets/icons/default-process-16.png'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/icons/default-process-32.png'),
        context,
      ),
    ]);
  });
  await tester.pumpAndSettle();
}
