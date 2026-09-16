import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'pomodoro_session.dart';

final _plugin = FlutterLocalNotificationsPlugin();
var _initialised = false;

/// Sounds once when a phase ends. The foreground notification is silent by
/// design, so this is a separate, high-importance one.
Future<void> showPhaseAlert(
  PomodoroPhase phase,
  PomodoroSession session,
) async {
  final copy = switch (phase) {
    PomodoroPhase.shortBreak => (
      title: 'Break time',
      text: 'Focus done. ${session.settings.shortBreak.inMinutes} minutes off.',
    ),
    PomodoroPhase.longBreak => (
      title: 'Long break',
      text: 'Focus done. ${session.settings.longBreak.inMinutes} minutes off.',
    ),
    PomodoroPhase.waiting => (
      title: 'Break over',
      text: 'Open SerenSync to start round ${session.round + 1}.',
    ),
    PomodoroPhase.finished => (
      title: 'Session complete',
      text: '${session.settings.rounds} rounds of focus done.',
    ),
    PomodoroPhase.focus => null,
  };
  if (copy == null) return;

  if (!_initialised) {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialised = true;
  }
  await _plugin.show(
    id: 1,
    title: copy.title,
    body: copy.text,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'pomodoro',
        'Focus timer',
        channelDescription: 'When focus and breaks end.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
