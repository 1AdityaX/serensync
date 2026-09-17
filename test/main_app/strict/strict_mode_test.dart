import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/strict/strict_mode.dart';

void main() {
  final activatedAt = DateTime(2026, 9, 16, 9);
  final now = DateTime(2026, 9, 16, 10);

  final pin = PinHash.create('2468', Random(1));

  StrictMode strict({
    DateTime? until,
    Duration? cooldown,
    DateTime? unlockRequestedAt,
  }) {
    return StrictMode(
      locks: const {},
      activatedAt: activatedAt,
      until: until,
      pin: until == null ? pin : null,
      cooldown: cooldown,
      unlockRequestedAt: unlockRequestedAt,
    );
  }

  group('ending', () {
    test('a timed mode ends by itself, a pin mode never does', () {
      final timed = strict(until: now.add(const Duration(minutes: 1)));

      expect(strictModeEnded(timed, now), isFalse);
      expect(
        strictModeEnded(timed, now.add(const Duration(minutes: 1))),
        isTrue,
      );
      expect(strictModeEnded(strict(), now), isFalse);
    });

    test('clock-bound choices and the admin keep Settings locked', () {
      Set<StrictLock> locks(
        Set<StrictLock> chosen, {
        bool timed = false,
        Duration? cooldown,
      }) {
        return effectiveLocks(chosen, timed: timed, cooldown: cooldown);
      }

      expect(locks({}), isEmpty);
      expect(locks({}, timed: true), {StrictLock.settings});
      expect(locks({}, cooldown: const Duration(minutes: 10)), {
        StrictLock.settings,
      });
      expect(locks({StrictLock.uninstall}), {
        StrictLock.uninstall,
        StrictLock.settings,
      });
      expect(locks({StrictLock.newApps}), {
        StrictLock.newApps,
        StrictLock.settings,
      });
      expect(locks({StrictLock.recents}), {StrictLock.recents});
    });

    test('cooldown counts from the unlock request', () {
      expect(cooldownRemaining(strict(), now), isNull);
      final waiting = strict(cooldown: const Duration(minutes: 10));
      expect(cooldownRemaining(waiting, now), const Duration(minutes: 10));

      final requested = waiting.withUnlockRequest(now);
      expect(
        cooldownRemaining(requested, now.add(const Duration(minutes: 4))),
        const Duration(minutes: 6),
      );
      expect(
        cooldownRemaining(requested, now.add(const Duration(minutes: 11))),
        Duration.zero,
      );
      expect(
        cooldownRemaining(requested.withUnlockRequest(null), now),
        const Duration(minutes: 10),
      );
    });
  });

  group('tightens', () {
    const base = BlockRule(
      id: 1,
      name: 'Social',
      packages: {'a', 'b'},
      websites: {'x.com'},
      keywords: {'k'},
      trigger: Schedule(
        weekdays: {DateTime.monday, DateTime.tuesday},
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      ),
      enabled: true,
    );

    BlockRule variant({
      Set<String>? packages,
      Set<String>? websites,
      Set<String>? keywords,
      Trigger? trigger,
      bool? enabled,
    }) {
      return BlockRule(
        id: 1,
        name: 'Social',
        packages: packages ?? base.packages,
        websites: websites ?? base.websites,
        keywords: keywords ?? base.keywords,
        trigger: trigger ?? base.trigger,
        enabled: enabled ?? base.enabled,
      );
    }

    test('adding targets tightens, removing loosens', () {
      expect(tightens(base, base), isTrue);
      expect(tightens(base, variant(packages: {'a', 'b', 'c'})), isTrue);
      expect(tightens(base, variant(packages: {'a'})), isFalse);
      expect(tightens(base, variant(websites: {})), isFalse);
      expect(tightens(base, variant(keywords: {'k', 'j'})), isTrue);
    });

    test('pausing loosens, resuming tightens', () {
      expect(tightens(base, variant(enabled: false)), isFalse);
      expect(tightens(variant(enabled: false), base), isTrue);
    });

    test('schedules must cover every blocked minute', () {
      expect(
        tightens(
          base,
          variant(
            trigger: const Schedule(
              weekdays: {DateTime.monday, DateTime.tuesday, DateTime.friday},
              startMinute: 8 * 60,
              endMinute: 18 * 60,
            ),
          ),
        ),
        isTrue,
      );
      expect(
        tightens(
          base,
          variant(
            trigger: const Schedule(
              weekdays: {DateTime.monday, DateTime.tuesday},
              startMinute: 9 * 60,
              endMinute: 16 * 60,
            ),
          ),
        ),
        isFalse,
      );
      expect(
        tightens(
          base,
          variant(
            trigger: const Schedule(
              weekdays: {DateTime.monday},
              startMinute: 9 * 60,
              endMinute: 17 * 60,
            ),
          ),
        ),
        isFalse,
      );
      expect(
        tightens(
          base,
          variant(
            trigger: const Schedule(
              weekdays: {DateTime.monday, DateTime.tuesday},
              startMinute: 0,
              endMinute: 0,
              allDay: true,
            ),
          ),
        ),
        isTrue,
      );
    });

    test('an overnight window is covered by an all-day pair', () {
      const night = BlockRule(
        id: 2,
        name: 'Night',
        packages: {'a'},
        trigger: Schedule(
          weekdays: {DateTime.friday},
          startMinute: 22 * 60,
          endMinute: 6 * 60,
        ),
        enabled: true,
      );
      const weekend = BlockRule(
        id: 2,
        name: 'Night',
        packages: {'a'},
        trigger: Schedule(
          weekdays: {DateTime.friday, DateTime.saturday},
          startMinute: 0,
          endMinute: 0,
          allDay: true,
        ),
        enabled: true,
      );
      const fridayOnly = BlockRule(
        id: 2,
        name: 'Night',
        packages: {'a'},
        trigger: Schedule(
          weekdays: {DateTime.friday},
          startMinute: 0,
          endMinute: 0,
          allDay: true,
        ),
        enabled: true,
      );

      expect(tightens(night, weekend), isTrue);
      expect(tightens(night, fridayOnly), isFalse);
    });

    test('limits may only shrink and never change kind', () {
      const usage = BlockRule(
        id: 3,
        name: 'Usage',
        packages: {'a'},
        trigger: UsageQuota(Duration(minutes: 30)),
        enabled: true,
      );
      const launches = BlockRule(
        id: 3,
        name: 'Usage',
        packages: {'a'},
        trigger: LaunchQuota(3),
        enabled: true,
      );

      expect(
        tightens(
          usage,
          const BlockRule(
            id: 3,
            name: 'Usage',
            packages: {'a'},
            trigger: UsageQuota(Duration(minutes: 20)),
            enabled: true,
          ),
        ),
        isTrue,
      );
      expect(
        tightens(
          usage,
          const BlockRule(
            id: 3,
            name: 'Usage',
            packages: {'a'},
            trigger: UsageQuota(Duration(minutes: 31)),
            enabled: true,
          ),
        ),
        isFalse,
      );
      expect(
        tightens(
          launches,
          const BlockRule(
            id: 3,
            name: 'Usage',
            packages: {'a'},
            trigger: LaunchQuota(2),
            enabled: true,
          ),
        ),
        isTrue,
      );
      expect(tightens(usage, launches), isFalse);
    });
  });

  test('pin hashes verify without storing the pin', () {
    final pin = PinHash.create('2468', Random(1));
    final other = PinHash.create('2468', Random(2));

    expect(pin.matches('2468'), isTrue);
    expect(pin.matches('2469'), isFalse);
    expect(pin.salt, isNot(other.salt));
    expect(pin.hash, isNot(other.hash));
    expect(pin.toJson().values, isNot(contains('2468')));
  });

  test('round-trips through json', () {
    final original = StrictMode(
      locks: {StrictLock.settings, StrictLock.newApps},
      activatedAt: activatedAt,
      cooldown: const Duration(minutes: 15),
      unlockRequestedAt: now,
      pin: PinHash.create('1234', Random(3)),
    );
    final timed = strict(until: now);

    final restored = StrictMode.fromJson(original.toJson());
    final restoredTimed = StrictMode.fromJson(timed.toJson());

    expect(restored.locks, original.locks);
    expect(restored.activatedAt, activatedAt);
    expect(restored.until, isNull);
    expect(restored.cooldown, const Duration(minutes: 15));
    expect(restored.unlockRequestedAt, now);
    expect(restored.pin!.matches('1234'), isTrue);
    expect(restoredTimed.until, now);
    expect(restoredTimed.cooldown, isNull);
    expect(restoredTimed.pin, isNull);
  });

  test('records from before timer and pin were exclusive are dropped', () {
    final timed = strict(until: now).toJson();
    final both = {...timed, 'pin': PinHash.create('1234', Random(3)).toJson()};
    final neither = {...timed, 'until': null};

    expect(strictModeFromJson(timed)!.until, now);
    expect(strictModeFromJson(strict().toJson())!.pin, isNotNull);
    expect(strictModeFromJson(both), isNull);
    expect(strictModeFromJson(neither), isNull);
  });

  test('emergency text is long and typeable', () {
    final text = emergencyText(Random(4));

    expect(text, hasLength(emergencyTextLength));
    expect(text, matches(RegExp(r'^[a-km-z2-9]+$')));
    expect(text, isNot(emergencyText(Random(5))));
  });
}
