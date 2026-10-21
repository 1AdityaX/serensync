sealed class Trigger {
  const Trigger();
}

class Schedule extends Trigger {
  final Set<int> weekdays;
  final int startMinute;
  final int endMinute;
  final List<ScheduleTime> additionalTimes;
  final bool allDay;

  const Schedule({
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
    this.additionalTimes = const [],
    this.allDay = false,
  });

  List<ScheduleTime> get times => [
    ScheduleTime(startMinute: startMinute, endMinute: endMinute),
    ...additionalTimes,
  ];
}

class ScheduleTime {
  final int startMinute;
  final int endMinute;

  const ScheduleTime({required this.startMinute, required this.endMinute});
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
  final Set<String> websites;
  final Set<String> keywords;
  final Trigger trigger;
  final bool enabled;

  const BlockRule({
    required this.id,
    required this.name,
    required this.packages,
    this.websites = const {},
    this.keywords = const {},
    required this.trigger,
    required this.enabled,
  });

  bool get blocksWeb => websites.isNotEmpty || keywords.isNotEmpty;
}

/// What a browser's address bar shows, without scheme, `www.`, or port.
typedef WebAddress = ({String host, String url});

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

/// Rules in [always] block whenever they match, whatever their trigger or
/// enabled state; a focus session uses this.
Decision decide({
  required List<BlockRule> rules,
  required String package,
  required DateTime now,
  required AppUsage usage,
  Set<int> always = const <int>{},
}) {
  for (final rule in rules) {
    if (!rule.packages.contains(package)) continue;
    if (always.contains(rule.id)) return Block(rule);
    if (!rule.enabled) continue;

    final blocks = switch (rule.trigger) {
      final Schedule schedule => scheduleActive(schedule, now),
      final UsageQuota quota => usage.foregroundTime >= quota.limit,
      final LaunchQuota quota => usage.launches >= quota.limit,
    };

    if (blocks) {
      return Block(rule);
    }
  }

  return const Allow();
}

Decision decideWeb({
  required List<BlockRule> rules,
  required WebAddress address,
  required DateTime now,
  Set<int> always = const <int>{},
}) {
  for (final rule in rules) {
    if (!_matchesAddress(rule, address)) continue;
    if (always.contains(rule.id)) return Block(rule);
    if (!rule.enabled) continue;

    // Browsing time is not measured, so usage and launch limits block their
    // websites and keywords outright.
    final blocks = switch (rule.trigger) {
      final Schedule schedule => scheduleActive(schedule, now),
      UsageQuota() || LaunchQuota() => true,
    };

    if (blocks) {
      return Block(rule);
    }
  }

  return const Allow();
}

final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://');
final _pathStart = RegExp(r'[/?#]');
final _host = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');

/// Parses address-bar text or a website entry. Returns null for text that is
/// not a web address, such as a typed search or a browser's placeholder.
WebAddress? parseAddress(String text) {
  final address = text.trim().toLowerCase().replaceFirst(_scheme, '');
  if (address.isEmpty || address.contains(' ')) return null;

  final pathStart = address.indexOf(_pathStart);
  var authority = pathStart == -1 ? address : address.substring(0, pathStart);
  final path = pathStart == -1 ? '' : address.substring(pathStart);
  authority = authority.substring(authority.indexOf('@') + 1);
  final port = authority.indexOf(':');
  if (port != -1) authority = authority.substring(0, port);
  final host = authority.startsWith('www.')
      ? authority.substring(4)
      : authority;
  if (!_host.hasMatch(host)) return null;

  return (host: host, url: _decode('$host$path'));
}

// Search engines encode query spaces as '+', which decodeFull leaves alone.
String _decode(String url) {
  final spaced = url.replaceAll('+', ' ');
  try {
    return Uri.decodeFull(spaced);
  } on ArgumentError {
    return spaced;
  }
}

String triggerSummary(Trigger trigger) {
  return switch (trigger) {
    final Schedule schedule when schedule.allDay =>
      'Blocked ${weekdaySummary(schedule.weekdays)} all day',
    final Schedule schedule when schedule.times.length == 1 =>
      'Blocked ${weekdaySummary(schedule.weekdays)} '
          '${ruleTime(schedule.startMinute)}–${ruleTime(schedule.endMinute)}',
    final Schedule schedule =>
      'Blocked ${weekdaySummary(schedule.weekdays)} · '
          '${schedule.times.length} time windows',
    final UsageQuota quota =>
      'Blocked after ${ruleDuration(quota.limit)} a day',
    final LaunchQuota quota => 'Blocked after ${quota.limit} opens a day',
  };
}

String weekdaySummary(Set<int> weekdays) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final sorted = weekdays.toList()..sort();
  final parts = <String>[];
  var index = 0;
  while (index < sorted.length) {
    final start = sorted[index];
    var end = start;
    while (index + 1 < sorted.length && sorted[index + 1] == end + 1) {
      end = sorted[++index];
    }
    parts.add(
      start == end ? names[start - 1] : '${names[start - 1]}–${names[end - 1]}',
    );
    index++;
  }
  return parts.isEmpty ? 'No days' : parts.join(', ');
}

String ruleTime(int minute) {
  final hour = (minute ~/ 60).toString().padLeft(2, '0');
  final minuteOfHour = (minute % 60).toString().padLeft(2, '0');
  return '$hour:$minuteOfHour';
}

String ruleDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${duration.inMinutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// A block's name from what it covers: "Instagram, TikTok + 2 more".
String ruleName(List<String> targets) {
  if (targets.length <= 2) return targets.join(', ');
  return '${targets.take(2).join(', ')} + ${targets.length - 2} more';
}

bool _matchesAddress(BlockRule rule, WebAddress address) {
  return rule.websites.any(
        (site) => address.host == site || address.host.endsWith('.$site'),
      ) ||
      rule.keywords.any(address.url.contains);
}

bool scheduleActive(Schedule schedule, DateTime now) {
  if (schedule.allDay) return schedule.weekdays.contains(now.weekday);
  return schedule.times.any(
    (time) => _timeBlocks(time, schedule.weekdays, now),
  );
}

bool _timeBlocks(ScheduleTime time, Set<int> weekdays, DateTime now) {
  if (time.startMinute == time.endMinute) return false;

  final minute = now.hour * 60 + now.minute;
  if (time.endMinute > time.startMinute) {
    return weekdays.contains(now.weekday) &&
        minute >= time.startMinute &&
        minute < time.endMinute;
  }

  // After midnight, the overnight window belongs to the previous weekday.
  if (minute < time.endMinute) {
    final startWeekday = now.weekday == DateTime.monday
        ? DateTime.sunday
        : now.weekday - 1;
    return weekdays.contains(startWeekday);
  }

  return minute >= time.startMinute && weekdays.contains(now.weekday);
}

/// When [schedule] next starts blocking after [now], within a week, or null
/// when it never does.
DateTime? nextScheduleStart(Schedule schedule, DateTime now) {
  DateTime? next;
  for (var offset = 0; offset <= 7; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    if (!schedule.weekdays.contains(day.weekday)) continue;
    final starts = schedule.allDay
        ? const [0]
        : [
            for (final time in schedule.times)
              if (time.startMinute != time.endMinute) time.startMinute,
          ];
    for (final minute in starts) {
      final start = DateTime(day.year, day.month, day.day, 0, minute);
      if (start.isAfter(now) && (next == null || start.isBefore(next))) {
        next = start;
      }
    }
    if (next != null) return next;
  }
  return next;
}

/// A short, plain status for a block, such as "Blocking now" or
/// "Starts at 22:00".
String ruleStatus(BlockRule rule, DateTime now) {
  if (!rule.enabled) return 'Paused';
  return switch (rule.trigger) {
    final Schedule schedule when scheduleActive(schedule, now) =>
      'Blocking now',
    final Schedule schedule => switch (nextScheduleStart(schedule, now)) {
      null => 'No days chosen',
      final start =>
        'Starts ${_relativeDay(start, now)}${ruleTime(start.hour * 60 + start.minute)}',
    },
    final UsageQuota quota => 'Closes after ${ruleDuration(quota.limit)} a day',
    final LaunchQuota quota =>
      'Closes after ${quota.limit} ${quota.limit == 1 ? 'open' : 'opens'} a day',
  };
}

String _relativeDay(DateTime day, DateTime now) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(day.year, day.month, day.day);
  if (date == today) return 'at ';
  if (date == DateTime(now.year, now.month, now.day + 1)) {
    return 'tomorrow at ';
  }
  return '${names[day.weekday - 1]} at ';
}

/// Whether [rule] is blocking by the clock at [now]. Limits depend on usage,
/// so they never count here.
bool blockingNow(BlockRule rule, DateTime now) =>
    rule.enabled &&
    switch (rule.trigger) {
      final Schedule schedule => scheduleActive(schedule, now),
      _ => false,
    };

/// The status in a word or two for tight spaces: "Now", "21:00",
/// "Tue 09:00", "45m a day", "5 opens" or "Off".
String ruleStatusShort(BlockRule rule, DateTime now) {
  if (!rule.enabled) return 'Off';
  return switch (rule.trigger) {
    final Schedule schedule when scheduleActive(schedule, now) => 'Now',
    final Schedule schedule => switch (nextScheduleStart(schedule, now)) {
      null => 'No days',
      final start =>
        '${_sameDate(start, now) ? '' : '${_dayNames[start.weekday - 1]} '}'
            '${ruleTime(start.hour * 60 + start.minute)}',
    },
    final UsageQuota quota => '${ruleDuration(quota.limit)} a day',
    final LaunchQuota quota =>
      '${quota.limit} ${quota.limit == 1 ? 'open' : 'opens'} a day',
  };
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
