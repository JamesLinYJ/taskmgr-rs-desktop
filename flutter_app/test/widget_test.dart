// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 窗口壳测试
//
//   文件:       flutter_app/test/widget_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；项目七页 UI 基线
// --------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/backend_state.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';

void main() {
  testWidgets('shows the seven task-manager tabs', (tester) async {
    final controller = BackendController.preview(
      const BackendState(loading: false),
    );

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Processes'), findsOneWidget);
    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('Networking'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });
}
