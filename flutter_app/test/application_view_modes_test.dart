// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 应用程序视图模式测试
//
//   文件:       flutter_app/test/application_view_modes_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 Applications ListView 大图标/小图标/详细信息行为
// --------------------------------------------------------------------------

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';
import 'package:taskmgr_rs/ui/desktop_controls.dart';
import 'package:taskmgr_rs/ui/desktop_theme.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  testWidgets('view menu persists modes and keeps the selected application', (
    tester,
  ) async {
    final state = sampleState(PageId.applications);
    final controller = BackendController.preview(state);
    final title = state.applications!.rows.first.title;

    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();
    await _precacheApplicationIcons(tester);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    await _chooseView(tester, 'Large Icons');

    expect(
      controller.value.settings!.applicationViewMode,
      ApplicationViewMode.largeIcons,
    );
    expect(find.byType(DesktopDataTable<ApplicationRow>), findsNothing);
    expect(_assetImages(tester, 'default-process-32.png'), hasLength(2));
    for (final image in _assetImages(tester, 'default-process-32.png')) {
      final renderObject = tester.renderObject<RenderImage>(
        find.descendant(
          of: find.byWidget(image),
          matching: find.byType(RawImage),
        ),
      );
      expect(renderObject.image, isNotNull);
      expect(renderObject.size, const Size.square(32));
    }
    expect(_selectedTitle(title), findsOneWidget);

    await _chooseView(tester, 'Small Icons');

    expect(
      controller.value.settings!.applicationViewMode,
      ApplicationViewMode.smallIcons,
    );
    expect(_assetImages(tester, 'default-process-16.png'), hasLength(2));
    expect(_selectedTitle(title), findsOneWidget);

    final view = find.byKey(const ValueKey<String>('applications-icon-view'));
    final bounds = tester.getRect(view);
    await tester.tapAt(
      Offset(bounds.right - 20, bounds.bottom - 20),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('Run...'),
        matching: find.byType(PopupMenuItem<void>),
      ),
      findsOneWidget,
    );
    expect(find.text('Large Icons'), findsOneWidget);
    expect(find.text('Small Icons'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('●'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details-view blank area opens the view menu', (tester) async {
    final controller = BackendController.preview(
      sampleState(PageId.applications),
    );
    await tester.pumpWidget(TaskManagerApp(controller: controller));
    await tester.pumpAndSettle();

    final table = find.byType(DesktopDataTable<ApplicationRow>);
    final bounds = tester.getRect(table);
    await tester.tapAt(
      Offset(bounds.right - 20, bounds.bottom - 20),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Large Icons'), findsOneWidget);
    expect(find.text('Small Icons'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('●'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _chooseView(WidgetTester tester, String label) async {
  await tester.tap(find.text('View'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Iterable<Image> _assetImages(WidgetTester tester, String filename) {
  return tester
      .widgetList<Image>(find.byType(Image))
      .where(
        (image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName.endsWith(filename),
      );
}

Finder _selectedTitle(String title) {
  return find.ancestor(
    of: find.text(title),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color == DesktopTheme.selection,
    ),
  );
}

Future<void> _precacheApplicationIcons(WidgetTester tester) async {
  final context = tester.element(find.byType(TaskManagerApp));
  await tester.runAsync(() async {
    await Future.wait(<Future<void>>[
      precacheImage(
        const AssetImage('assets/icons/default-process-16.png'),
        context,
      ),
      precacheImage(
        const AssetImage('assets/icons/default-process-32.png'),
        context,
      ),
    ]);
  });
  await tester.pumpAndSettle();
}
