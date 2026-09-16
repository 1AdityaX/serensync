import 'dart:math';

import 'package:flutter/material.dart';

import '../blocking/blocking_colors.dart';

/// A day as 24 hour cells, filled left to right. Partial hours fill part of
/// a cell so the amount can animate smoothly.
class HourGrid extends StatelessWidget {
  const HourGrid({super.key, required this.hours, required this.color});

  final double hours;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: CustomPaint(painter: _HourGridPainter(hours, color)),
    );
  }
}

class _HourGridPainter extends CustomPainter {
  const _HourGridPainter(this.hours, this.color);

  final double hours;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 6;
    const rows = 4;
    const gap = 0.3;
    final cell = min(
      size.width / (columns + (columns - 1) * gap),
      size.height / (rows + (rows - 1) * gap),
    );
    final step = cell * (1 + gap);
    final left = (size.width - (step * columns - cell * gap)) / 2;
    final top = (size.height - (step * rows - cell * gap)) / 2;
    final radius = Radius.circular(cell * 0.22);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = BlockingColors.outline;
    final fill = Paint()..color = color;

    for (var hour = 0; hour < columns * rows; hour++) {
      final rect = Rect.fromLTWH(
        left + (hour % columns) * step,
        top + (hour ~/ columns) * step,
        cell,
        cell,
      );
      final rrect = RRect.fromRectAndRadius(rect, radius);
      final amount = (hours - hour).clamp(0.0, 1.0);
      if (amount == 1) {
        canvas.drawRRect(rrect, fill);
        continue;
      }
      canvas.drawRRect(rrect, outline);
      if (amount > 0) {
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, cell * amount, cell),
          fill,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_HourGridPainter old) =>
      old.hours != hours || old.color != color;
}

/// A day as a timeline with one spike per pickup. Most spikes are short,
/// like most sessions.
class PickupTimeline extends StatelessWidget {
  const PickupTimeline({super.key, required this.pickups});

  final int pickups;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.8,
      child: CustomPaint(painter: _PickupTimelinePainter(pickups)),
    );
  }
}

class _PickupTimelinePainter extends CustomPainter {
  const _PickupTimelinePainter(this.pickups);

  final int pickups;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(pickups);
    final baseline = size.height * 0.72;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = BlockingColors.outline
        ..strokeWidth = 1.5,
    );

    final spike = Paint()
      ..color = BlockingColors.rising
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final positions = List<double>.generate(
      pickups,
      (_) => 0.01 + random.nextDouble() * 0.98,
    )..sort();
    for (final position in positions) {
      final roll = random.nextDouble();
      final height = roll < 0.69
          ? 0.16
          : roll < 0.9
          ? 0.34
          : 0.62;
      final x = position * size.width;
      canvas.drawLine(
        Offset(x, baseline),
        Offset(x, baseline - size.height * height),
        spike,
      );
    }
  }

  @override
  bool shouldRepaint(_PickupTimelinePainter old) => old.pickups != pickups;
}

enum PhoneScene { usage, overlay, notification, battery, browser }

/// A phone frame showing the one thing a permission touches.
class PhoneIllustration extends StatelessWidget {
  const PhoneIllustration({super.key, required this.scene});

  final PhoneScene scene;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: AspectRatio(
        aspectRatio: 0.56,
        child: CustomPaint(painter: _PhonePainter(scene)),
      ),
    );
  }
}

class _PhonePainter extends CustomPainter {
  const _PhonePainter(this.scene);

  final PhoneScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, radius),
      Paint()..color = BlockingColors.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = BlockingColors.outline,
    );

    final screen = frame.deflate(size.width * 0.1);
    switch (scene) {
      case PhoneScene.usage:
        _bars(canvas, screen);
      case PhoneScene.overlay:
        _lines(canvas, screen, from: 0.1, count: 5);
        _card(canvas, screen);
      case PhoneScene.notification:
        _pill(canvas, screen, dot: BlockingColors.accent);
        _lines(canvas, screen, from: 0.3, count: 4);
      case PhoneScene.battery:
        _battery(canvas, screen);
      case PhoneScene.browser:
        _pill(canvas, screen, dot: null, outline: BlockingColors.accent);
        _lines(canvas, screen, from: 0.3, count: 4);
    }
  }

  void _bars(Canvas canvas, Rect screen) {
    const widths = [0.85, 0.55, 0.3];
    final height = screen.height * 0.07;
    for (var index = 0; index < widths.length; index++) {
      final top = screen.top + screen.height * (0.3 + index * 0.14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(screen.left, top, screen.width * widths[index], height),
          Radius.circular(height / 2),
        ),
        Paint()
          ..color = BlockingColors.rising.withValues(alpha: 1 - index * 0.3),
      );
    }
  }

  void _lines(
    Canvas canvas,
    Rect screen, {
    required double from,
    required int count,
  }) {
    final paint = Paint()
      ..color = BlockingColors.outline
      ..strokeWidth = screen.height * 0.03
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < count; index++) {
      final y = screen.top + screen.height * (from + index * 0.1);
      final width = screen.width * (index.isEven ? 0.9 : 0.6);
      canvas.drawLine(
        Offset(screen.left, y),
        Offset(screen.left + width, y),
        paint,
      );
    }
  }

  void _card(Canvas canvas, Rect screen) {
    final card = Rect.fromCenter(
      center: screen.center,
      width: screen.width * 0.92,
      height: screen.height * 0.4,
    );
    final rrect = RRect.fromRectAndRadius(
      card,
      Radius.circular(screen.width * 0.08),
    );
    canvas.drawRRect(rrect, Paint()..color = BlockingColors.surfaceRaised);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = BlockingColors.accent,
    );
    final inner = card.deflate(card.width * 0.12);
    canvas.drawLine(
      Offset(inner.left, inner.top + inner.height * 0.15),
      Offset(inner.left + inner.width * 0.6, inner.top + inner.height * 0.15),
      Paint()
        ..color = Colors.white
        ..strokeWidth = inner.height * 0.08
        ..strokeCap = StrokeCap.round,
    );
    final button = Rect.fromLTWH(
      inner.left,
      inner.bottom - inner.height * 0.22,
      inner.width,
      inner.height * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(button, Radius.circular(button.height / 2)),
      Paint()..color = BlockingColors.accent,
    );
  }

  void _pill(Canvas canvas, Rect screen, {Color? dot, Color? outline}) {
    final pill = Rect.fromLTWH(
      screen.left,
      screen.top + screen.height * 0.08,
      screen.width,
      screen.height * 0.1,
    );
    final rrect = RRect.fromRectAndRadius(
      pill,
      Radius.circular(pill.height / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = BlockingColors.surfaceRaised);
    if (outline != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = outline,
      );
    }
    final inset = pill.height * 0.3;
    var textStart = pill.left + inset;
    if (dot != null) {
      final dotRadius = pill.height * 0.2;
      canvas.drawCircle(
        Offset(pill.left + inset + dotRadius, pill.center.dy),
        dotRadius,
        Paint()..color = dot,
      );
      textStart += dotRadius * 2 + inset;
    }
    canvas.drawLine(
      Offset(textStart, pill.center.dy),
      Offset(pill.right - pill.width * 0.3, pill.center.dy),
      Paint()
        ..color = BlockingColors.textMuted
        ..strokeWidth = pill.height * 0.16
        ..strokeCap = StrokeCap.round,
    );
  }

  void _battery(Canvas canvas, Rect screen) {
    final body = Rect.fromCenter(
      center: screen.center,
      width: screen.width * 0.56,
      height: screen.height * 0.16,
    );
    final radius = Radius.circular(body.height * 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = BlockingColors.textMuted,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.right + 2,
          body.center.dy - body.height * 0.2,
          body.width * 0.06,
          body.height * 0.4,
        ),
        Radius.circular(body.height * 0.08),
      ),
      Paint()..color = BlockingColors.textMuted,
    );
    final charge = body.deflate(body.height * 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          charge.left,
          charge.top,
          charge.width * 0.72,
          charge.height,
        ),
        Radius.circular(charge.height * 0.15),
      ),
      Paint()..color = BlockingColors.accent,
    );
  }

  @override
  bool shouldRepaint(_PhonePainter old) => old.scene != scene;
}
