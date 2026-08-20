// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 用户消息对话框测试
//
//   文件:       flutter_app/test/message_dialog_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原 IDD_MESSAGE 对话框行为
// --------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  testWidgets('message text controllers live through the close animation', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.users));
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('james'));
    await tester.pump();
    await tester.tap(find.text('Send Message...'));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopTextField), findsNWidgets(2));

    await tester.enterText(find.byType(DesktopTextField).first, 'Notice');
    await tester.enterText(find.byType(DesktopTextField).last, 'Hello');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Not available'), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });
}
