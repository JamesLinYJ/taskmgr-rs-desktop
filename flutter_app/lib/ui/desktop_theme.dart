// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台桌面视觉令牌
//
//   文件:       flutter_app/lib/ui/desktop_theme.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter ThemeData/painting；项目桌面密度与可访问性契约
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Shared visual language for the Windows and Linux clients.
///
/// The layout remains deliberately compact, but the rendering is platform
/// neutral: soft surfaces, restrained radii and one blue interaction accent.
/// Pages must consume these tokens instead of inventing local variants.
abstract final class DesktopTheme {
  static const Color background = Color(0xfff2f4f7);
  static const Color surface = Color(0xffffffff);
  static const Color surfaceMuted = Color(0xfff7f8fa);
  static const Color text = Color(0xff20242b);
  static const Color mutedText = Color(0xff667085);
  static const Color disabledText = Color(0xff98a2b3);
  static const Color accent = Color(0xff2563eb);
  static const Color accentPressed = Color(0xff1d4ed8);
  static const Color selection = Color(0xffdbeafe);
  static const Color selectionText = Color(0xff172554);
  static const Color hover = Color(0xffeaf0f8);
  static const Color divider = Color(0xffe1e6ed);
  static const Color border = Color(0xffcbd3dd);
  static const Color borderStrong = Color(0xff98a2b3);
  static const Color focusRing = Color(0xff60a5fa);

  static const Color graphBackground = Color(0xff101820);
  static const Color graphGrid = Color(0xff1d5c49);
  static const Color graphGreen = Color(0xff32e875);
  static const Color graphYellow = Color(0xffffcf4a);
  static const Color graphRed = Color(0xffff6262);

  static const double radiusSmall = 4;
  static const double radiusMedium = 7;
  static const double radiusLarge = 10;
  static const double fontSize = 12;
  static const double menuHeight = 28;
  static const double tabHeight = 32;
  static const double headerHeight = 27;
  static const double rowHeight = 23;
  static const double buttonHeight = 28;
  static const double statusHeight = 24;
  static const double contentMargin = 8;

  static ThemeData data() {
    const textStyle = TextStyle(
      fontFamily: 'NotoSans',
      fontFamilyFallback: <String>['NotoSansSC', 'NotoSansTC'],
      fontSize: fontSize,
      height: 1.2,
      color: text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: accent,
      focusColor: focusRing.withValues(alpha: 0.22),
      hoverColor: hover,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      fontFamily: 'NotoSans',
      fontFamilyFallback: const <String>['NotoSansSC', 'NotoSansTC'],
      textTheme: const TextTheme(
        bodyLarge: textStyle,
        bodyMedium: textStyle,
        bodySmall: textStyle,
        labelLarge: textStyle,
        labelMedium: textStyle,
        labelSmall: textStyle,
        titleMedium: textStyle,
        titleSmall: textStyle,
      ),
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: text,
        error: Color(0xffb42318),
        onError: Colors.white,
        outline: border,
        outlineVariant: divider,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        elevation: 18,
        shadowColor: Color(0x330f172a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLarge)),
          side: BorderSide(color: border),
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          elevation: WidgetStatePropertyAll(10),
          shadowColor: WidgetStatePropertyAll(Color(0x330f172a)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
              side: BorderSide(color: border),
            ),
          ),
          padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
        ),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(borderStrong),
        trackColor: WidgetStatePropertyAll(surfaceMuted),
        trackVisibility: WidgetStatePropertyAll(true),
        thickness: WidgetStatePropertyAll(9),
        radius: Radius.circular(radiusSmall),
      ),
    );
  }

  static Border controlBorder({bool pressed = false}) {
    return Border.all(color: pressed ? accentPressed : borderStrong);
  }

  static Border panelBorder({bool focused = false}) {
    return Border.all(color: focused ? focusRing : border);
  }
}
