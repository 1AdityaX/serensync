import 'dart:math';

import '../blocking/rule.dart';

/// What the first block is for. The goal fixes the kind of block and where
/// the ring starts; the apps and the value are the user's.
enum Goal { scrolling, work, nights, pickups }

const _minutesPerDay = 24 * 60;

/// A full ring on the limit dial.
const _ringMinutes = 4 * 60;
const _ringOpens = 30;

const _weekdays = {
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
};
const _everyDay = {..._weekdays, DateTime.saturday, DateTime.sunday};

String goalTitle(Goal goal) => switch (goal) {
  Goal.scrolling => 'Scroll less',
  Goal.work => 'Focus at work',
  Goal.nights => 'Phone-free nights',
  Goal.pickups => 'Pick it up less',
};

String goalDetail(Goal goal) => switch (goal) {
  Goal.scrolling => 'A daily limit, then they close',
  Goal.work => 'Closed through the workday',
  Goal.nights => 'Closed from evening to morning',
  Goal.pickups => 'A set number of opens a day',
};

/// Completes "Your plan to …".
String goalPhrase(Goal goal) => switch (goal) {
  Goal.scrolling => 'scroll less',
  Goal.work => 'focus at work',
  Goal.nights => 'keep nights phone-free',
  Goal.pickups => 'pick it up less',
};

Trigger goalTrigger(Goal goal) => switch (goal) {
  Goal.scrolling => const UsageQuota(Duration(minutes: 45)),
  Goal.work => const Schedule(
    weekdays: _weekdays,
    startMinute: 9 * 60,
    endMinute: 17 * 60,
  ),
  Goal.nights => const Schedule(
    weekdays: _everyDay,
    startMinute: 22 * 60,
    endMinute: 7 * 60,
  ),
  Goal.pickups => const LaunchQuota(5),
};

String limitQuestion(Trigger trigger) => switch (trigger) {
  UsageQuota() => 'How much a day is enough?',
  LaunchQuota() => 'How many opens a day?',
  Schedule() => 'When should they stay closed?',
};

String limitHint(Trigger trigger) => switch (trigger) {
  UsageQuota() =>
    'Drag the ring. Once it is used up, the apps close for the day.',
  LaunchQuota() =>
    'Drag the ring. After the last open, the apps close for the day.',
  final Schedule schedule =>
    'Drag either end. ${weekdaySummary(schedule.weekdays)}.',
};

/// Minutes a window covers, across midnight when it has to.
int windowMinutes(Schedule schedule) =>
    (schedule.endMinute - schedule.startMinute) % _minutesPerDay;

String _window(Schedule schedule) =>
    '${ruleTime(schedule.startMinute)}–${ruleTime(schedule.endMinute)}';

/// How much of the ring the limit fills: a day for a window, four hours for
/// a usage limit, thirty for opens.
double limitFraction(Trigger trigger) => switch (trigger) {
  final UsageQuota quota => quota.limit.inMinutes / _ringMinutes,
  final LaunchQuota quota => quota.limit / _ringOpens,
  final Schedule schedule => windowMinutes(schedule) / _minutesPerDay,
};

/// The limit at [fraction] of the ring, in five-minute or single-open steps.
/// Windows are not on this ring; both their ends are dragged directly.
Trigger quotaAt(Trigger quota, double fraction) => switch (quota) {
  UsageQuota() => UsageQuota(
    Duration(minutes: max(5, (fraction * _ringMinutes / 5).round() * 5)),
  ),
  LaunchQuota() => LaunchQuota(max(1, (fraction * _ringOpens).round())),
  Schedule() => quota,
};

/// What the limit dial shows in its middle.
({String big, String small}) limitCentre(Trigger trigger) => switch (trigger) {
  final UsageQuota quota => (big: ruleDuration(quota.limit), small: 'a day'),
  final LaunchQuota quota => (
    big: '${quota.limit}',
    small: _opens(quota.limit),
  ),
  final Schedule schedule => (
    big: _window(schedule),
    small:
        '${ruleDuration(Duration(minutes: windowMinutes(schedule)))} · '
        '${weekdaySummary(schedule.weekdays)}',
  ),
};

/// What the plan's gauge shows in its middle.
({String big, String small}) planCentre(Trigger trigger) => switch (trigger) {
  final Schedule schedule => (
    big: ruleDuration(Duration(minutes: windowMinutes(schedule))),
    small: 'a day, ${weekdaySummary(schedule.weekdays)}',
  ),
  _ => limitCentre(trigger),
};

String limitChip(Trigger trigger) => switch (trigger) {
  final UsageQuota quota => '${ruleDuration(quota.limit)} a day',
  final LaunchQuota quota => '${quota.limit} ${_opens(quota.limit)}',
  final Schedule schedule => _window(schedule),
};

/// "Instagram", "Instagram +2".
String appsChip(List<String> names) =>
    names.length == 1 ? names.single : '${names.first} +${names.length - 1}';

/// "Instagram", "Instagram and TikTok" or "Instagram and 2 more".
String appsPhrase(List<String> names) => switch (names.length) {
  1 => names.single,
  2 => '${names[0]} and ${names[1]}',
  _ => '${names.first} and ${names.length - 1} more',
};

/// "Instagram and 2 more close after 45m a day."
String planSentence(List<String> names, Trigger trigger) {
  final one = names.length == 1;
  final closes = switch (trigger) {
    final Schedule schedule =>
      '${one ? 'stays' : 'stay'} closed ${weekdaySummary(schedule.weekdays)}, '
          '${_window(schedule)}',
    final UsageQuota quota =>
      '${one ? 'closes' : 'close'} after ${ruleDuration(quota.limit)} a day',
    final LaunchQuota quota =>
      '${one ? 'closes' : 'close'} after ${quota.limit} '
          '${_opens(quota.limit)}',
  };
  return '${appsPhrase(names)} $closes.';
}

String _opens(int count) => count == 1 ? 'open a day' : 'opens a day';
