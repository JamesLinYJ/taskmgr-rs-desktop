// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 桌面窗口选项测试
//
//   文件:       flutter_app/test/window_options_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter widget test；原任务管理器窗口选项行为
// --------------------------------------------------------------------------

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/app_window_controller.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/backend_state.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/api.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  test('CPU tray levels match the 12-icon mapping', () {
    expect(trayIconLevelForCpu(null), 0);
    expect(trayIconLevelForCpu(-1), 0);
    expect(trayIconLevelForCpu(8), 0);
    expect(trayIconLevelForCpu(9), 1);
    expect(trayIconLevelForCpu(50), 6);
    expect(trayIconLevelForCpu(99), 11);
    expect(trayIconLevelForCpu(100), 11);
    expect(trayIconLevelForCpu(101), 11);
  });

  testWidgets('Always On Top updates the native window before settings', (
    tester,
  ) async {
    final appWindow = _FakeAppWindowController();
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(
      TaskManagerApp(controller: controller, windowController: appWindow),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Always On Top'));
    await tester.pumpAndSettle();

    expect(appWindow.alwaysOnTopValues, <bool>[true]);
    expect(controller.value.settings?.alwaysOnTop, isTrue);
  });

  testWidgets('Switch To minimizes Task Manager when the option is enabled', (
    tester,
  ) async {
    final appWindow = _FakeAppWindowController();
    final initial = sampleState(PageId.applications);
    final state = initial.copyWith(
      settings: _copySettings(initial.settings!, minimizeOnUse: true),
    );
    final controller = BackendController.preview(
      state,
      onExecute: (_) async =>
          const ActionResult(status: ActionStatus.succeeded),
    );
    await tester.pumpWidget(
      TaskManagerApp(controller: controller, windowController: appWindow),
    );
    await tester.pumpAndSettle();

    final task = find.text('Project Notes — Text Editor');
    await tester.tap(task);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(task);
    await tester.pumpAndSettle();

    expect(appWindow.minimizeCalls, 1);
  });

  testWidgets('Windows menu applies an allowed action to the selected task', (
    tester,
  ) async {
    final operations = <WindowAction>[];
    final controller = BackendController.preview(
      sampleState(PageId.applications),
      onExecute: (request) async {
        if (request case BridgeActionRequest_Window(:final operation)) {
          operations.add(operation);
        }
        return const ActionResult(status: ActionStatus.succeeded);
      },
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project Notes — Text Editor'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Windows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();

    expect(operations, <WindowAction>[WindowAction.minimize]);
  });

  testWidgets('application multi-selection drives window arrangement', (
    tester,
  ) async {
    final arrangements = <BridgeActionRequest_ArrangeWindows>[];
    final operations = <WindowAction>[];
    final controller = BackendController.preview(
      sampleState(PageId.applications),
      onExecute: (request) async {
        if (request case final BridgeActionRequest_ArrangeWindows value) {
          arrangements.add(value);
        }
        if (request case BridgeActionRequest_Window(:final operation)) {
          operations.add(operation);
        }
        return const ActionResult(status: ActionStatus.succeeded);
      },
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project Notes — Text Editor'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Build output'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Windows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tile Horizontally'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project Notes — Text Editor'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Build output'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(arrangements, hasLength(1));
    expect(
      arrangements.single.identities.map((identity) => identity.nativeId),
      <BigInt>[BigInt.one, BigInt.two],
    );
    expect(arrangements.single.arrangement, WindowArrangement.tileHorizontally);
    expect(operations, <WindowAction>[WindowAction.close, WindowAction.close]);
  });

  testWidgets('Delete and Shift Escape accelerators remain active', (
    tester,
  ) async {
    final operations = <WindowAction>[];
    final appWindow = _FakeAppWindowController();
    final controller = BackendController.preview(
      sampleState(PageId.applications),
      onExecute: (request) async {
        if (request case BridgeActionRequest_Window(:final operation)) {
          operations.add(operation);
        }
        return const ActionResult(status: ActionStatus.succeeded);
      },
    );
    await tester.pumpWidget(
      TaskManagerApp(controller: controller, windowController: appWindow),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project Notes — Text Editor'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(operations, <WindowAction>[WindowAction.close]);
    expect(appWindow.minimizeCalls, 1);
  });

  testWidgets('selected task actions follow the latest snapshot', (
    tester,
  ) async {
    final operations = <WindowAction>[];
    final initial = sampleState(PageId.applications);
    final controller = BackendController.preview(
      initial,
      onExecute: (request) async {
        if (request case BridgeActionRequest_Window(:final operation)) {
          operations.add(operation);
        }
        return const ActionResult(status: ActionStatus.succeeded);
      },
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final original = initial.applications!.rows.first;
    await tester.tap(find.text(original.title));
    await tester.pump(const Duration(milliseconds: 400));

    final refreshed = ApplicationRow(
      identity: original.identity,
      title: original.title,
      status: original.status,
      windowStation: original.windowStation,
      desktop: original.desktop,
      iconPng: original.iconPng,
      largeIconPng: original.largeIconPng,
      allowedActions: const <ActionKind>[ActionKind.maximize],
      rowError: original.rowError,
    );
    controller.value = initial.copyWith(
      applications: ApplicationsData(rows: <ApplicationRow>[refreshed]),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Windows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maximize'));
    await tester.pumpAndSettle();

    expect(operations, <WindowAction>[WindowAction.maximize]);

    controller.value = initial.copyWith(
      applications: const ApplicationsData(rows: <ApplicationRow>[]),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(operations, <WindowAction>[WindowAction.maximize]);
  });

  testWidgets('Go To Process waits for and selects the exact next snapshot', (
    tester,
  ) async {
    final initial = sampleState(PageId.applications);
    final process = initial.processes!.rows.first.identity;
    final controller = BackendController.preview(
      _linkFirstApplication(
        initial.copyWith(processes: const ProcessesData(rows: <ProcessRow>[])),
        process,
      ),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Project Notes — Text Editor'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(_goToProcessMenuItem());
    await tester.pumpAndSettle();

    expect(controller.value.activePage, PageId.processes);
    expect(find.text('taskmgr_rs (32-bit)'), findsNothing);
    expect(_endProcessButton(tester).onPressed, isNull);

    controller.value = controller.value.copyWith(processes: initial.processes);
    await tester.pumpAndSettle();

    expect(find.text('taskmgr_rs (32-bit)'), findsOneWidget);
    expect(_endProcessButton(tester).onPressed, isNotNull);
  });

  testWidgets('Go To Process never falls back to a reused PID', (tester) async {
    final initial = sampleState(PageId.applications);
    final current = initial.processes!.rows.first.identity;
    final reused = ProcessIdentity(
      pid: current.pid,
      startTime: current.startTime + BigInt.one,
    );
    final controller = BackendController.preview(
      _linkFirstApplication(initial, reused),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Project Notes — Text Editor'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(_goToProcessMenuItem());
    await tester.pumpAndSettle();

    expect(controller.value.activePage, PageId.processes);
    expect(find.text('taskmgr_rs (32-bit)'), findsOneWidget);
    expect(_endProcessButton(tester).onPressed, isNull);
  });

  testWidgets('Hide When Minimized stays disabled without a verified tray', (
    tester,
  ) async {
    final appWindow = _FakeAppWindowController();
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(
      TaskManagerApp(controller: controller, windowController: appWindow),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();

    expect(_menuItem(tester, 'Hide When Minimized').onPressed, isNull);
    expect(controller.value.settings?.hideWhenMinimized, isFalse);
  });

  testWidgets('missing StatusNotifier host skips native tray initialization', (
    tester,
  ) async {
    final appWindow = _FakeAppWindowController(
      trayAvailability: Availability.partial,
    );
    final controller = BackendController.preview(
      sampleState(PageId.applications, tray: Availability.unsupported),
    );
    await tester.pumpWidget(
      TaskManagerApp(controller: controller, windowController: appWindow),
    );
    await tester.pumpAndSettle();

    expect(appWindow.trayInitializationCalls, 0);
    expect(appWindow.hideWhenMinimizedValues, <bool>[false]);
    expect(appWindow.trayUpdates, isEmpty);
  });

  testWidgets('verified tray enables hiding and receives the CPU indicator', (
    tester,
  ) async {
    final appWindow = _FakeAppWindowController(
      trayAvailability: Availability.supported,
    );
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(
      TaskManagerApp(controller: controller, windowController: appWindow),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    final hideItem = _menuItem(tester, 'Hide When Minimized');
    expect(hideItem.onPressed, isNotNull);
    await tester.tap(find.text('Hide When Minimized'));
    await tester.pumpAndSettle();

    expect(appWindow.trayInitializationCalls, 1);
    expect(appWindow.hideWhenMinimizedValues, <bool>[false, true]);
    expect(appWindow.trayUpdates, contains((36, 'CPU Usage: 36%')));
    expect(controller.value.settings?.hideWhenMinimized, isTrue);
  });
}

BackendState _linkFirstApplication(
  BackendState state,
  ProcessIdentity process,
) {
  final rows = state.applications!.rows;
  final first = rows.first;
  final linked = ApplicationRow(
    identity: ApplicationIdentity(
      nativeId: first.identity.nativeId,
      process: process,
    ),
    title: first.title,
    status: first.status,
    windowStation: first.windowStation,
    desktop: first.desktop,
    iconPng: first.iconPng,
    largeIconPng: first.largeIconPng,
    allowedActions: first.allowedActions,
    rowError: first.rowError,
  );
  return state.copyWith(
    applications: ApplicationsData(
      rows: <ApplicationRow>[linked, ...rows.skip(1)],
    ),
  );
}

Finder _goToProcessMenuItem() => find.byWidgetPredicate(
  (widget) =>
      widget is DesktopMnemonicText &&
      stripMnemonic(widget.text) == 'Go To Process',
);

DesktopButton _endProcessButton(WidgetTester tester) =>
    tester.widget<DesktopButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DesktopButton &&
            stripMnemonic(widget.label) == 'End Process',
      ),
    );

MenuItemButton _menuItem(WidgetTester tester, String label) =>
    tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(MenuItemButton),
      ),
    );

UiSettings _copySettings(UiSettings current, {required bool minimizeOnUse}) {
  return UiSettings(
    schemaVersion: current.schemaVersion,
    locale: current.locale,
    activePage: current.activePage,
    updateSpeed: current.updateSpeed,
    alwaysOnTop: current.alwaysOnTop,
    minimizeOnUse: minimizeOnUse,
    confirmations: current.confirmations,
    hideWhenMinimized: current.hideWhenMinimized,
    showKernelTimes: current.showKernelTimes,
    oneGraphPerCpu: current.oneGraphPerCpu,
    tinyFootprint: current.tinyFootprint,
    applicationViewMode: current.applicationViewMode,
    window: current.window,
    processColumns: current.processColumns,
  );
}

final class _FakeAppWindowController implements AppWindowController {
  _FakeAppWindowController({this.trayAvailability = Availability.unsupported});

  final Availability trayAvailability;
  final List<bool> alwaysOnTopValues = <bool>[];
  final List<bool> hideWhenMinimizedValues = <bool>[];
  final List<(int?, String)> trayUpdates = <(int?, String)>[];
  int minimizeCalls = 0;
  int trayInitializationCalls = 0;
  bool disposed = false;

  @override
  Future<void> setAlwaysOnTop(bool enabled) async {
    alwaysOnTopValues.add(enabled);
  }

  @override
  Future<void> minimize() async {
    minimizeCalls += 1;
  }

  @override
  Future<Availability> initializeTray({
    required String restoreLabel,
    required String exitLabel,
    required String alwaysOnTopLabel,
    required bool alwaysOnTop,
  }) async {
    trayInitializationCalls += 1;
    return trayAvailability;
  }

  @override
  Future<void> updateTray({
    required int? cpuPercent,
    required String tooltip,
  }) async {
    trayUpdates.add((cpuPercent, tooltip));
  }

  @override
  Future<void> setHideWhenMinimized(bool enabled) async {
    hideWhenMinimizedValues.add(enabled);
  }

  @override
  void dispose() {
    disposed = true;
  }
}
