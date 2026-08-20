// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 测试字体加载器
//
//   文件:       flutter_app/test/support/test_fonts.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter FontLoader；项目内置 Noto Sans 字体清单
// --------------------------------------------------------------------------

import 'package:flutter/services.dart';

/// 加载生产环境使用的真实字体，避免 golden 被 Ahem 占位字形污染。
Future<void> loadTestFonts() async {
  await Future.wait(<Future<void>>[
    _loadFont('NotoSans', 'assets/fonts/NotoSans-VF.ttf'),
    _loadFont('NotoSansSC', 'assets/fonts/NotoSansSC-VF.ttf'),
    _loadFont('NotoSansTC', 'assets/fonts/NotoSansTC-VF.ttf'),
  ]);
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
