// +-------------------------------------------------------------------------
//
//   taskmgr-rs - CPU/GPU 完整信息与引擎选择测试
//
//   文件:       flutter_app/test/hardware_pages_test.dart
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原 IDD_CPUPAGE/IDD_GPUPAGE 信息结构
// --------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  testWidgets('CPU page renders all four typed metric groups', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(396, 401);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = BackendController.preview(sampleState(PageId.cpu));

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Current State'), findsAtLeastNWidgets(1));
    expect(find.text('System Diagnostics'), findsOneWidget);
    expect(find.text('Open File Handles'), findsOneWidget);
    expect(find.text('Topology and Features'), findsOneWidget);
    expect(find.text('Hardware and Cache'), findsOneWidget);
    expect(find.text('Logical Processors'), findsOneWidget);
    expect(find.text('Firmware Max Frequency'), findsOneWidget);
    expect(find.text('5.45 GHz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPU engine selectors expose engines beyond the first four', (
    tester,
  ) async {
    final base = sampleState(PageId.gpu);
    final adapter = base.gpu!.adapters.single;
    final history = Float64List.fromList(<double>[2, 5, 8, 13, 21]);
    final engines = <GpuEngine>[
      ...adapter.engines,
      GpuEngine(
        id: 'compute:1',
        kind: GpuEngineKind.compute,
        ordinal: 1,
        utilizationPercent: 11,
        history: history,
      ),
      GpuEngine(
        id: 'security:2',
        kind: GpuEngineKind.security,
        ordinal: 2,
        utilizationPercent: 3,
        history: history,
      ),
    ];
    final controller = BackendController.preview(
      base.copyWith(
        gpu: GpuData(
          selectedAdapter: BigInt.zero,
          adapters: <GpuAdapter>[_copyAdapter(adapter, engines)],
        ),
      ),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('gpu-engine-selector-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('gpu-engine-selector-3')),
      findsOneWidget,
    );
    expect(find.text('Graphics API'), findsOneWidget);
    expect(find.text('Vulkan 1.4'), findsOneWidget);
    expect(find.text('DirectX Version'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('gpu-engine-selector-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compute 1'), findsOneWidget);
    expect(find.text('Security 2'), findsOneWidget);

    await tester.tap(find.text('Compute 1'));
    await tester.pumpAndSettle();
    expect(find.text('Compute 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GpuAdapter _copyAdapter(GpuAdapter value, List<GpuEngine> engines) {
  return GpuAdapter(
    id: value.id,
    name: value.name,
    driverModel: value.driverModel,
    utilizationPercent: value.utilizationPercent,
    dedicatedUsedBytes: value.dedicatedUsedBytes,
    dedicatedTotalBytes: value.dedicatedTotalBytes,
    sharedUsedBytes: value.sharedUsedBytes,
    sharedTotalBytes: value.sharedTotalBytes,
    temperatureCelsius: value.temperatureCelsius,
    driverName: value.driverName,
    driverVersion: value.driverVersion,
    driverDate: value.driverDate,
    graphicsApi: value.graphicsApi,
    physicalLocation: value.physicalLocation,
    primaryDeviceNode: value.primaryDeviceNode,
    renderDeviceNode: value.renderDeviceNode,
    hardwareReservedBytes: value.hardwareReservedBytes,
    engines: engines,
    dedicatedUsageHistoryPercent: value.dedicatedUsageHistoryPercent,
    sharedUsageHistoryPercent: value.sharedUsageHistoryPercent,
    detailError: value.detailError,
  );
}
