import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/stats/usage_report.dart';

const _resumed = 1;
const _paused = 2;
const _screenOff = 16;

final _day = DateTime(2026, 8, 4);
final _end = DateTime(2026, 8, 5);
final _hours = [
  for (var hour = 0; hour < 24; hour++) _day.add(Duration(hours: hour)),
];

UsageEvent _event(String package, int type, DateTime time) {
  return (packageName: package, type: type, time: time);
}

DateTime _at(int hour, [int minute = 0]) {
  return DateTime(_day.year, _day.month, _day.day, hour, minute);
}

UsageReport _summarize(List<UsageEvent> events, {DateTime? end}) {
  return summarizeUsage(events: events, bucketStarts: _hours, end: end ?? _end);
}

void main() {
  test('measures a session between resume and pause', () {
    final report = _summarize([
      _event('chat', _resumed, _at(9, 10)),
      _event('chat', _paused, _at(9, 40)),
    ]);

    expect(report.total, const Duration(minutes: 30));
    expect(report.buckets[9], const Duration(minutes: 30));
    expect(report.apps.single.packageName, 'chat');
    expect(report.apps.single.time, const Duration(minutes: 30));
    expect(report.apps.single.opens, 1);
  });

  test('splits a session across the buckets it spans', () {
    final report = _summarize([
      _event('video', _resumed, _at(9, 30)),
      _event('video', _paused, _at(11, 15)),
    ]);

    expect(report.buckets[9], const Duration(minutes: 30));
    expect(report.buckets[10], const Duration(hours: 1));
    expect(report.buckets[11], const Duration(minutes: 15));
    expect(report.total, const Duration(hours: 1, minutes: 45));
  });

  test('clips a session that started before the window', () {
    final report = _summarize([
      _event('video', _resumed, _at(0).subtract(const Duration(hours: 2))),
      _event('video', _paused, _at(0, 20)),
    ]);

    expect(report.total, const Duration(minutes: 20));
    expect(report.apps.single.opens, 0);
  });

  test('closes a session still open at the end of the window', () {
    final report = _summarize([
      _event('chat', _resumed, _at(22, 30)),
    ], end: _at(23));

    expect(report.total, const Duration(minutes: 30));
    expect(report.buckets[22], const Duration(minutes: 30));
  });

  test('ends a session when the screen turns off', () {
    final report = _summarize([
      _event('chat', _resumed, _at(8)),
      _event('android', _screenOff, _at(8, 15)),
      _event('chat', _resumed, _at(9)),
      _event('chat', _paused, _at(9, 5)),
    ]);

    expect(report.total, const Duration(minutes: 20));
    expect(report.apps.single.opens, 2);
  });

  test('switching apps ends the previous session', () {
    final report = _summarize([
      _event('chat', _resumed, _at(8)),
      _event('video', _resumed, _at(8, 20)),
      _event('video', _paused, _at(8, 50)),
    ]);

    expect(report.total, const Duration(minutes: 50));
    expect(report.apps.first.packageName, 'video');
    expect(report.apps.first.time, const Duration(minutes: 30));
    expect(report.apps.last.time, const Duration(minutes: 20));
  });

  test('counts an open once when an app resumes its own activities', () {
    final report = _summarize([
      _event('chat', _resumed, _at(8)),
      _event('chat', _resumed, _at(8, 10)),
      _event('chat', _paused, _at(8, 30)),
    ]);

    expect(report.opens, 1);
    expect(report.total, const Duration(minutes: 30));
  });

  test('reads events in any order', () {
    final report = _summarize([
      _event('chat', _paused, _at(9, 40)),
      _event('chat', _resumed, _at(9, 10)),
    ]);

    expect(report.total, const Duration(minutes: 30));
  });

  test('reports nothing when no events were recorded', () {
    final report = _summarize([]);

    expect(report.total, Duration.zero);
    expect(report.opens, 0);
    expect(report.apps, isEmpty);
    expect(report.buckets, hasLength(24));
  });
}
