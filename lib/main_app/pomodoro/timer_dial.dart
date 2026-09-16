import 'dart:math';

import 'package:flutter/material.dart';

import '../blocking/blocking_colors.dart';

const _stroke = 14.0;
const _ticks = 60;

/// A clock-face ring. [fraction] is the arc drawn from twelve o'clock. With
/// [onFractionChanged] the arc end becomes a handle and dragging anywhere on
/// the ring moves it.
class TimerDial extends StatelessWidget {
  const TimerDial({
    super.key,
    required this.fraction,
    required this.color,
    required this.child,
    this.onFractionChanged,
  });

  final double fraction;
  final Color color;
  final Widget child;
  final ValueChanged<double>? onFractionChanged;

  @override
  Widget build(BuildContext context) {
    final onFractionChanged = this.onFractionChanged;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 320.0);
        // Axis drags, not a pan: the innermost axis recognizer wins the
        // arena, so a drag on the ring never scrolls the page behind it.
        void drag(Offset position) => _drag(position, size);
        return GestureDetector(
          onVerticalDragStart: onFractionChanged == null
              ? null
              : (details) => drag(details.localPosition),
          onVerticalDragUpdate: onFractionChanged == null
              ? null
              : (details) => drag(details.localPosition),
          onHorizontalDragStart: onFractionChanged == null
              ? null
              : (details) => drag(details.localPosition),
          onHorizontalDragUpdate: onFractionChanged == null
              ? null
              : (details) => drag(details.localPosition),
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _DialPainter(
                fraction: fraction,
                color: color,
                handle: onFractionChanged != null,
              ),
              child: Center(child: child),
            ),
          ),
        );
      },
    );
  }

  void _drag(Offset position, double size) {
    final center = Offset(size / 2, size / 2);
    final offset = position - center;
    // The middle holds the digits; a drag that starts there is not on the ring.
    if (offset.distance < size * 0.28) return;
    final angle = atan2(offset.dy, offset.dx) + pi / 2;
    onFractionChanged!((angle < 0 ? angle + 2 * pi : angle) / (2 * pi));
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.fraction,
    required this.color,
    required this.handle,
  });

  final double fraction;
  final Color color;
  final bool handle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var tick = 0; tick < _ticks; tick++) {
      final angle = -pi / 2 + 2 * pi * tick / _ticks;
      final major = tick % 5 == 0;
      final outer = radius - _stroke / 2 - 8;
      final inner = outer - (major ? 12 : 6);
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * inner,
        center + Offset(cos(angle), sin(angle)) * outer,
        Paint()
          ..color = major ? BlockingColors.textMuted : BlockingColors.outline
          ..strokeWidth = major ? 2 : 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = BlockingColors.outline,
    );
    final sweep = 2 * pi * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
    if (handle) {
      final angle = -pi / 2 + sweep;
      final end = center + Offset(cos(angle), sin(angle)) * radius;
      canvas.drawCircle(end, _stroke, Paint()..color = Colors.black);
      canvas.drawCircle(end, _stroke * 0.7, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction || old.color != color || old.handle != handle;
}
