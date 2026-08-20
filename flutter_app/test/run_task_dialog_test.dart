// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 新建任务对话框测试
//
//   文件:       flutter_app/test/run_task_dialog_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原任务管理器“运行”交互
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

  testWidgets('run dialog returns a trimmed command line', (tester) async {
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final result = showRunTaskDialog(tester.element(find.byType(Scaffold)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(DesktopTextField),
      '  program --name "two words"  ',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(await result, 'program --name "two words"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('run dialog rejects an empty task name', (tester) async {
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final result = showRunTaskDialog(tester.element(find.byType(Scaffold)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Enter the name of a program, folder, document, or Internet resource.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applications Run button opens the shared dialog', (
    tester,
  ) async {
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Run...'));
    await tester.pumpAndSettle();

    expect(find.text('Run'), findsOneWidget);
    expect(find.byType(DesktopTextField), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
