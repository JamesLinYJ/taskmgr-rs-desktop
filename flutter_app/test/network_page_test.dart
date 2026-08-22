// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 每网络适配器图表测试
//
//   文件:       flutter_app/test/network_page_test.dart
//
//   日期:       2026年08月22日
//   环境:       Windows 11；Flutter 3.47.1；Dart 3.13
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原任务管理器网络页
// --------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_graph.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  testWidgets('every adapter has a graph and remains in the summary table', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.network));
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopNetworkGraph), findsNWidgets(2));
    expect(find.text('Ethernet'), findsNWidgets(2));
    expect(find.text('Wi-Fi'), findsNWidgets(2));
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Hardware Disabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
