import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/common/glyphs.dart';
import 'package:serensync/main_app/common/illustrations.dart';

void main() {
  testWidgets('every glyph draws at its size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final glyph in Glyphs.values)
              Glyph(glyph, key: ValueKey(glyph), size: 32),
          ],
        ),
      ),
    );

    for (final glyph in Glyphs.values) {
      expect(tester.getSize(find.byKey(ValueKey(glyph))), const Size(32, 32));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a glyph stays square in a wide slot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(children: [Expanded(child: Glyph(Glyphs.swipe, size: 20))]),
      ),
    );

    final painted = find.descendant(
      of: find.byType(Glyph),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(painted), const Size(20, 20));
  });

  testWidgets('a glyph takes the icon theme by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(size: 40, color: Colors.red),
          child: Center(child: Glyph(Glyphs.sun)),
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(Glyph),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter! as GlyphPainter).color, Colors.red);
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(Glyph),
          matching: find.byType(CustomPaint),
        ),
      ),
      const Size(40, 40),
    );
  });

  testWidgets('every scene draws', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final scene in Scene.values) Illustration(scene, size: 80),
          ],
        ),
      ),
    );

    expect(find.byType(Illustration), findsNWidgets(Scene.values.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the breathing circle holds still when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: BreathingCircle(size: 100)),
        ),
      ),
    );

    // Settles at once because nothing repeats.
    await tester.pumpAndSettle();
    expect(find.byType(BreathingCircle), findsOneWidget);
  });
}
