import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../blocking/blocking_colors.dart';

const _stroke = 14.0;
const _minutesPerDay = 24 * 60;
const _snap = 15;

/// A day as a ring with midnight at the top. The arc runs clockwise from
/// [start] to [end], both minutes of the day, so a window that crosses
/// midnight bends over the top. Dragging moves whichever end is nearer.
class WindowDial extends StatefulWidget {
  const WindowDial({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    required this.child,
  });

  final int start;
  final int end;
  final void Function(int start, int end) onChanged;
  final Widget child;

  @override
  State<WindowDial> createState() => _WindowDialState();
}

class _WindowDialState extends State<WindowDial> {
  // Which end the current drag moves; null outside the ring.
  bool? _movingStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 300.0);
        // Axis drags, not a pan: the innermost axis recognizer wins the
        // arena, so a drag on the ring never scrolls the page behind it.
        return GestureDetector(
          onVerticalDragStart: (details) => _begin(details.localPosition, size),
          onVerticalDragUpdate: (details) =>
              _update(details.localPosition, size),
          onHorizontalDragStart: (details) =>
              _begin(details.localPosition, size),
          onHorizontalDragUpdate: (details) =>
              _update(details.localPosition, size),
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _WindowPainter(start: widget.start, end: widget.end),
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }

  void _begin(Offset position, double size) {
    final offset = position - Offset(size / 2, size / 2);
    // The middle holds the times; a drag that starts there is not on the ring.
    if (offset.distance < size * 0.28) {
      _movingStart = null;
      return;
    }
    final minute = _minuteAt(offset);
    _movingStart = _apart(minute, widget.start) <= _apart(minute, widget.end);
    _move(minute);
  }

  void _update(Offset position, double size) {
    if (_movingStart == null) return;
    _move(_minuteAt(position - Offset(size / 2, size / 2)));
  }

  void _move(int minute) {
    final start = _movingStart! ? minute : widget.start;
    final end = _movingStart! ? widget.end : minute;
    // A window with no length blocks nothing, so the ends never meet.
    if (start != end) widget.onChanged(start, end);
  }
}

int _minuteAt(Offset offset) {
  final angle = atan2(offset.dy, offset.dx) + pi / 2;
  final turn = (angle < 0 ? angle + 2 * pi : angle) / (2 * pi);
  return (turn * _minutesPerDay / _snap).round() * _snap % _minutesPerDay;
}

int _apart(int a, int b) {
  final difference = (a - b).abs();
  return min(difference, _minutesPerDay - difference);
}

double _angleOf(int minute) => -pi / 2 + 2 * pi * minute / _minutesPerDay;

class _WindowPainter extends CustomPainter {
  const _WindowPainter({required this.start, required this.end});

  final int start;
  final int end;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _stroke;
    final outer = radius - _stroke / 2 - 8;

    for (var hour = 0; hour < 24; hour++) {
      final angle = _angleOf(hour * 60);
      final major = hour % 6 == 0;
      final inner = outer - (major ? 12 : 6);
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        Paint()
          ..color = major ? BlockingColors.textMuted : BlockingColors.outline
          ..strokeWidth = major ? 2 : 1.5
          ..strokeCap = StrokeCap.round,
      );
      if (major) _hourLabel(canvas, hour, center + direction * (inner - 14));
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = BlockingColors.outline,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _angleOf(start),
      2 * pi * ((end - start) % _minutesPerDay) / _minutesPerDay,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = BlockingColors.accent,
    );
    _handle(canvas, center, radius, start, filled: true);
    _handle(canvas, center, radius, end, filled: false);
  }

  void _hourLabel(Canvas canvas, int hour, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$hour',
        style: TextStyle(
          fontFamily: appFont,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: BlockingColors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - painter.size.center(Offset.zero));
  }

  // The start is solid and the end hollow, so the two read apart.
  void _handle(
    Canvas canvas,
    Offset center,
    double radius,
    int minute, {
    required bool filled,
  }) {
    final angle = _angleOf(minute);
    final at = center + Offset(cos(angle), sin(angle)) * radius;
    canvas.drawCircle(at, _stroke, Paint()..color = BlockingColors.background);
    canvas.drawCircle(
      at,
      _stroke * 0.7,
      Paint()
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = BlockingColors.accent,
    );
  }

  @override
  bool shouldRepaint(_WindowPainter old) =>
      old.start != start || old.end != end;
}
