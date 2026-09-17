import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'strict_mode.dart';

/// Reads storage on every call so the app and the blocking service see the
/// same strict mode without sharing memory.
class StrictModeStore {
  static const _modeKey = 'strict.mode';
  static const _emergencyKey = 'strict.emergencyUsed';

  Future<StrictMode?> read() async {
    final json = await SharedPreferencesAsync().getString(_modeKey);
    if (json == null) return null;
    final strict = strictModeFromJson(jsonDecode(json) as Map<String, Object?>);
    if (strict == null) await write(null);
    return strict;
  }

  Future<void> write(StrictMode? strict) {
    final preferences = SharedPreferencesAsync();
    if (strict == null) return preferences.remove(_modeKey);
    return preferences.setString(_modeKey, jsonEncode(strict.toJson()));
  }

  /// The one easy emergency unlock is spent for good, across activations.
  Future<bool> get emergencyUsed async =>
      await SharedPreferencesAsync().getBool(_emergencyKey) ?? false;

  Future<void> markEmergencyUsed() =>
      SharedPreferencesAsync().setBool(_emergencyKey, true);
}
