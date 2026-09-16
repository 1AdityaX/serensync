import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../blocking/rule.dart';

/// What the user must satisfy to unlock. Every chosen condition must hold.
enum UnlockCondition { pin, charger, timer, followSchedules }

enum StrictLock { rules, settings, uninstall, recents, newApps }

class StrictMode {
  const StrictMode({
    required this.conditions,
    required this.locks,
    required this.activatedAt,
    this.until,
    this.cooldown,
    this.unlockRequestedAt,
    this.pin,
  });

  final Set<UnlockCondition> conditions;
  final Set<StrictLock> locks;
  final DateTime activatedAt;
  final DateTime? until;
  final Duration? cooldown;
  final DateTime? unlockRequestedAt;
  final PinHash? pin;

  StrictMode withUnlockRequest(DateTime? requestedAt) {
    return StrictMode(
      conditions: conditions,
      locks: locks,
      activatedAt: activatedAt,
      until: until,
      cooldown: cooldown,
      unlockRequestedAt: requestedAt,
      pin: pin,
    );
  }

  Map<String, Object?> toJson() => {
    'conditions': [for (final condition in conditions) condition.name],
    'locks': [for (final lock in locks) lock.name],
    'activatedAt': activatedAt.millisecondsSinceEpoch,
    'until': until?.millisecondsSinceEpoch,
    'cooldownMinutes': cooldown?.inMinutes,
    'unlockRequestedAt': unlockRequestedAt?.millisecondsSinceEpoch,
    'pin': pin?.toJson(),
  };

  factory StrictMode.fromJson(Map<String, Object?> json) {
    return StrictMode(
      conditions: {
        for (final name in json['conditions'] as List<Object?>)
          UnlockCondition.values.byName(name as String),
      },
      locks: {
        for (final name in json['locks'] as List<Object?>)
          StrictLock.values.byName(name as String),
      },
      activatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['activatedAt'] as int,
      ),
      until: _time(json['until']),
      cooldown: switch (json['cooldownMinutes']) {
        final int minutes => Duration(minutes: minutes),
        _ => null,
      },
      unlockRequestedAt: _time(json['unlockRequestedAt']),
      pin: switch (json['pin']) {
        final Map<String, Object?> pin => PinHash.fromJson(pin),
        _ => null,
      },
    );
  }
}

DateTime? _time(Object? milliseconds) {
  return milliseconds is int
      ? DateTime.fromMillisecondsSinceEpoch(milliseconds)
      : null;
}

/// A salted SHA-256 of the PIN; the PIN itself is never stored.
class PinHash {
  const PinHash({required this.salt, required this.hash});

  factory PinHash.create(String pin, Random random) {
    final salt = base64Encode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    return PinHash(salt: salt, hash: _digest(salt, pin));
  }

  final String salt;
  final String hash;

  bool matches(String pin) => _digest(salt, pin) == hash;

  Map<String, Object?> toJson() => {'salt': salt, 'hash': hash};

  factory PinHash.fromJson(Map<String, Object?> json) {
    return PinHash(salt: json['salt'] as String, hash: json['hash'] as String);
  }

  static String _digest(String salt, String pin) {
    return sha256.convert(utf8.encode('$salt$pin')).toString();
  }
}

/// Conditions that still stand between the user and unlocking.
Set<UnlockCondition> unmetConditions(
  StrictMode strict, {
  required DateTime now,
  required bool charging,
  required bool pinEntered,
  required bool schedulesRunning,
}) {
  return {
    for (final condition in strict.conditions)
      if (switch (condition) {
        UnlockCondition.pin => !pinEntered,
        UnlockCondition.charger => !charging,
        UnlockCondition.timer => now.isBefore(strict.until!),
        UnlockCondition.followSchedules => schedulesRunning,
      })
        condition,
  };
}

/// A timer-only mode ends on its own; every other mode lasts until the user
/// unlocks and the record is removed.
bool strictModeEnded(StrictMode strict, DateTime now) {
  return strict.conditions.length == 1 &&
      strict.conditions.contains(UnlockCondition.timer) &&
      !now.isBefore(strict.until!);
}

/// Whether the screen guards apply. The rules lock holds for as long as the
/// record exists; a mode that follows the schedules guards screens only while
/// one runs.
bool strictGuardsApply(
  StrictMode strict, {
  required DateTime now,
  required bool schedulesRunning,
}) {
  if (strictModeEnded(strict, now)) return false;
  return schedulesRunning ||
      !strict.conditions.contains(UnlockCondition.followSchedules);
}

/// The timer, a cooldown, and the new-apps lock follow the phone's clock, and
/// the device admin can be removed from Settings, so each of them keeps the
/// Settings app blocked.
Set<StrictLock> effectiveLocks(
  Set<StrictLock> locks, {
  required Set<UnlockCondition> conditions,
  required Duration? cooldown,
}) {
  final needsSettings =
      conditions.contains(UnlockCondition.timer) ||
      cooldown != null ||
      locks.contains(StrictLock.uninstall) ||
      locks.contains(StrictLock.newApps);
  return needsSettings ? {...locks, StrictLock.settings} : locks;
}

/// Null without a cooldown; otherwise the wait still left, zero once served.
Duration? cooldownRemaining(StrictMode strict, DateTime now) {
  final cooldown = strict.cooldown;
  final requestedAt = strict.unlockRequestedAt;
  if (cooldown == null) return null;
  if (requestedAt == null) return cooldown;
  final remaining = cooldown - now.difference(requestedAt);
  return remaining.isNegative ? Duration.zero : remaining;
}

bool schedulesRunning(List<BlockRule> rules, DateTime now) {
  return rules.any(
    (rule) =>
        rule.enabled &&
        rule.trigger is Schedule &&
        scheduleActive(rule.trigger as Schedule, now),
  );
}

/// Whether [after] blocks everything [before] blocks, so the change can be
/// saved while rules are locked.
bool tightens(BlockRule before, BlockRule after) {
  if (!after.packages.containsAll(before.packages) ||
      !after.websites.containsAll(before.websites) ||
      !after.keywords.containsAll(before.keywords) ||
      (before.enabled && !after.enabled)) {
    return false;
  }
  return switch ((before.trigger, after.trigger)) {
    (final Schedule before, final Schedule after) => _covers(after, before),
    (final UsageQuota before, final UsageQuota after) =>
      after.limit <= before.limit,
    (final LaunchQuota before, final LaunchQuota after) =>
      after.limit <= before.limit,
    _ => false,
  };
}

// Schedules resolve to minutes, so one reference week checked minute by
// minute is exact.
bool _covers(Schedule after, Schedule before) {
  for (var day = 0; day < 7; day++) {
    for (var minute = 0; minute < 24 * 60; minute++) {
      final at = DateTime(2024, 1, 1 + day, minute ~/ 60, minute % 60);
      if (scheduleActive(before, at) && !scheduleActive(after, at)) {
        return false;
      }
    }
  }
  return true;
}

const _emergencyAlphabet = 'abcdefghijkmnpqrstuvwxyz23456789';
const emergencyTextLength = 120;

/// Text the user must retype for a repeat emergency unlock.
String emergencyText(Random random) {
  return String.fromCharCodes(
    List<int>.generate(
      emergencyTextLength,
      (_) => _emergencyAlphabet.codeUnitAt(
        random.nextInt(_emergencyAlphabet.length),
      ),
    ),
  );
}
