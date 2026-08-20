// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 八语言与桌面缩放布局测试
//
//   文件:       flutter_app/test/locale_scaling_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原版 396×401 客户区与八语言矩阵
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

  const locales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];
  const scales = <double>[1, 1.25, 1.5, 2];
  const logicalSize = Size(396, 401);

  for (final locale in locales) {
    for (final scale in scales) {
      testWidgets(
        '${locale.toLanguageTag()} at ${scale * 100}% renders all pages without overflow',
        (tester) async {
          tester.platformDispatcher.localesTestValue = <Locale>[locale];
          tester.view.devicePixelRatio = scale;
          tester.view.physicalSize = logicalSize * scale;
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          final controller = BackendController.preview(
            sampleState(PageId.applications),
          );
          await tester.pumpWidget(TaskManagerApp(controller: controller));
          await tester.pumpAndSettle();

          for (final page in PageId.values) {
            controller.value = sampleState(page);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${locale.toLanguageTag()} ${scale}x ${page.name}',
            );
          }
        },
      );
    }
  }
}
