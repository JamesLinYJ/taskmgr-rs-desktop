// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 进程列选择行为测试
//
//   文件:       flutter_app/test/process_columns_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原 Select Columns 对话框行为
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

  testWidgets('select columns keeps Image Name enabled and persists choices', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.processes));

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select Columns...'));
    await tester.pumpAndSettle();

    final imageName = tester.widget<DesktopCheckbox>(
      find.widgetWithText(DesktopCheckbox, 'Image Name'),
    );
    expect(imageName.value, isTrue);
    expect(imageName.onChanged, isNull);

    await tester.tap(find.widgetWithText(DesktopCheckbox, 'CPU'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final layouts = <ColumnId, ColumnLayout>{
      for (final layout in controller.value.settings!.processColumns)
        layout.column: layout,
    };
    expect(layouts[ColumnId.imageName]!.visible, isTrue);
    expect(layouts[ColumnId.cpu]!.visible, isFalse);

    final table = tester.widget<DesktopDataTable<ProcessRow>>(
      find.byType(DesktopDataTable<ProcessRow>),
    );
    expect(table.columns.map((column) => column.label), isNot(contains('CPU')));
  });

  testWidgets('saved process columns control visibility and width', (
    tester,
  ) async {
    final base = sampleState(PageId.processes);
    final current = base.settings!;
    final state = base.copyWith(
      settings: UiSettings(
        schemaVersion: current.schemaVersion,
        locale: current.locale,
        activePage: current.activePage,
        updateSpeed: current.updateSpeed,
        alwaysOnTop: current.alwaysOnTop,
        minimizeOnUse: current.minimizeOnUse,
        confirmations: current.confirmations,
        hideWhenMinimized: current.hideWhenMinimized,
        showKernelTimes: current.showKernelTimes,
        oneGraphPerCpu: current.oneGraphPerCpu,
        tinyFootprint: current.tinyFootprint,
        applicationViewMode: current.applicationViewMode,
        window: current.window,
        processColumns: const <ColumnLayout>[
          ColumnLayout(column: ColumnId.imageName, width: 145, visible: true),
          ColumnLayout(column: ColumnId.pid, width: 50, visible: false),
        ],
      ),
    );
    final controller = BackendController.preview(state);

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final table = tester.widget<DesktopDataTable<ProcessRow>>(
      find.byType(DesktopDataTable<ProcessRow>),
    );
    expect(table.columns, hasLength(1));
    expect(table.columns.single.label, 'Image Name');
    expect(table.columns.single.width, 145);
  });

  testWidgets('32-bit process image names use the localized suffix', (
    tester,
  ) async {
    final controller = BackendController.preview(sampleState(PageId.processes));

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('taskmgr_rs (32-bit)'), findsOneWidget);
  });
}
