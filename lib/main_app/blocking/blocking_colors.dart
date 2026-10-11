import 'package:flutter/material.dart';

/// One set of colours for every screen.
class Palette {
  const Palette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.accent,
    required this.accentSoft,
    required this.inverseAccent,
    required this.rising,
    required this.falling,
    required this.danger,
    required this.onAccent,
    required this.text,
    required this.textMuted,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color outline;
  final Color accent;
  final Color accentSoft;

  /// The accent on the opposite background, as on a snack bar.
  final Color inverseAccent;

  /// More screen time than before.
  final Color rising;

  /// Less screen time than before.
  final Color falling;
  final Color danger;
  final Color onAccent;
  final Color text;
  final Color textMuted;
}

/// Black ink on near-white paper, with one blue accent for what is on.
const lightPalette = Palette(
  brightness: Brightness.light,
  background: Color(0xFFFAFAF8),
  surface: Color(0xFFF1F1EE),
  surfaceRaised: Color(0xFFE7E7E3),
  outline: Color(0xFFE2E2DE),
  accent: Color(0xFF2F5BFF),
  accentSoft: Color(0x1A2F5BFF),
  inverseAccent: Color(0xFF9DB2FF),
  rising: Color(0xFFE2622C),
  falling: Color(0xFF1E9E5A),
  danger: Color(0xFFD63B30),
  onAccent: Color(0xFFFFFFFF),
  text: Color(0xFF161618),
  textMuted: Color(0xFF707075),
);

/// The same layout at night: near-black, soft white ink and a lighter blue.
const darkPalette = Palette(
  brightness: Brightness.dark,
  background: Color(0xFF0B0B0C),
  surface: Color(0xFF18181B),
  surfaceRaised: Color(0xFF242428),
  outline: Color(0xFF27272B),
  accent: Color(0xFF7A95FF),
  accentSoft: Color(0x297A95FF),
  inverseAccent: Color(0xFF2F5BFF),
  rising: Color(0xFFFF8F5E),
  falling: Color(0xFF4CC38A),
  danger: Color(0xFFFF6B60),
  onAccent: Color(0xFF0B0B0C),
  text: Color(0xFFF2F2F3),
  textMuted: Color(0xFF9A9AA0),
);

/// The colours in use right now. Screens read these while they build or
/// paint, so switching palettes takes [applyPalette] followed by a full
/// rebuild, which `refreshAppearance` in `theme.dart` does.
abstract final class BlockingColors {
  static Palette _palette = lightPalette;

  static Palette get palette => _palette;
  static bool get dark => _palette.brightness == Brightness.dark;

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceRaised => _palette.surfaceRaised;
  static Color get outline => _palette.outline;
  static Color get accent => _palette.accent;
  static Color get accentSoft => _palette.accentSoft;
  static Color get inverseAccent => _palette.inverseAccent;
  static Color get rising => _palette.rising;
  static Color get falling => _palette.falling;
  static Color get danger => _palette.danger;
  static Color get onAccent => _palette.onAccent;
  static Color get text => _palette.text;
  static Color get textMuted => _palette.textMuted;
}

/// Switches every colour to [palette]. Returns whether anything changed.
bool applyPalette(Palette palette) {
  if (identical(palette, BlockingColors._palette)) return false;
  BlockingColors._palette = palette;
  return true;
}
