sealed class Trigger {
  const Trigger();
}

class Schedule extends Trigger {
  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;

  const Schedule({
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
  });
}

class UsageQuota extends Trigger {
  final Duration limit;

  const UsageQuota(this.limit);
}

class LaunchQuota extends Trigger {
  final int limit;

  const LaunchQuota(this.limit);
}

class BlockRule {
  final int id;
  final String name;
  final Set<String> packages;
  final Trigger trigger;
  final bool enabled;

  const BlockRule({
    required this.id,
    required this.name,
    required this.packages,
    required this.trigger,
    required this.enabled,
  });
}

class AppUsage {
  final Duration foregroundTime;
  final int launches;

  const AppUsage({required this.foregroundTime, required this.launches});
}

sealed class Decision {
  const Decision();
}

class Allow extends Decision {
  const Allow();
}

class Block extends Decision {
  final BlockRule rule;

  const Block(this.rule);
}

Decision decide({
  required List<BlockRule> rules,
  required String package,
  required DateTime now,
  required AppUsage usage,
}) {
  for (final rule in rules) {
    if (!rule.enabled || !rule.packages.contains(package)) {
      continue;
    }

    final blocks = switch (rule.trigger) {
      final Schedule schedule => _scheduleBlocks(schedule, now),
      final UsageQuota quota => usage.foregroundTime >= quota.limit,
      final LaunchQuota quota => usage.launches >= quota.limit,
    };

    if (blocks) {
      return Block(rule);
    }
  }

  return const Allow();
}

bool _scheduleBlocks(Schedule schedule, DateTime now) {
  if (schedule.startMinute == schedule.endMinute) {
    return false;
  }

  final minute = now.hour * 60 + now.minute;
  if (schedule.endMinute > schedule.startMinute) {
    return schedule.weekdays.contains(now.weekday) &&
        minute >= schedule.startMinute &&
        minute < schedule.endMinute;
  }

  // After midnight, the overnight window belongs to the previous weekday.
  if (minute < schedule.endMinute) {
    final startWeekday = now.weekday == DateTime.monday
        ? DateTime.sunday
        : now.weekday - 1;
    return schedule.weekdays.contains(startWeekday);
  }

  return minute >= schedule.startMinute &&
      schedule.weekdays.contains(now.weekday);
}
