// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 进程亲和性对话框测试
//
//   文件:       flutter_app/test/affinity_dialog_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原 IDD_AFFINITY 行为
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';
import 'package:taskmgr_rs/ui/desktop_dialogs.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  testWidgets('affinity dialog returns the checked logical processors', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.processes));
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final result = showProcessorAffinityDialog(
      tester.element(find.byType(Scaffold)),
      processors: const <int>[0, 1, 2],
      selected: const <int>{0, 1, 2},
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DesktopCheckbox>(
            find.widgetWithText(DesktopCheckbox, 'CPU 1'),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.widgetWithText(DesktopCheckbox, 'CPU 1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(await result, equals(<int>{0, 2}));
  });

  testWidgets('affinity dialog rejects an empty mask', (tester) async {
    final controller = BackendController.preview(sampleState(PageId.processes));
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final result = showProcessorAffinityDialog(
      tester.element(find.byType(Scaffold)),
      processors: const <int>[0],
      selected: const <int>{0},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DesktopCheckbox, 'CPU 0'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('The process must have affinity with at least one processor.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });
}
