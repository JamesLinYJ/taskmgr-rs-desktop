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
    this.compact = false,
    this.label,
  });

  final List<double> primary;
  final List<double> secondary;
  final Color primaryColor;
  final Color secondaryColor;

  /// Small per-processor panes use the original one-pixel, non-antialiased line.
  final bool compact;

  /// Optional semantic title rendered inside the plot, matching classic task-manager charts.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final graphLabel = label?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DesktopTheme.graphBackground,
        border: DesktopTheme.panelBorder(),
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium - 1),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const CustomPaint(
                painter: _DesktopGraphGridPainter(),
                child: SizedBox.expand(),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _DesktopGraphSeriesPainter(
                    primary: primary,
                    secondary: secondary,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    compact: compact,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              if (graphLabel != null && graphLabel.isNotEmpty)
                Positioned(
                  left: 3,
                  top: 2,
                  right: 1,
                  child: IgnorePointer(
                    child: Text(
                      graphLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xb3ffffff),
                        fontSize: compact ? 8 : DesktopTheme.fontSize,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopGraphGridPainter extends CustomPainter {
  const _DesktopGraphGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = DesktopTheme.graphBackground);
    final grid = Paint()
      ..color = DesktopTheme.graphGrid
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (var x = 0.5; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.5; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_DesktopGraphGridPainter oldDelegate) => false;
}

class _DesktopGraphSeriesPainter extends CustomPainter {
  const _DesktopGraphSeriesPainter({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
    required this.compact,
  });

  final List<double> primary;
  final List<double> secondary;
  final Color primaryColor;
  final Color secondaryColor;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
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
        ..strokeWidth = compact ? 1 : 2
        ..strokeCap = compact ? StrokeCap.butt : StrokeCap.round
        ..strokeJoin = compact ? StrokeJoin.miter : StrokeJoin.round
        ..isAntiAlias = !compact,
    );
  }

  @override
  bool shouldRepaint(_DesktopGraphSeriesPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.compact != compact;
  }
}

/// Classic networking chart with an adaptive percent scale and three full-duplex series.
class DesktopNetworkGraph extends StatelessWidget {
  const DesktopNetworkGraph({
    super.key,
    required this.received,
    required this.sent,
  });

  final List<double> received;
  final List<double> sent;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DefaultTextStyle.of(context).style.copyWith(
      color: DesktopTheme.graphYellow,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DesktopTheme.graphBackground,
          border: DesktopTheme.panelBorder(),
        ),
        child: CustomPaint(
          painter: _DesktopNetworkGraphPainter(
            received: received,
            sent: sent,
            labelStyle: labelStyle,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _DesktopNetworkGraphPainter extends CustomPainter {
  const _DesktopNetworkGraphPainter({
    required this.received,
    required this.sent,
    required this.labelStyle,
  });

  final List<double> received;
  final List<double> sent;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = DesktopTheme.graphBackground,
    );
    if (size.width <= 2 || size.height <= 2) {
      return;
    }
    final total = List<double>.generate(
      math.max(received.length, sent.length),
      (index) => math.max(
        index < received.length ? _finitePercent(received[index]) : 0,
        index < sent.length ? _finitePercent(sent[index]) : 0,
      ),
      growable: false,
    );
    final maximum = <double>[
      ...received,
      ...sent,
      ...total,
    ].map(_finitePercent).fold(0.0, math.max);
    final scale = _networkScale(maximum);
    final labels = <String>[
      _percentLabel(scale),
      _percentLabel(scale / 2),
      '0 %',
    ];
    final painters = labels
        .map(
          (label) => TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(),
        )
        .toList(growable: false);
    final scaleWidth =
        painters.map((painter) => painter.width).fold(0.0, math.max) + 7;
    for (var index = 0; index < painters.length; index++) {
      final painter = painters[index];
      final y = switch (index) {
        0 => 1.0,
        1 => (size.height - painter.height) / 2,
        _ => size.height - painter.height - 1,
      };
      painter.paint(canvas, Offset(scaleWidth - painter.width - 4, y));
    }

    final dividerX = scaleWidth + 0.5;
    final axis = Paint()
      ..color = DesktopTheme.graphYellow
      ..strokeWidth = 1;
    canvas.drawLine(Offset(dividerX, 0), Offset(dividerX, size.height), axis);
    final plot = Rect.fromLTRB(dividerX + 1, 0, size.width, size.height);
    if (plot.width <= 1) {
      return;
    }
    canvas.save();
    canvas.clipRect(plot);
    final grid = Paint()
      ..color = DesktopTheme.graphGrid
      ..strokeWidth = 1;
    for (var x = plot.right - 0.5; x > plot.left; x -= 16) {
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
    }
    for (var y = plot.bottom - 16.5; y > plot.top; y -= 16) {
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    _drawNetworkSeries(canvas, plot, total, scale, DesktopTheme.graphGreen);
    _drawNetworkSeries(canvas, plot, received, scale, DesktopTheme.graphYellow);
    _drawNetworkSeries(canvas, plot, sent, scale, DesktopTheme.graphRed);
    canvas.restore();
  }

  void _drawNetworkSeries(
    Canvas canvas,
    Rect plot,
    List<double> values,
    double scale,
    Color color,
  ) {
    if (values.length < 2) {
      return;
    }
    final path = Path();
    final step = plot.width / math.max(values.length - 1, 1);
    for (var index = 0; index < values.length; index++) {
      final point = Offset(
        plot.left + index * step,
        plot.bottom - (_finitePercent(values[index]) / scale) * plot.height,
      );
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
        ..strokeWidth = 1
        ..isAntiAlias = false,
    );
  }

  double _networkScale(double maximum) => switch (maximum.ceil()) {
    <= 1 => 1,
    2 => 2,
    <= 5 => 5,
    <= 10 => 10,
    <= 25 => 25,
    <= 50 => 50,
    _ => 100,
  };

  double _finitePercent(double value) =>
      value.isFinite ? value.clamp(0.0, 100.0) : 0;

  String _percentLabel(double value) => value == value.roundToDouble()
      ? '${value.toStringAsFixed(0)} %'
      : '${value.toStringAsFixed(1)} %';

  @override
  bool shouldRepaint(_DesktopNetworkGraphPainter oldDelegate) =>
      oldDelegate.received != received ||
      oldDelegate.sent != sent ||
      oldDelegate.labelStyle != labelStyle;
}

class DesktopMeter extends StatelessWidget {
  const DesktopMeter({
    super.key,
    required this.value,
    required this.label,
    this.displayText,
  });

  // Classic meters use pixel-stable LED bars. The available height changes how many bars fit;
  // it must never stretch each bar into a solid, variable-height fill.
  // The native meter bitmap is 33 px wide: two 16 px cells separated by a
  // single black center column. Keeping those dimensions integral prevents the
  // divider from being blurred away at ordinary Windows scale factors.
  static const segmentWidth = 33.0;
  static const centerGap = 1.0;
  static const segmentHeight = 2.0;
  static const segmentGap = 2.0;

  final double? value;
  final String label;
  final String? displayText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: displayText ?? (value == null ? null : '${value!.round()}%'),
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
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  displayText ?? (value == null ? '—' : '${value!.round()}%'),
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
    const labelHeight = 22.0;
    const verticalPadding = 7.0;
    final meterHeight = math.max(
      0.0,
      size.height - labelHeight - verticalPadding * 2,
    );
    final segmentCount = math.max(
      0,
      ((meterHeight + DesktopMeter.segmentGap) /
              (DesktopMeter.segmentHeight + DesktopMeter.segmentGap))
          .floor(),
    );
    if (segmentCount == 0) {
      return;
    }
    final segmentWidth = math.min(
      DesktopMeter.segmentWidth,
      math.max(0.0, size.width - 8),
    );
    final left = (size.width - segmentWidth) / 2;
    final cellWidth = math.max(
      0.0,
      (segmentWidth - DesktopMeter.centerGap) / 2,
    );
    final rightCellLeft = left + cellWidth + DesktopMeter.centerGap;
    final normalized = ((value ?? 0.0).clamp(0.0, 100.0)) / 100.0;
    final litSegments = (normalized * segmentCount).round();
    final litPaint = Paint()
      ..color = DesktopTheme.graphGreen
      ..isAntiAlias = false;
    final unlitPaint = Paint()
      ..color = DesktopTheme.graphGrid
      ..isAntiAlias = false;
    for (var index = 0; index < segmentCount; index++) {
      final bottom = size.height - labelHeight - verticalPadding;
      final top =
          bottom -
          DesktopMeter.segmentHeight -
          index * (DesktopMeter.segmentHeight + DesktopMeter.segmentGap);
      final paint = index < litSegments ? litPaint : unlitPaint;
      canvas.drawRect(
        Rect.fromLTWH(left, top, cellWidth, DesktopMeter.segmentHeight),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rightCellLeft,
          top,
          cellWidth,
          DesktopMeter.segmentHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DesktopMeterPainter oldDelegate) =>
      oldDelegate.value != value;
}
