import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_session.dart';

void main() {
  final start = DateTime(2026, 9, 16, 9);
  const settings = PomodoroSettings(
    focus: Duration(minutes: 25),
    shortBreak: Duration(minutes: 5),
    longBreak: Duration(minutes: 15),
    rounds: 2,
  );
  final session = PomodoroSession(
    settings: settings,
    ruleIds: const {1, 2},
    round: 1,
    focusStartedAt: start,
  );

  test('focus runs for its length, then the break follows by itself', () {
    final focus = session.stateAt(start.add(const Duration(minutes: 10)));
    expect(focus.phase, PomodoroPhase.focus);
    expect(focus.remaining, const Duration(minutes: 15));
    expect(focus.length, const Duration(minutes: 25));

    final rest = session.stateAt(start.add(const Duration(minutes: 27)));
    expect(rest.phase, PomodoroPhase.shortBreak);
    expect(rest.remaining, const Duration(minutes: 3));
    expect(rest.length, const Duration(minutes: 5));
  });

  test('after a short break the next round waits for a tap', () {
    final waiting = session.stateAt(start.add(const Duration(hours: 3)));
    expect(waiting.phase, PomodoroPhase.waiting);
    expect(waiting.remaining, Duration.zero);

    final next = session.nextRound(start.add(const Duration(minutes: 40)));
    expect(next.round, 2);
    expect(next.ruleIds, {1, 2});
    expect(
      next.stateAt(start.add(const Duration(minutes: 41))).phase,
      PomodoroPhase.focus,
    );
  });

  test('the last round takes the long break and then finishes', () {
    final last = session.nextRound(start);
    expect(last.isLastRound, isTrue);
    expect(
      last.stateAt(start.add(const Duration(minutes: 30))).phase,
      PomodoroPhase.longBreak,
    );
    expect(
      last.stateAt(start.add(const Duration(minutes: 30))).remaining,
      const Duration(minutes: 10),
    );
    expect(
      last.stateAt(start.add(const Duration(minutes: 40))).phase,
      PomodoroPhase.finished,
    );
  });

  test('next change is the end of focus, then of the break, then nothing', () {
    expect(session.nextChangeAt(start), start.add(const Duration(minutes: 25)));
    expect(
      session.nextChangeAt(start.add(const Duration(minutes: 26))),
      start.add(const Duration(minutes: 30)),
    );
    expect(session.nextChangeAt(start.add(const Duration(hours: 1))), isNull);
  });

  test('a session survives a round trip through json', () {
    final restored = PomodoroSession.fromJson(session.toJson());
    expect(restored.round, 1);
    expect(restored.ruleIds, {1, 2});
    expect(restored.focusStartedAt, start);
    expect(restored.settings.focus, const Duration(minutes: 25));
    expect(restored.settings.rounds, 2);
  });
}
