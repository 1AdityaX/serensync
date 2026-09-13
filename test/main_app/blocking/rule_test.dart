import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/rule.dart';

const _packageName = 'com.example.focus';
const _noUsage = AppUsage(foregroundTime: Duration.zero, launches: 0);

void main() {
  test('formats weekday selections readably', () {
    expect(weekdaySummary({DateTime.wednesday}), 'Wed');
    expect(
      weekdaySummary({
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      }),
      'Mon–Fri',
    );
    expect(
      weekdaySummary({
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
        DateTime.sunday,
      }),
      'Mon, Wed, Fri, Sun',
    );
    expect(
      weekdaySummary({
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      }),
      'Mon–Sun',
    );
  });

  test('formats every limit summary readably', () {
    expect(ruleTime(6 * 60 + 5), '06:05');
    expect(ruleDuration(const Duration(minutes: 90)), '1h 30m');
    expect(
      triggerSummary(
        const Schedule(
          weekdays: {DateTime.monday, DateTime.tuesday, DateTime.wednesday},
          startMinute: 22 * 60,
          endMinute: 6 * 60,
        ),
      ),
      'Blocked Mon–Wed 22:00–06:00',
    );
    expect(
      triggerSummary(
        const Schedule(
          weekdays: {DateTime.saturday, DateTime.sunday},
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          allDay: true,
        ),
      ),
      'Blocked Sat–Sun all day',
    );
    expect(
      triggerSummary(
        const Schedule(
          weekdays: {DateTime.monday},
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          additionalTimes: [
            ScheduleTime(startMinute: 14 * 60, endMinute: 15 * 60),
          ],
        ),
      ),
      'Blocked Mon · 2 time windows',
    );
    expect(
      triggerSummary(const UsageQuota(Duration(minutes: 30))),
      'Blocked after 30m a day',
    );
    expect(triggerSummary(const LaunchQuota(5)), 'Blocked after 5 opens a day');
  });

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

    test('blocks during any configured time window', () {
      const rule = BlockRule(
        id: 1,
        name: 'Split shift',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.monday},
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          additionalTimes: [
            ScheduleTime(startMinute: 14 * 60, endMinute: 16 * 60),
          ],
        ),
        enabled: true,
      );

      expect(_decisionFor(rule, DateTime(2024, 1, 1, 9, 30)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 12)), isA<Allow>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 15)), isA<Block>());
    });

    test('all-day schedules ignore their retained time windows', () {
      const rule = BlockRule(
        id: 1,
        name: 'Monday',
        packages: {_packageName},
        trigger: Schedule(
          weekdays: {DateTime.monday},
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          allDay: true,
        ),
        enabled: true,
      );

      expect(_decisionFor(rule, DateTime(2024, 1, 1)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 1, 23, 59)), isA<Block>());
      expect(_decisionFor(rule, DateTime(2024, 1, 2, 9)), isA<Allow>());
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

  group('parseAddress', () {
    test('normalises address-bar text to a host and url', () {
      final address = parseAddress('https://www.Instagram.com/Reels?tab=1')!;

      expect(address.host, 'instagram.com');
      expect(address.url, 'instagram.com/reels?tab=1');
    });

    test('keeps subdomains, drops ports and credentials, decodes the url', () {
      expect(parseAddress('m.youtube.com:443/shorts')!.host, 'm.youtube.com');
      expect(parseAddress('user@example.org/x')!.host, 'example.org');
      expect(
        parseAddress('google.com/search?q=online%20casino')!.url,
        'google.com/search?q=online casino',
      );
      expect(
        parseAddress('google.com/search?q=online+casino')!.url,
        'google.com/search?q=online casino',
      );
      expect(parseAddress('example.com/%zz')!.url, 'example.com/%zz');
    });

    test('rejects text that is not an address', () {
      expect(parseAddress('Search or type URL'), isNull);
      expect(parseAddress('play games now'), isNull);
      expect(parseAddress('reddit'), isNull);
      expect(parseAddress('http://'), isNull);
      expect(parseAddress(''), isNull);
    });
  });

  group('web decisions', () {
    const rule = BlockRule(
      id: 1,
      name: 'Focus',
      packages: {},
      websites: {'instagram.com'},
      keywords: {'casino'},
      trigger: Schedule(
        weekdays: {DateTime.monday},
        startMinute: 9 * 60,
        endMinute: 10 * 60,
      ),
      enabled: true,
    );
    final inSchedule = DateTime(2024, 1, 1, 9, 30);
    final outsideSchedule = DateTime(2024, 1, 1, 12);

    test('blocks a website and its subdomains during the schedule', () {
      expect(_webDecision(rule, 'instagram.com', inSchedule), isA<Block>());
      expect(
        _webDecision(rule, 'https://www.instagram.com/reels', inSchedule),
        isA<Block>(),
      );
      expect(_webDecision(rule, 'm.instagram.com', inSchedule), isA<Block>());
      expect(_webDecision(rule, 'notinstagram.com', inSchedule), isA<Allow>());
      expect(
        _webDecision(rule, 'instagram.com', outsideSchedule),
        isA<Allow>(),
      );
    });

    test('blocks a keyword anywhere in the url', () {
      const phrase = BlockRule(
        id: 6,
        name: 'Phrase',
        packages: {},
        keywords: {'online casino'},
        trigger: LaunchQuota(1),
        enabled: true,
      );

      expect(
        _webDecision(rule, 'google.com/search?q=best+casino', inSchedule),
        isA<Block>(),
      );
      expect(
        _webDecision(phrase, 'bing.com/search?q=online+casino', inSchedule),
        isA<Block>(),
      );
      expect(_webDecision(rule, 'bestcasino.net', inSchedule), isA<Block>());
      expect(_webDecision(rule, 'example.com', inSchedule), isA<Allow>());
    });

    test('usage and launch limits block their web targets all day', () {
      const usage = BlockRule(
        id: 2,
        name: 'Limit',
        packages: {},
        websites: {'reddit.com'},
        trigger: UsageQuota(Duration(hours: 5)),
        enabled: true,
      );
      const launches = BlockRule(
        id: 3,
        name: 'Opens',
        packages: {},
        keywords: {'shorts'},
        trigger: LaunchQuota(99),
        enabled: true,
      );

      expect(
        _webDecision(usage, 'reddit.com/r/all', outsideSchedule),
        isA<Block>(),
      );
      expect(
        _webDecision(launches, 'youtube.com/shorts/x', outsideSchedule),
        isA<Block>(),
      );
    });

    test('disabled rules and app-only rules allow every page', () {
      const disabled = BlockRule(
        id: 4,
        name: 'Off',
        packages: {},
        websites: {'instagram.com'},
        trigger: UsageQuota(Duration.zero),
        enabled: false,
      );
      const appsOnly = BlockRule(
        id: 5,
        name: 'Apps',
        packages: {'com.instagram.android'},
        trigger: UsageQuota(Duration.zero),
        enabled: true,
      );

      expect(_webDecision(disabled, 'instagram.com', inSchedule), isA<Allow>());
      expect(_webDecision(appsOnly, 'instagram.com', inSchedule), isA<Allow>());
    });
  });
}

Decision _webDecision(BlockRule rule, String address, DateTime now) {
  return decideWeb(rules: [rule], address: parseAddress(address)!, now: now);
}

Decision _decisionFor(
  BlockRule rule,
  DateTime now, {
  AppUsage usage = _noUsage,
}) {
  return decide(rules: [rule], package: _packageName, now: now, usage: usage);
}
