// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 性能页交互与逐核心布局测试
//
//   文件:       flutter_app/test/performance_behavior_test.dart
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原 IDD_PERFPAGE 双击与逐处理器历史行为
// --------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';
import 'package:taskmgr_rs/ui/desktop_graph.dart';
import 'package:taskmgr_rs/ui/desktop_theme.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  testWidgets('double-click toggles the original performance compact view', (
    tester,
  ) async {
    final controller = BackendController.preview(
      sampleState(PageId.performance),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopMenuBar), findsOneWidget);
    expect(find.byType(DesktopStatusBar), findsOneWidget);
    expect(find.text('Physical Memory (K)'), findsOneWidget);

    await _doubleTap(
      tester,
      find.byKey(
        const ValueKey<String>('performance-page-double-click-target'),
      ),
    );
    await tester.pump();

    expect(controller.value.settings?.tinyFootprint, isTrue);
    expect(
      find.byKey(const ValueKey<String>('performance-layout-normal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('performance-layout-tiny')),
      findsOneWidget,
    );
    await tester.pump(DesktopTheme.pageTransitionDuration ~/ 2);
    expect(
      find.byKey(const ValueKey<String>('performance-layout-normal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('performance-layout-tiny')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesktopMenuBar), findsNothing);
    expect(find.byType(DesktopStatusBar), findsNothing);
    expect(find.text('Physical Memory (K)'), findsNothing);
    expect(find.text('CPU Usage History'), findsOneWidget);

    await _doubleTap(
      tester,
      find.byKey(
        const ValueKey<String>('performance-page-double-click-target'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.value.settings?.tinyFootprint, isFalse);
    expect(find.byType(DesktopMenuBar), findsOneWidget);
    expect(find.byType(DesktopStatusBar), findsOneWidget);
  });

  testWidgets('all logical processors fit inside the original-size graph', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(396, 401);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const logicalCount = 32;
    final base = sampleState(PageId.performance);
    final controller = BackendController.preview(
      base.copyWith(
        performance: _withLogicalCount(base.performance!, logicalCount),
      ),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final grid = find.byKey(const ValueKey<String>('logical-cpu-grid-32'));
    expect(grid, findsOneWidget);
    expect(
      find.descendant(of: grid, matching: find.byType(Scrollable)),
      findsNothing,
    );
    expect(find.text('CPU0 - SMT0'), findsOneWidget);
    expect(find.text('CPU1 - SMT1'), findsOneWidget);
    final firstGraphElement = tester.element(
      find.byKey(const ValueKey<String>('logical-cpu-0')),
    );
    final gridRect = tester.getRect(grid);
    for (var index = 0; index < logicalCount; index++) {
      final graph = find.byKey(ValueKey<String>('logical-cpu-$index'));
      expect(graph, findsOneWidget, reason: 'logical CPU $index is missing');
      final graphRect = tester.getRect(graph);
      expect(graphRect.top, greaterThanOrEqualTo(gridRect.top - 0.01));
      expect(graphRect.bottom, lessThanOrEqualTo(gridRect.bottom + 0.01));
    }

    for (final size in const <Size>[
      Size(620, 460),
      Size(860, 620),
      Size(396, 401),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(
        identical(
          tester.element(find.byKey(const ValueKey<String>('logical-cpu-0'))),
          firstGraphElement,
        ),
        isTrue,
      );
      final resizedGridRect = tester.getRect(grid);
      for (var index = 0; index < logicalCount; index++) {
        final graphRect = tester.getRect(
          find.byKey(ValueKey<String>('logical-cpu-$index')),
        );
        expect(graphRect.top, greaterThanOrEqualTo(resizedGridRect.top - 0.01));
        expect(
          graphRect.bottom,
          lessThanOrEqualTo(resizedGridRect.bottom + 0.01),
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Linux keeps the layout but uses native memory semantics', (
    tester,
  ) async {
    final controller = BackendController.preview(
      sampleState(PageId.performance, platform: PlatformKind.linux),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Open File Handles'), findsOneWidget);
    expect(find.text('Virtual Memory (K)'), findsOneWidget);
    expect(find.text('Swap Used'), findsOneWidget);
    expect(find.text('Slab'), findsOneWidget);
    expect(find.text('Kernel Stack'), findsOneWidget);
    expect(find.text('Page Tables'), findsOneWidget);
    expect(find.text('Handles'), findsNothing);
  });

  testWidgets('Windows preserves the archived Task Manager metric names', (
    tester,
  ) async {
    final controller = BackendController.preview(
      sampleState(PageId.performance, platform: PlatformKind.windows),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Handles'), findsOneWidget);
    expect(find.text('Commit Charge (K)'), findsOneWidget);
    expect(find.text('Paged'), findsOneWidget);
    expect(find.text('Nonpaged'), findsOneWidget);
    expect(find.text('Open File Handles'), findsNothing);
    expect(find.text('Virtual Memory (K)'), findsNothing);
  });

  testWidgets(
    'performance meters and memory history preserve classic visuals',
    (tester) async {
      final controller = BackendController.preview(
        sampleState(PageId.performance, platform: PlatformKind.windows),
      );
      await tester.pumpWidget(TaskManagerApp(controller: controller));
      await tester.pumpAndSettle();

      expect(DesktopMeter.segmentWidth, 33);
      expect(DesktopMeter.centerGap, 1);
      expect(DesktopMeter.segmentHeight, 2);
      expect(DesktopMeter.segmentGap, 2);
      expect(find.text('19.7 GB'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DesktopGraph &&
              widget.primaryColor == DesktopTheme.graphYellow,
        ),
        findsOneWidget,
      );
    },
  );
}

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(target);
}

PerformanceData _withLogicalCount(PerformanceData value, int count) {
  Float64List history(int index, double ceiling) => Float64List.fromList(
    List<double>.generate(
      60,
      (sample) => (sample * (index + 3) % ceiling).toDouble(),
    ),
  );

  return PerformanceData(
    processCount: value.processCount,
    threadCount: value.threadCount,
    handleCount: value.handleCount,
    openFileCount: value.openFileCount,
    memoryTotalKib: value.memoryTotalKib,
    memoryAvailableKib: value.memoryAvailableKib,
    fileCacheKib: value.fileCacheKib,
    commitTotalKib: value.commitTotalKib,
    commitLimitKib: value.commitLimitKib,
    commitPeakKib: value.commitPeakKib,
    kernelTotalKib: value.kernelTotalKib,
    kernelPagedKib: value.kernelPagedKib,
    kernelNonPagedKib: value.kernelNonPagedKib,
    swapUsedKib: value.swapUsedKib,
    slabKib: value.slabKib,
    kernelStackKib: value.kernelStackKib,
    pageTablesKib: value.pageTablesKib,
    cpuPercent: value.cpuPercent,
    memoryPercent: value.memoryPercent,
    cpuHistory: value.cpuHistory,
    kernelHistory: value.kernelHistory,
    memoryHistory: value.memoryHistory,
    logicalCpuLabels: List<String>.generate(
      count,
      (index) => 'CPU$index - SMT${index % 2}',
    ),
    logicalCpuHistories: List<Float64List>.generate(
      count,
      (index) => history(index, 100),
    ),
    logicalKernelHistories: List<Float64List>.generate(
      count,
      (index) => history(index, 35),
    ),
  );
}
