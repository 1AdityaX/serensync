import 'package:flutter/material.dart';

import 'main_app/blocking/blocking_colors.dart';

/// The small muted heading above a group of controls.
const sectionLabel = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: BlockingColors.textMuted,
);

const _pill = StadiumBorder();
const _buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

final _panelShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(20),
  side: const BorderSide(color: BlockingColors.outline),
);

const _scheme = ColorScheme.dark(
  primary: BlockingColors.accent,
  onPrimary: BlockingColors.onAccent,
  secondaryContainer: Color(0x2E78A6FF),
  onSecondaryContainer: BlockingColors.accent,
  surface: BlockingColors.background,
  surfaceContainer: BlockingColors.surface,
  surfaceContainerHigh: BlockingColors.surfaceRaised,
  surfaceContainerHighest: BlockingColors.surfaceRaised,
  onSurface: Colors.white,
  onSurfaceVariant: BlockingColors.textMuted,
  outline: BlockingColors.outline,
  error: BlockingColors.rising,
);

// Text styles start from the default text theme so they keep its font family.
final _text = ThemeData(colorScheme: _scheme).textTheme;

final _buttonText = _text.labelLarge!.copyWith(
  fontSize: 16,
  fontWeight: FontWeight.w700,
);

/// One look for every screen, so no screen has to restate it.
final appTheme = ThemeData(
  colorScheme: _scheme,
  scaffoldBackgroundColor: BlockingColors.background,
  appBarTheme: AppBarTheme(
    backgroundColor: BlockingColors.background,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleTextStyle: _text.titleLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: BlockingColors.background,
    surfaceTintColor: Colors.transparent,
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: Colors.white,
    textColor: Colors.white,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    hintStyle: TextStyle(color: BlockingColors.textMuted),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: BlockingColors.surface,
    shape: _panelShape,
    titleTextStyle: _text.titleLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    contentTextStyle: _text.bodyMedium!.copyWith(
      fontSize: 15,
      height: 1.45,
      color: Colors.white,
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: BlockingColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: BlockingColors.outline),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: BlockingColors.surfaceRaised,
    shape: _panelShape,
  ),
  dividerTheme: const DividerThemeData(color: BlockingColors.outline),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: BlockingColors.accent,
      foregroundColor: BlockingColors.onAccent,
      disabledBackgroundColor: BlockingColors.surfaceRaised,
      disabledForegroundColor: Colors.white38,
      shape: _pill,
      padding: _buttonPadding,
      textStyle: _buttonText,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: BlockingColors.outline),
      shape: _pill,
      padding: _buttonPadding,
      textStyle: _buttonText,
    ),
  ),
);
