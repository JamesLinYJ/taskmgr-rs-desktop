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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/backend_state.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_theme.dart';

import 'support/sample_state.dart';

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
    expect(
      tester.widgetList<Title>(find.byType(Title)).map((title) => title.title),
      contains('Windows NT Task Manager'),
    );
  });

  testWidgets('uses the localized Windows NT title on every platform', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final controller = BackendController.preview(
      const BackendState(loading: false),
    );

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<Title>(find.byType(Title)).map((title) => title.title),
      contains('Windows NT 任务管理器'),
    );
  });

  testWidgets('switching pages uses the bounded desktop transition', (
    tester,
  ) async {
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    controller.value = sampleState(PageId.processes);
    await tester.pump();

    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      DesktopTheme.pageTransitionDuration,
    );

    expect(
      find.byKey(const ValueKey<PageId>(PageId.applications)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<PageId>(PageId.processes)),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<PageId>(PageId.applications)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<PageId>(PageId.processes)),
      findsOneWidget,
    );
  });
}
