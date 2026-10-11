import 'dart:math';

import 'package:flutter/material.dart';

/// SerenSync's own icon set. Every glyph is drawn on a 24 × 24 grid with one
/// stroke weight and rounded ends, so they read as one family.
enum Glyphs {
  sun,
  timer,
  block,
  shield,
  insights,
  settings,
  clock,
  hourglass,
  launch,
  apps,
  globe,
  search,
  moon,
  briefcase,
  phone,
  camera,
  lock,
  key,
  bell,
  layers,
  battery,
  home,
  plus,
  check,
  close,
  chevronLeft,
  chevronRight,
  more,
  arrowUp,
  arrowDown,
  alert,
  swipe,
  contrast,
}

/// Draws a [Glyphs] icon, sized and coloured by the surrounding [IconTheme]
/// unless told otherwise.
class Glyph extends StatelessWidget {
  const Glyph(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final Glyphs glyph;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = this.size ?? theme.size ?? 24;
    final color = this.color ?? theme.color ?? Colors.black;
    // Kept square and centred whatever space the parent offers.
    final painted = Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: GlyphPainter(glyph, color)),
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: painted);
    return Semantics(label: label, image: true, child: painted);
  }
}

class GlyphPainter extends CustomPainter {
  const GlyphPainter(this.glyph, this.color);

  final Glyphs glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    _draw(glyph, canvas, stroke, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

void _line(Canvas c, Paint p, double x1, double y1, double x2, double y2) =>
    c.drawLine(Offset(x1, y1), Offset(x2, y2), p);

void _circle(Canvas c, Paint p, double x, double y, double r) =>
    c.drawCircle(Offset(x, y), r, p);

void _rrect(
  Canvas c,
  Paint p,
  double l,
  double t,
  double r,
  double b,
  double radius,
) => c.drawRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)), p);

void _draw(Glyphs glyph, Canvas c, Paint s, Paint f) {
  switch (glyph) {
    case Glyphs.sun:
      _circle(c, s, 12, 12, 4);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        _line(
          c,
          s,
          12 + cos(a) * 7.2,
          12 + sin(a) * 7.2,
          12 + cos(a) * 9.4,
          12 + sin(a) * 9.4,
        );
      }
    case Glyphs.timer:
      _circle(c, s, 12, 13.5, 7.8);
      _line(c, s, 9.5, 2.8, 14.5, 2.8);
      _line(c, s, 12, 2.8, 12, 5.7);
      _line(c, s, 12, 13.5, 12, 9.5);
      _line(c, s, 18.4, 6.6, 19.6, 5.4);
    case Glyphs.block:
      _circle(c, s, 12, 12, 8.6);
      _line(c, s, 6, 18, 18, 6);
    case Glyphs.shield:
      c.drawPath(
        Path()
          ..moveTo(12, 2.8)
          ..lineTo(19.2, 5.8)
          ..lineTo(19.2, 11.4)
          ..cubicTo(19.2, 15.9, 16.2, 19.4, 12, 21.2)
          ..cubicTo(7.8, 19.4, 4.8, 15.9, 4.8, 11.4)
          ..lineTo(4.8, 5.8)
          ..close(),
        s,
      );
      _circle(c, f, 12, 10.6, 1.7);
      _line(c, s, 12, 11.5, 12, 14.8);
    case Glyphs.insights:
      final bars = Paint()
        ..color = s.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      _line(c, bars, 6, 19, 6, 14);
      _line(c, bars, 12, 19, 12, 9);
      _line(c, bars, 18, 19, 18, 5);
    case Glyphs.settings:
      _line(c, s, 4, 8, 6.6, 8);
      _circle(c, s, 9, 8, 2.4);
      _line(c, s, 11.4, 8, 20, 8);
      _line(c, s, 4, 16, 12.6, 16);
      _circle(c, s, 15, 16, 2.4);
      _line(c, s, 17.4, 16, 20, 16);
    case Glyphs.clock:
      _circle(c, s, 12, 12, 8.6);
      _line(c, s, 12, 12, 12, 7.4);
      _line(c, s, 12, 12, 15.2, 14);
    case Glyphs.hourglass:
      _line(c, s, 6.5, 3, 17.5, 3);
      _line(c, s, 6.5, 21, 17.5, 21);
      c.drawPath(
        Path()
          ..moveTo(8, 3)
          ..cubicTo(8, 8, 11, 9.5, 11, 12)
          ..cubicTo(11, 14.5, 8, 16, 8, 21)
          ..moveTo(16, 3)
          ..cubicTo(16, 8, 13, 9.5, 13, 12)
          ..cubicTo(13, 14.5, 16, 16, 16, 21),
        s,
      );
      c.drawPath(
        Path()
          ..moveTo(12, 16.2)
          ..lineTo(14.8, 20)
          ..lineTo(9.2, 20)
          ..close(),
        f,
      );
    case Glyphs.launch:
      _rrect(c, s, 4, 8, 16, 20, 3);
      _line(c, s, 11, 13, 19.5, 4.5);
      _line(c, s, 14, 4.5, 19.5, 4.5);
      _line(c, s, 19.5, 4.5, 19.5, 10);
    case Glyphs.apps:
      _rrect(c, s, 4, 4, 10.6, 10.6, 2.4);
      _rrect(c, s, 13.4, 4, 20, 10.6, 2.4);
      _rrect(c, s, 4, 13.4, 10.6, 20, 2.4);
      _rrect(c, s, 13.4, 13.4, 20, 20, 2.4);
    case Glyphs.globe:
      _circle(c, s, 12, 12, 8.6);
      c.drawOval(
        Rect.fromCenter(center: const Offset(12, 12), width: 8, height: 17.2),
        s,
      );
      _line(c, s, 3.6, 12, 20.4, 12);
    case Glyphs.search:
      _circle(c, s, 10.5, 10.5, 6);
      _line(c, s, 15, 15, 20, 20);
    case Glyphs.moon:
      c.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(11.5, 12.5), radius: 8.2),
          ),
          Path()..addOval(
            Rect.fromCircle(center: const Offset(16.5, 7.5), radius: 6.8),
          ),
        ),
        s,
      );
    case Glyphs.briefcase:
      _rrect(c, s, 3.5, 7.5, 20.5, 19.5, 2.6);
      c.drawPath(
        Path()
          ..moveTo(9, 7.5)
          ..lineTo(9, 5.6)
          ..quadraticBezierTo(9, 4.4, 10.2, 4.4)
          ..lineTo(13.8, 4.4)
          ..quadraticBezierTo(15, 4.4, 15, 5.6)
          ..lineTo(15, 7.5),
        s,
      );
      _line(c, s, 3.5, 12.8, 20.5, 12.8);
    case Glyphs.phone:
      c.drawPath(
        Path()
          ..moveTo(8.4, 3.8)
          ..lineTo(10.2, 8.2)
          ..lineTo(8.3, 9.8)
          ..cubicTo(9.3, 12.2, 11.8, 14.7, 14.2, 15.7)
          ..lineTo(15.8, 13.8)
          ..lineTo(20.2, 15.6)
          ..lineTo(20.2, 17.8)
          ..cubicTo(20.2, 19.2, 19.2, 20.2, 17.8, 20.2)
          ..cubicTo(10.2, 20.2, 3.8, 13.8, 3.8, 6.2)
          ..cubicTo(3.8, 4.8, 4.8, 3.8, 6.2, 3.8)
          ..close(),
        s,
      );
    case Glyphs.camera:
      c.drawPath(
        Path()
          ..moveTo(3.5, 9.5)
          ..quadraticBezierTo(3.5, 7.2, 5.8, 7.2)
          ..lineTo(7.8, 7.2)
          ..lineTo(9.4, 4.8)
          ..lineTo(14.6, 4.8)
          ..lineTo(16.2, 7.2)
          ..lineTo(18.2, 7.2)
          ..quadraticBezierTo(20.5, 7.2, 20.5, 9.5)
          ..lineTo(20.5, 17.2)
          ..quadraticBezierTo(20.5, 19.5, 18.2, 19.5)
          ..lineTo(5.8, 19.5)
          ..quadraticBezierTo(3.5, 19.5, 3.5, 17.2)
          ..close(),
        s,
      );
      _circle(c, s, 12, 13, 3.4);
    case Glyphs.lock:
      _rrect(c, s, 5.2, 10.4, 18.8, 20.4, 2.6);
      c.drawPath(
        Path()
          ..moveTo(8.4, 10.4)
          ..lineTo(8.4, 7.6)
          ..arcToPoint(
            const Offset(15.6, 7.6),
            radius: const Radius.circular(3.6),
          )
          ..lineTo(15.6, 10.4),
        s,
      );
      _circle(c, f, 12, 15.4, 1.4);
    case Glyphs.key:
      _circle(c, s, 7.6, 12, 3.8);
      _line(c, s, 11.4, 12, 20.5, 12);
      _line(c, s, 16.8, 12, 16.8, 15);
      _line(c, s, 19.8, 12, 19.8, 14.4);
    case Glyphs.bell:
      c.drawPath(
        Path()
          ..moveTo(6, 16.8)
          ..lineTo(6, 11)
          ..cubicTo(6, 7.4, 8.6, 4.8, 12, 4.8)
          ..cubicTo(15.4, 4.8, 18, 7.4, 18, 11)
          ..lineTo(18, 16.8)
          ..lineTo(19.6, 18.2)
          ..lineTo(4.4, 18.2)
          ..close(),
        s,
      );
      _line(c, s, 10.4, 21, 13.6, 21);
    case Glyphs.layers:
      Path diamond(double y) => Path()
        ..moveTo(12, y - 4.6)
        ..lineTo(20.4, y)
        ..lineTo(12, y + 4.6)
        ..lineTo(3.6, y)
        ..close();
      c.drawPath(diamond(9), s);
      c.drawPath(
        Path()
          ..moveTo(3.6, 14.4)
          ..lineTo(12, 19)
          ..lineTo(20.4, 14.4),
        s,
      );
    case Glyphs.battery:
      _rrect(c, s, 7.2, 4.6, 16.8, 21, 2.4);
      _line(c, s, 10.4, 2.6, 13.6, 2.6);
      c.drawPath(
        Path()
          ..moveTo(12.8, 8.6)
          ..lineTo(10, 13.2)
          ..lineTo(14, 13.2)
          ..lineTo(11.2, 17.6),
        s,
      );
    case Glyphs.home:
      c.drawPath(
        Path()
          ..moveTo(4, 10.6)
          ..lineTo(12, 4)
          ..lineTo(20, 10.6)
          ..moveTo(6.2, 9)
          ..lineTo(6.2, 19.4)
          ..lineTo(17.8, 19.4)
          ..lineTo(17.8, 9),
        s,
      );
      _line(c, s, 10.4, 19.4, 10.4, 15);
      _line(c, s, 10.4, 15, 13.6, 15);
      _line(c, s, 13.6, 15, 13.6, 19.4);
    case Glyphs.plus:
      _line(c, s, 12, 5, 12, 19);
      _line(c, s, 5, 12, 19, 12);
    case Glyphs.check:
      c.drawPath(
        Path()
          ..moveTo(5, 12.6)
          ..lineTo(9.8, 17.2)
          ..lineTo(19, 7.2),
        s,
      );
    case Glyphs.close:
      _line(c, s, 6, 6, 18, 18);
      _line(c, s, 18, 6, 6, 18);
    case Glyphs.chevronLeft:
      c.drawPath(
        Path()
          ..moveTo(14.5, 5.5)
          ..lineTo(8, 12)
          ..lineTo(14.5, 18.5),
        s,
      );
    case Glyphs.chevronRight:
      c.drawPath(
        Path()
          ..moveTo(9.5, 5.5)
          ..lineTo(16, 12)
          ..lineTo(9.5, 18.5),
        s,
      );
    case Glyphs.more:
      _circle(c, f, 5.5, 12, 1.7);
      _circle(c, f, 12, 12, 1.7);
      _circle(c, f, 18.5, 12, 1.7);
    case Glyphs.arrowUp:
      _line(c, s, 12, 19, 12, 5);
      c.drawPath(
        Path()
          ..moveTo(6.5, 10.5)
          ..lineTo(12, 5)
          ..lineTo(17.5, 10.5),
        s,
      );
    case Glyphs.arrowDown:
      _line(c, s, 12, 5, 12, 19);
      c.drawPath(
        Path()
          ..moveTo(6.5, 13.5)
          ..lineTo(12, 19)
          ..lineTo(17.5, 13.5),
        s,
      );
    case Glyphs.alert:
      _circle(c, s, 12, 12, 8.6);
      _line(c, s, 12, 7.6, 12, 12.8);
      _circle(c, f, 12, 16.2, 1.2);
    case Glyphs.contrast:
      _circle(c, s, 12, 12, 8.6);
      c.drawPath(
        Path()
          ..moveTo(12, 3.4)
          ..arcToPoint(
            const Offset(12, 20.6),
            radius: const Radius.circular(8.6),
          )
          ..close(),
        f,
      );
    case Glyphs.swipe:
      c.drawPath(
        Path()
          ..moveTo(11, 6.5)
          ..lineTo(5.5, 12)
          ..lineTo(11, 17.5)
          ..moveTo(18.5, 6.5)
          ..lineTo(13, 12)
          ..lineTo(18.5, 17.5),
        s,
      );
  }
}
