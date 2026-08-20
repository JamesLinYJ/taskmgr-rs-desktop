// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux nice 值对话框测试
//
//   文件:       flutter_app/test/nice_dialog_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；setpriority(2) nice 范围
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

  testWidgets('nice dialog returns a valid signed value', (tester) async {
    final controller = BackendController.preview(sampleState(PageId.processes));
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final result = showNiceValueDialog(
      tester.element(find.byType(Scaffold)),
      current: 0,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(DesktopTextField), '-7');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(await result, -7);
  });

  testWidgets('nice dialog rejects values outside the kernel range', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.processes));
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final result = showNiceValueDialog(
      tester.element(find.byType(Scaffold)),
      current: 0,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(DesktopTextField), '20');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('The nice value must be an integer between -20 and 19.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
  });
}
