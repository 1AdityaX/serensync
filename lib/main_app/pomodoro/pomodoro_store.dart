import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pomodoro_session.dart';

/// Reads storage on every call so the app and the blocking service see the
/// same session without sharing memory.
class PomodoroStore {
  static const _sessionKey = 'pomodoro.session';
  static const _settingsKey = 'pomodoro.settings';

  Future<PomodoroSession?> readSession() async {
    final json = await SharedPreferencesAsync().getString(_sessionKey);
    if (json == null) return null;
    return PomodoroSession.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  Future<void> writeSession(PomodoroSession? session) {
    final preferences = SharedPreferencesAsync();
    if (session == null) return preferences.remove(_sessionKey);
    return preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<PomodoroSettings> readSettings() async {
    final json = await SharedPreferencesAsync().getString(_settingsKey);
    if (json == null) return const PomodoroSettings();
    return PomodoroSettings.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  Future<void> writeSettings(PomodoroSettings settings) {
    return SharedPreferencesAsync().setString(
      _settingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
