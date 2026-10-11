import 'dart:math';

import 'package:flutter/material.dart';

import '../blocking/blocking_colors.dart';

/// Small scenes that say at a glance what words would otherwise explain.
enum Scene {
  /// A sprout in a pot: nothing set up yet, room to grow.
  sprout,

  /// A shield with a tick: blocks are working right now.
  shield,

  /// The sun on the horizon: blocks are ready, nothing to block yet.
  sunrise,

  /// A ring filling up: a focus session is running.
  focus,

  /// A padlock: strict mode holds the blocks.
  lock,
}

class Illustration extends StatelessWidget {
  const Illustration(
    this.scene, {
    super.key,
    this.size = 120,
    this.fraction = 0.7,
  });

  final Scene scene;
  final double size;

  /// How full the [Scene.focus] ring is.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _ScenePainter(scene, fraction),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.scene, this.fraction);

  final Scene scene;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final backdrop = Paint()..color = BlockingColors.surface;
    canvas.drawCircle(const Offset(50, 50), 48, backdrop);
    final ink = Paint()
      ..color = BlockingColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accent = Paint()..color = BlockingColors.accent;
    final paper = Paint()..color = BlockingColors.background;
    switch (scene) {
      case Scene.sprout:
        _sprout(canvas, ink, accent, paper);
      case Scene.shield:
        _shield(canvas, ink, accent);
      case Scene.sunrise:
        _sunrise(canvas, ink, accent);
      case Scene.focus:
        _focus(canvas, ink, accent);
      case Scene.lock:
        _lock(canvas, ink, accent, paper);
    }
    canvas.restore();
  }

  void _sprout(Canvas c, Paint ink, Paint accent, Paint paper) {
    final pot = Path()
      ..moveTo(33, 62)
      ..lineTo(67, 62)
      ..lineTo(62.5, 84)
      ..quadraticBezierTo(62, 86, 60, 86)
      ..lineTo(40, 86)
      ..quadraticBezierTo(38, 86, 37.5, 84)
      ..close();
    c.drawPath(pot, accent);
    c.drawRRect(
      RRect.fromLTRBR(29, 56, 71, 64, const Radius.circular(3)),
      accent,
    );
    c.drawLine(const Offset(50, 56), const Offset(50, 36), ink);
    final left = Path()
      ..moveTo(50, 46)
      ..cubicTo(40, 47, 31, 42, 29, 31)
      ..cubicTo(40, 30, 48, 36, 50, 46)
      ..close();
    final right = Path()
      ..moveTo(50, 38)
      ..cubicTo(51, 27, 60, 19, 72, 19)
      ..cubicTo(72, 31, 62, 38, 50, 38)
      ..close();
    for (final leaf in [left, right]) {
      c.drawPath(leaf, paper);
      c.drawPath(leaf, ink);
    }
  }

  void _shield(Canvas c, Paint ink, Paint accent) {
    final shield = Path()
      ..moveTo(50, 18)
      ..lineTo(74, 27)
      ..lineTo(74, 47)
      ..cubicTo(74, 63, 64, 76, 50, 82)
      ..cubicTo(36, 76, 26, 63, 26, 47)
      ..lineTo(26, 27)
      ..close();
    c.drawPath(shield, accent);
    final tick = Paint()
      ..color = BlockingColors.onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(39, 49)
        ..lineTo(47, 57)
        ..lineTo(62, 41),
      tick,
    );
    _sparkle(c, ink, const Offset(17, 30), 4);
    _sparkle(c, ink, const Offset(84, 66), 3);
  }

  void _sunrise(Canvas c, Paint ink, Paint accent) {
    c.save();
    c.clipRect(const Rect.fromLTRB(0, 0, 100, 62));
    c.drawCircle(const Offset(50, 62), 19, accent);
    c.restore();
    for (var i = 0; i < 5; i++) {
      final a = pi + pi * (i + 1) / 6;
      c.drawLine(
        Offset(50 + cos(a) * 26, 62 + sin(a) * 26),
        Offset(50 + cos(a) * 32, 62 + sin(a) * 32),
        ink,
      );
    }
    c.drawLine(const Offset(14, 62), const Offset(86, 62), ink);
    c.drawLine(const Offset(28, 72), const Offset(46, 72), ink);
    c.drawLine(const Offset(54, 80), const Offset(72, 80), ink);
  }

  void _focus(Canvas c, Paint ink, Paint accent) {
    final track = Paint()
      ..color = BlockingColors.surfaceRaised
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    c.drawCircle(const Offset(50, 50), 28, track);
    final arc = Paint()
      ..color = BlockingColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    c.drawArc(
      Rect.fromCircle(center: const Offset(50, 50), radius: 28),
      -pi / 2,
      2 * pi * fraction.clamp(0.02, 1),
      false,
      arc,
    );
    c.drawCircle(const Offset(50, 50), 3.5, Paint()..color = ink.color);
  }

  void _lock(Canvas c, Paint ink, Paint accent, Paint paper) {
    c.drawPath(
      Path()
        ..moveTo(37, 48)
        ..lineTo(37, 38)
        ..arcToPoint(const Offset(63, 38), radius: const Radius.circular(13))
        ..lineTo(63, 48),
      ink..strokeWidth = 5,
    );
    c.drawRRect(
      RRect.fromLTRBR(29, 46, 71, 80, const Radius.circular(8)),
      accent,
    );
    c.drawCircle(const Offset(50, 60), 4.5, paper);
    c.drawRRect(
      RRect.fromLTRBR(48, 61, 52, 70, const Radius.circular(2)),
      paper,
    );
  }

  void _sparkle(Canvas c, Paint ink, Offset at, double r) {
    final thin = Paint()
      ..color = ink.color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    c.drawLine(at - Offset(0, r), at + Offset(0, r), thin);
    c.drawLine(at - Offset(r, 0), at + Offset(r, 0), thin);
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.fraction != fraction;
}

/// Two soft circles that slowly grow and shrink, to breathe along with.
class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key, this.size = 200, this.child});

  final double size;
  final Widget? child;

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  // Four seconds in, four seconds out.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 0.6;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_breath.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              _disc(size * (0.72 + 0.28 * t), 0.08),
              _disc(size * (0.5 + 0.18 * t), 0.14),
              _disc(size * 0.34, 1),
              ?child,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _disc(double diameter, double alpha) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BlockingColors.accent.withValues(alpha: alpha),
      ),
    );
  }
}
