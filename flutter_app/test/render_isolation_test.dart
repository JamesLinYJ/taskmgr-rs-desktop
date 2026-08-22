// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 高频快照渲染隔离测试
//
//   文件:       flutter_app/test/render_isolation_test.dart
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x86_64；Flutter 3.47.1；Dart 3.13
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter debugOnRebuildDirtyWidget；不可变后端快照
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/pages/processes_page.dart';
import 'package:taskmgr_rs/src/native_bridge/api.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  testWidgets('status-only performance updates do not rebuild process rows', (
    tester,
  ) async {
    final initial = sampleState(PageId.processes);
    final controller = BackendController.preview(initial);
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    var processPageRebuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget is ProcessesPage) {
        processPageRebuilds += 1;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);

    controller.acceptEventForTesting(
      BridgeBackendEvent.performance(
        meta: SnapshotMeta(
          generation: BigInt.two,
          sampledAtMillis: BigInt.from(2),
          stale: false,
        ),
        data: initial.performance!,
      ),
    );
    await tester.pump(const Duration(milliseconds: 9));
    await tester.pump();

    expect(processPageRebuilds, 0);
  });
}
