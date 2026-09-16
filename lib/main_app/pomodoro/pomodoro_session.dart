class PomodoroSettings {
  const PomodoroSettings({
    this.focus = const Duration(minutes: 25),
    this.shortBreak = const Duration(minutes: 5),
    this.longBreak = const Duration(minutes: 15),
    this.rounds = 4,
  });

  final Duration focus;
  final Duration shortBreak;
  final Duration longBreak;
  final int rounds;

  PomodoroSettings copyWith({
    Duration? focus,
    Duration? shortBreak,
    Duration? longBreak,
    int? rounds,
  }) {
    return PomodoroSettings(
      focus: focus ?? this.focus,
      shortBreak: shortBreak ?? this.shortBreak,
      longBreak: longBreak ?? this.longBreak,
      rounds: rounds ?? this.rounds,
    );
  }

  Map<String, Object> toJson() => {
    'focus': focus.inMinutes,
    'shortBreak': shortBreak.inMinutes,
    'longBreak': longBreak.inMinutes,
    'rounds': rounds,
  };

  factory PomodoroSettings.fromJson(Map<String, Object?> json) {
    return PomodoroSettings(
      focus: Duration(minutes: json['focus'] as int),
      shortBreak: Duration(minutes: json['shortBreak'] as int),
      longBreak: Duration(minutes: json['longBreak'] as int),
      rounds: json['rounds'] as int,
    );
  }
}

enum PomodoroPhase { focus, shortBreak, longBreak, waiting, finished }

typedef PomodoroState = ({
  PomodoroPhase phase,
  Duration remaining,
  Duration length,
});

/// A running session. Focus and the break after it follow from
/// [focusStartedAt] alone, so every isolate reads the same phase from the
/// clock and only user actions write.
class PomodoroSession {
  const PomodoroSession({
    required this.settings,
    required this.ruleIds,
    required this.round,
    required this.focusStartedAt,
  });

  final PomodoroSettings settings;
  final Set<int> ruleIds;
  final int round;
  final DateTime focusStartedAt;

  bool get isLastRound => round >= settings.rounds;

  Duration get _breakLength =>
      isLastRound ? settings.longBreak : settings.shortBreak;

  DateTime get _focusEnd => focusStartedAt.add(settings.focus);

  DateTime get _breakEnd => _focusEnd.add(_breakLength);

  PomodoroState stateAt(DateTime now) {
    if (now.isBefore(_focusEnd)) {
      return (
        phase: PomodoroPhase.focus,
        remaining: _focusEnd.difference(now),
        length: settings.focus,
      );
    }
    if (now.isBefore(_breakEnd)) {
      return (
        phase: isLastRound ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
        remaining: _breakEnd.difference(now),
        length: _breakLength,
      );
    }
    return (
      phase: isLastRound ? PomodoroPhase.finished : PomodoroPhase.waiting,
      remaining: Duration.zero,
      length: Duration.zero,
    );
  }

  /// When the phase next changes by itself, or null once the session waits
  /// for a tap or is finished.
  DateTime? nextChangeAt(DateTime now) {
    if (now.isBefore(_focusEnd)) return _focusEnd;
    if (now.isBefore(_breakEnd)) return _breakEnd;
    return null;
  }

  PomodoroSession nextRound(DateTime now) {
    return PomodoroSession(
      settings: settings,
      ruleIds: ruleIds,
      round: round + 1,
      focusStartedAt: now,
    );
  }

  Map<String, Object> toJson() => {
    'settings': settings.toJson(),
    'ruleIds': ruleIds.toList(),
    'round': round,
    'focusStartedAt': focusStartedAt.millisecondsSinceEpoch,
  };

  factory PomodoroSession.fromJson(Map<String, Object?> json) {
    return PomodoroSession(
      settings: PomodoroSettings.fromJson(
        json['settings'] as Map<String, Object?>,
      ),
      ruleIds: (json['ruleIds'] as List<Object?>).cast<int>().toSet(),
      round: json['round'] as int,
      focusStartedAt: DateTime.fromMillisecondsSinceEpoch(
        json['focusStartedAt'] as int,
      ),
    );
  }
}
