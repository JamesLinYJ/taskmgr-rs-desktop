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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/backend_state.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/l10n/app_localizations.dart';
import 'package:taskmgr_rs/pages/processes_page.dart';
import 'package:taskmgr_rs/src/native_bridge/api.dart' as native;
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';
import 'package:taskmgr_rs/ui/desktop_theme.dart';

import 'support/sample_state.dart';

void main() {
  testWidgets('coalesces a Rust snapshot burst into one UI notification', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.processes));
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    final meta = SnapshotMeta(
      generation: BigInt.one,
      sampledAtMillis: BigInt.one,
      stale: false,
    );

    controller.acceptEventForTesting(
      native.BridgeBackendEvent.processes(
        meta: meta,
        data: const ProcessesData(rows: <ProcessRow>[]),
      ),
    );
    controller.acceptEventForTesting(
      native.BridgeBackendEvent.pageUnavailable(
        page: PageId.network,
        meta: meta,
      ),
    );

    expect(notifications, 0);
    await tester.pump(const Duration(milliseconds: 9));
    expect(notifications, 1);
    expect(controller.value.processes?.rows, isEmpty);
    expect(controller.value.metaFor(PageId.processes), meta);
    expect(controller.value.metaFor(PageId.network), meta);
  });

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

  testWidgets('Go To Process reveals its row without a wheel event', (
    tester,
  ) async {
    final rows = List<ProcessRow>.generate(
      240,
      (index) => ProcessRow(
        identity: ProcessIdentity(
          pid: index + 1,
          startTime: BigInt.from(index + 1),
        ),
        imageName: 'process-$index.exe',
        userName: 'SYSTEM',
      ),
    );
    final target = rows[220];
    final controller = BackendController.preview(
      sampleState(PageId.processes)
          .copyWith(processes: ProcessesData(rows: rows)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: DesktopTheme.data(),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProcessesPage(
            controller: controller,
            data: ProcessesData(rows: rows),
            capability: null,
            confirmations: false,
            processColumns: const <ColumnLayout>[],
            logicalProcessors: const <int>[],
            initialSelection: target.identity,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final table = find.byType(DesktopDataTable<ProcessRow>);
    final targetText = find.text('process-220.exe');
    expect(targetText, findsOneWidget);
    expect(
      tester.getRect(targetText).bottom,
      lessThanOrEqualTo(tester.getRect(table).bottom),
    );
  });
}
