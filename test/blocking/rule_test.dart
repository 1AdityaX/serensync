import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/blocking/rule.dart';

const _packageName = 'com.example.focus';
const _noUsage = AppUsage(foregroundTime: Duration.zero, launches: 0);

void main() {
  group('schedule', () {
    test('uses an inclusive start and exclusive end', () {
      const rule = BlockRule(
        id: 1,
        name: 'Work hours',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.monday},
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        ),
        enabled: true,
      );

      expect(_decisionFor(rule, DateTime(2024, 1, 1, 8, 59)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 9)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 9, 59)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 10)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 2, 9)), isA<Allow>());
    });

    test('overnight window blocks on both sides of midnight', () {
      const rule = BlockRule(
        id: 1,
        name: 'Night',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.friday},
          startMinute: 22 * 60,
          endMinute: 6 * 60,
        ),
        enabled: true,
      );

      expect(_decisionFor(rule, DateTime(2024, 1, 5, 22)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 6, 2)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 6, 6)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 6, 12)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 6, 23)), isA<Allow>());
    });

    test('early hours use the weekday on which the window started', () {
      const sundayRule = BlockRule(
        id: 1,
        name: 'Sunday night',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.sunday},
          startMinute: 22 * 60,
          endMinute: 6 * 60,
        ),
        enabled: true,
      );
      const mondayRule = BlockRule(
        id: 2,
        name: 'Monday night',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.monday},
          startMinute: 22 * 60,
          endMinute: 6 * 60,
        ),
        enabled: true,
      );
      final mondayMorning = DateTime(2024, 1, 8, 2);

      expect(_decisionFor(sundayRule, mondayMorning), isA<Block>());
      expect(_decisionFor(mondayRule, mondayMorning), isA<Allow>());
    });

    test('zero-length window never blocks', () {
      const rule = BlockRule(
        id: 1,
        name: 'No window',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.monday},
          startMinute: 9 * 60,
          endMinute: 9 * 60,
        ),
        enabled: true,
      );

      expect(_decisionFor(rule, DateTime(2024, 1, 1, 8, 59)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 9)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 23, 59)), isA<Allow>());
    });
  });

  test('usage quota blocks at and above the limit', () {
    const rule = BlockRule(
      id: 1,
      name: 'One hour',
      packages: {_packageName},
      trigger: UsageQuota(Duration(hours: 1)),
      enabled: true,
    );

    expect(
      _decisionFor(
        rule,
        DateTime(2024),
        usage: const AppUsage(
          foregroundTime: Duration(minutes: 59),
          launches: 0,
        ),
      ),
      isA<Allow>(),
    );
    expect(
      _decisionFor(
        rule,
        DateTime(2024),
        usage: const AppUsage(foregroundTime: Duration(hours: 1), launches: 0),
      ),
      isA<Block>(),
    );
    expect(
      _decisionFor(
        rule,
        DateTime(2024),
        usage: const AppUsage(
          foregroundTime: Duration(minutes: 61),
          launches: 0,
        ),
      ),
      isA<Block>(),
    );
  });

  test('launch quota blocks at and above the limit', () {
    const rule = BlockRule(
      id: 1,
      name: 'Three launches',
      packages: {_packageName},
      trigger: LaunchQuota(3),
      enabled: true,
    );

    expect(
      _decisionFor(
        rule,
        DateTime(2024),
        usage: const AppUsage(foregroundTime: Duration.zero, launches: 2),
      ),
      isA<Allow>(),
    );
    expect(
      _decisionFor(
        rule,
        DateTime(2024),
        usage: const AppUsage(foregroundTime: Duration.zero, launches: 3),
      ),
      isA<Block>(),
    );
    expect(
      _decisionFor(
        rule,
        DateTime(2024),
        usage: const AppUsage(foregroundTime: Duration.zero, launches: 4),
      ),
      isA<Block>(),
    );
  });

  test('disabled rule never blocks', () {
    const rule = BlockRule(
      id: 1,
      name: 'Disabled',
      packages: {_packageName},
      trigger: LaunchQuota(0),
      enabled: false,
    );

    expect(_decisionFor(rule, DateTime(2024)), isA<Allow>());
  });

  test('rule for another package never blocks', () {
    const rule = BlockRule(
      id: 1,
      name: 'Other app',
      packages: {'com.example.other'},
      trigger: LaunchQuota(0),
      enabled: true,
    );

    expect(_decisionFor(rule, DateTime(2024)), isA<Allow>());
  });

  test('empty rules allow', () {
    final decision = decide(
      rules: const [],
      package: _packageName,
      now: DateTime(2024),
      usage: _noUsage,
    );

    expect(decision, isA<Allow>());
  });

  test('first blocking rule wins', () {
    const allowing = BlockRule(
      id: 1,
      name: 'Below limit',
      packages: {_packageName},
      trigger: LaunchQuota(1),
      enabled: true,
    );
    const firstBlocking = BlockRule(
      id: 2,
      name: 'First block',
      packages: {_packageName},
      trigger: UsageQuota(Duration.zero),
      enabled: true,
    );
    const laterBlocking = BlockRule(
      id: 3,
      name: 'Later block',
      packages: {_packageName},
      trigger: LaunchQuota(0),
      enabled: true,
    );

    final decision = decide(
      rules: const [allowing, firstBlocking, laterBlocking],
      package: _packageName,
      now: DateTime(2024),
      usage: _noUsage,
    );

    expect(decision, isA<Block>());
    expect((decision as Block).rule.id, 2);
  });
}

Decision _decisionFor(
  BlockRule rule,
  DateTime now, {
  AppUsage usage = _noUsage,
}) {
  return decide(rules: [rule], package: _packageName, now: now, usage: usage);
}
