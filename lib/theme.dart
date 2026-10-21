import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main_app/blocking/blocking_colors.dart';

/// The neutral typeface bundled with the app.
const appFont = 'Inter';

/// The small muted heading above a group of controls.
TextStyle get sectionLabel => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: BlockingColors.textMuted,
);

/// [milliseconds] of motion, or none when the system asks for less.
Duration motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Status and navigation bar icons that contrast with the background.
SystemUiOverlayStyle get systemBars {
  final dark = BlockingColors.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: BlockingColors.background,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
  );
}

const _pill = StadiumBorder();
const _buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

final _panelShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(24),
);

ColorScheme get _scheme => ColorScheme(
  brightness: BlockingColors.palette.brightness,
  onError: BlockingColors.background,
  primary: BlockingColors.accent,
  onPrimary: BlockingColors.onAccent,
  primaryContainer: BlockingColors.accentSoft,
  onPrimaryContainer: BlockingColors.accent,
  secondary: BlockingColors.accent,
  onSecondary: BlockingColors.onAccent,
  secondaryContainer: BlockingColors.accentSoft,
  onSecondaryContainer: BlockingColors.accent,
  surface: BlockingColors.background,
  surfaceContainerLowest: BlockingColors.background,
  surfaceContainerLow: BlockingColors.surface,
  surfaceContainer: BlockingColors.surface,
  surfaceContainerHigh: BlockingColors.surfaceRaised,
  surfaceContainerHighest: BlockingColors.surfaceRaised,
  onSurface: BlockingColors.text,
  onSurfaceVariant: BlockingColors.textMuted,
  outline: BlockingColors.outline,
  outlineVariant: BlockingColors.outline,
  error: BlockingColors.danger,
  inverseSurface: BlockingColors.text,
  onInverseSurface: BlockingColors.background,
  inversePrimary: BlockingColors.inverseAccent,
);

// Text styles start from the default text theme so they pick up the font.
TextTheme get _text => ThemeData(colorScheme: _scheme, fontFamily: appFont)
    .textTheme
    .apply(bodyColor: BlockingColors.text, displayColor: BlockingColors.text);

TextStyle get _buttonText =>
    _text.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

final _themes = <Palette, ThemeData>{};

/// One look for every screen, built once per palette.
ThemeData get appTheme => _themes[BlockingColors.palette] ??= _buildTheme();

ThemeData _buildTheme() => ThemeData(
  colorScheme: _scheme,
  fontFamily: appFont,
  textTheme: _text,
  scaffoldBackgroundColor: BlockingColors.background,
  splashFactory: InkSparkle.splashFactory,
  appBarTheme: AppBarTheme(
    backgroundColor: BlockingColors.background,
    surfaceTintColor: Colors.transparent,
    foregroundColor: BlockingColors.text,
    systemOverlayStyle: systemBars,
    centerTitle: false,
    titleTextStyle: _text.titleLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: BlockingColors.background,
    surfaceTintColor: Colors.transparent,
    indicatorColor: BlockingColors.surface,
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    height: 68,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: 24,
        color: states.contains(WidgetState.selected)
            ? BlockingColors.text
            : BlockingColors.textMuted,
      ),
    ),
    labelTextStyle: WidgetStateProperty.all(
      _text.labelMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: BlockingColors.text,
      ),
    ),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: BlockingColors.text,
    textColor: BlockingColors.text,
  ),
  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(color: BlockingColors.textMuted),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: BlockingColors.background,
    shape: _panelShape,
    titleTextStyle: _text.titleLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: _text.bodyMedium!.copyWith(fontSize: 15, height: 1.5),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: BlockingColors.background,
    dragHandleColor: BlockingColors.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: BlockingColors.background,
    elevation: 6,
    shadowColor: const Color(0x33000000),
    shape: _panelShape,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: BlockingColors.text,
    contentTextStyle: _text.bodyMedium!.copyWith(
      color: BlockingColors.background,
      fontWeight: FontWeight.w500,
    ),
    actionTextColor: BlockingColors.inverseAccent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? BlockingColors.background
          : states.contains(WidgetState.selected)
          ? BlockingColors.onAccent
          : BlockingColors.background,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? BlockingColors.accent.withValues(
              alpha: states.contains(WidgetState.disabled) ? 0.4 : 1,
            )
          : BlockingColors.surfaceRaised,
    ),
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: BlockingColors.text,
    foregroundColor: BlockingColors.background,
    elevation: 0,
    highlightElevation: 0,
    shape: const CircleBorder(),
    extendedTextStyle: _buttonText,
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: BlockingColors.text,
  ),
  dividerTheme: DividerThemeData(color: BlockingColors.outline, space: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: BlockingColors.text,
      foregroundColor: BlockingColors.background,
      disabledBackgroundColor: BlockingColors.surface,
      disabledForegroundColor: BlockingColors.textMuted,
      shape: _pill,
      padding: _buttonPadding,
      textStyle: _buttonText,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: BlockingColors.text,
      side: BorderSide(color: BlockingColors.surfaceRaised),
      shape: _pill,
      padding: _buttonPadding,
      textStyle: _buttonText,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: BlockingColors.accent,
      textStyle: _text.labelLarge!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

/// Switches to [palette] and redraws every screen in place. Colours are read
/// while widgets build and paint, so every element rebuilds and every render
/// object repaints; state such as the open route or a half-filled form stays.
/// Returns whether the palette changed. Must not run during a build.
bool showPalette(Palette palette) {
  if (!applyPalette(palette)) return false;
  void redraw(Element element) {
    element.markNeedsBuild();
    if (element is RenderObjectElement) element.renderObject.markNeedsPaint();
    element.visitChildren(redraw);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(redraw);
  return true;
}
