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
    await tester.pumpAndSettle();

    expect(controller.value.settings?.tinyFootprint, isTrue);
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
    final gridRect = tester.getRect(grid);
    for (var index = 0; index < logicalCount; index++) {
      final graph = find.byKey(ValueKey<String>('logical-cpu-$index'));
      expect(graph, findsOneWidget, reason: 'logical CPU $index is missing');
      final graphRect = tester.getRect(graph);
      expect(graphRect.top, greaterThanOrEqualTo(gridRect.top - 0.01));
      expect(graphRect.bottom, lessThanOrEqualTo(gridRect.bottom + 0.01));
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
