import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocking/blocking_colors.dart';

/// Whether the app is light, dark, or follows the phone.
enum Appearance { system, light, dark }

/// The palette [appearance] calls for while the phone is [platform].
Palette paletteFor(Appearance appearance, Brightness platform) {
  return switch (appearance) {
    Appearance.light => lightPalette,
    Appearance.dark => darkPalette,
    Appearance.system =>
      platform == Brightness.dark ? darkPalette : lightPalette,
  };
}

/// Keeps the chosen [Appearance] on the device. The block screen runs in its
/// own engine and reads the same key.
class AppearanceStore {
  static const _key = 'settings.appearance';

  /// Falls back to following the phone when nothing readable is stored.
  Future<Appearance> read() async {
    try {
      final name = await SharedPreferencesAsync().getString(_key);
      return Appearance.values.asNameMap()[name] ?? Appearance.system;
    } catch (_) {
      return Appearance.system;
    }
  }

  Future<void> write(Appearance appearance) {
    return SharedPreferencesAsync().setString(_key, appearance.name);
  }
}

/// The current [Appearance], saved whenever it changes.
class AppearanceController extends ValueNotifier<Appearance> {
  AppearanceController({AppearanceStore? store, Appearance? initial})
    : _store = store ?? AppearanceStore(),
      super(initial ?? Appearance.system);

  final AppearanceStore _store;

  Future<void> choose(Appearance appearance) async {
    value = appearance;
    await _store.write(appearance);
  }
}
