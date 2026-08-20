// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 应用程序列表图标测试
//
//   文件:       flutter_app/test/application_icons_test.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 Win32 Applications ListView 小图标与默认图标语义
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmgr_rs/app/backend_controller.dart';
import 'package:taskmgr_rs/app/task_manager_app.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';

import 'support/sample_state.dart';
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  testWidgets(
    'application rows prefer backend PNG and otherwise use fallback',
    (tester) async {
      final base = sampleState(PageId.applications);
      final rows = base.applications!.rows;
      final first = rows.first;
      final asset = await rootBundle.load(
        'assets/icons/default-process-16.png',
      );
      final state = base.copyWith(
        applications: ApplicationsData(
          rows: <ApplicationRow>[
            ApplicationRow(
              identity: first.identity,
              title: first.title,
              status: first.status,
              windowStation: first.windowStation,
              desktop: first.desktop,
              iconPng: asset.buffer.asUint8List(),
              largeIconPng: first.largeIconPng,
              allowedActions: first.allowedActions,
              rowError: first.rowError,
            ),
            rows.last,
          ],
        ),
      );
      final controller = BackendController.preview(state);

      await tester.pumpWidget(TaskManagerApp(controller: controller));
      await tester.pumpAndSettle();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.where((image) => image.image is MemoryImage), hasLength(1));
      expect(
        images.where(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName ==
                  'assets/icons/default-process-16.png',
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
