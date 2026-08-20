// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台实时指标图表
//
//   文件:       flutter_app/lib/ui/desktop_graph.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter CustomPainter；项目采样历史与图表语义契约
// --------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'desktop_theme.dart';

class DesktopGraph extends StatelessWidget {
  const DesktopGraph({
    super.key,
    required this.primary,
    this.secondary = const <double>[],
    this.primaryColor = DesktopTheme.graphGreen,
    this.secondaryColor = DesktopTheme.graphRed,
  });

  final List<double> primary;
  final List<double> secondary;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DesktopTheme.graphBackground,
          border: DesktopTheme.panelBorder(),
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium - 1),
            child: CustomPaint(
              painter: _DesktopGraphPainter(
                primary: primary,
                secondary: secondary,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopGraphPainter extends CustomPainter {
  const _DesktopGraphPainter({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final List<double> primary;
  final List<double> secondary;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = DesktopTheme.graphBackground);
    final grid = Paint()
      ..color = DesktopTheme.graphGrid
      ..strokeWidth = 1;
    for (var x = 0.5; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.5; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _drawSeries(canvas, size, primary, primaryColor);
    _drawSeries(canvas, size, secondary, secondaryColor);
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, Color color) {
    if (values.length < 2 || size.width <= 1 || size.height <= 1) {
      return;
    }
    final path = Path();
    final step = size.width / math.max(values.length - 1, 1);
    for (var index = 0; index < values.length; index++) {
      final value = values[index].isFinite ? values[index].clamp(0, 100) : 0;
      final point = Offset(index * step, size.height * (1 - value / 100));
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_DesktopGraphPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class DesktopMeter extends StatelessWidget {
  const DesktopMeter({super.key, required this.value, required this.label});

  final double? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value == null ? null : '${value!.round()}%',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DesktopTheme.graphBackground,
          border: DesktopTheme.panelBorder(),
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium - 1),
            child: CustomPaint(
              painter: _DesktopMeterPainter(value),
              child: Center(
                child: Text(
                  value == null ? '—' : '${value!.round()}%',
                  style: const TextStyle(
                    color: DesktopTheme.graphGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopMeterPainter extends CustomPainter {
  const _DesktopMeterPainter(this.value);

  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = DesktopTheme.graphBackground,
    );
    final normalized = ((value ?? 0).clamp(0, 100)) / 100;
    if (normalized > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          2,
          size.height * (1 - normalized),
          math.max(0, size.width - 4),
          size.height * normalized,
        ),
        Paint()..color = DesktopTheme.graphGreen,
      );
    }
  }

  @override
  bool shouldRepaint(_DesktopMeterPainter oldDelegate) =>
      oldDelegate.value != value;
}
