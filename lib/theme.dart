import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main_app/blocking/blocking_colors.dart';

/// The neutral typeface bundled with the app.
const appFont = 'Inter';

/// The small muted heading above a group of controls.
const sectionLabel = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: BlockingColors.textMuted,
);

/// Dark status and navigation bar icons on the light background.
const systemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: BlockingColors.background,
  systemNavigationBarIconBrightness: Brightness.dark,
);

const _pill = StadiumBorder();
const _buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

final _panelShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(24),
);

const _scheme = ColorScheme.light(
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
  inversePrimary: Color(0xFF9DB2FF),
);

// Text styles start from the default text theme so they pick up the font.
final _text = ThemeData(colorScheme: _scheme, fontFamily: appFont).textTheme
    .apply(bodyColor: BlockingColors.text, displayColor: BlockingColors.text);

final _buttonText = _text.labelLarge!.copyWith(
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

/// One look for every screen, so no screen has to restate it.
final appTheme = ThemeData(
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
  listTileTheme: const ListTileThemeData(
    iconColor: BlockingColors.text,
    textColor: BlockingColors.text,
  ),
  inputDecorationTheme: const InputDecorationTheme(
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
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: BlockingColors.background,
    dragHandleColor: BlockingColors.surfaceRaised,
    shape: RoundedRectangleBorder(
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
    actionTextColor: const Color(0xFF9DB2FF),
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
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: BlockingColors.text,
  ),
  dividerTheme: const DividerThemeData(color: BlockingColors.outline, space: 1),
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
      side: const BorderSide(color: BlockingColors.surfaceRaised),
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
