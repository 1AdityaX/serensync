import 'package:usage_stats/usage_stats.dart';

const _activityResumed = 1;
const _activityPaused = 2;
const _activityStopped = 23;
const _screenNonInteractive = 16;
const _keyguardShown = 17;

typedef UsageEvent = ({String packageName, int type, DateTime time});

class AppTotal {
  const AppTotal({
    required this.packageName,
    required this.time,
    required this.opens,
  });

  final String packageName;
  final Duration time;
  final int opens;
}

class UsageReport {
  const UsageReport({
    required this.buckets,
    required this.apps,
    required this.total,
    required this.opens,
  });

  final List<Duration> buckets;
  final List<AppTotal> apps;
  final Duration total;
  final int opens;
}

Future<List<UsageEvent>> readUsageEvents(DateTime start, DateTime end) async {
  final events = await UsageStats.queryEvents(start, end);
  return [for (final event in events) ?_parse(event)];
}

/// Rebuilds foreground sessions from raw events and folds them into the
/// buckets spanning `bucketStarts.first` to [end]. Bucket `i` covers
/// `bucketStarts[i]` up to the next start, so callers can use calendar days
/// without losing an hour to daylight saving.
UsageReport summarizeUsage({
  required List<UsageEvent> events,
  required List<DateTime> bucketStarts,
  required DateTime end,
}) {
  final start = bucketStarts.first;
  final buckets = List<Duration>.filled(bucketStarts.length, Duration.zero);
  final totals = <String, Duration>{};
  final opens = <String, int>{};
  String? foreground;
  DateTime? openedAt;

  void record(DateTime until) {
    final package = foreground;
    final opened = openedAt;
    foreground = null;
    openedAt = null;
    if (package == null || opened == null) return;

    final from = opened.isBefore(start) ? start : opened;
    final to = until.isAfter(end) ? end : until;
    if (!to.isAfter(from)) return;

    totals[package] = (totals[package] ?? Duration.zero) + to.difference(from);
    for (var index = 0; index < buckets.length; index++) {
      final bucketStart = bucketStarts[index];
      final bucketEnd = index + 1 < bucketStarts.length
          ? bucketStarts[index + 1]
          : end;
      final overlapFrom = from.isAfter(bucketStart) ? from : bucketStart;
      final overlapTo = to.isBefore(bucketEnd) ? to : bucketEnd;
      if (overlapTo.isAfter(overlapFrom)) {
        buckets[index] += overlapTo.difference(overlapFrom);
      }
    }
  }

  final ordered = [...events]..sort((a, b) => a.time.compareTo(b.time));
  for (final event in ordered) {
    if (event.type == _activityResumed) {
      if (event.packageName == foreground) continue;
      record(event.time);
      foreground = event.packageName;
      openedAt = event.time;
      if (!event.time.isBefore(start) && !event.time.isAfter(end)) {
        opens[event.packageName] = (opens[event.packageName] ?? 0) + 1;
      }
    } else if (event.type == _screenNonInteractive ||
        event.type == _keyguardShown ||
        (event.packageName == foreground &&
            (event.type == _activityPaused ||
                event.type == _activityStopped))) {
      record(event.time);
    }
  }
  record(end);

  final apps = [
    for (final total in totals.entries)
      AppTotal(
        packageName: total.key,
        time: total.value,
        opens: opens[total.key] ?? 0,
      ),
  ]..sort((a, b) => b.time.compareTo(a.time));

  return UsageReport(
    buckets: buckets,
    apps: apps,
    total: buckets.fold(Duration.zero, (sum, bucket) => sum + bucket),
    opens: opens.values.fold(0, (sum, count) => sum + count),
  );
}

UsageEvent? _parse(EventUsageInfo event) {
  final package = event.packageName;
  final type = int.tryParse(event.eventType ?? '');
  final milliseconds = int.tryParse(event.timeStamp ?? '');
  if (package == null || type == null || milliseconds == null) return null;
  return (
    packageName: package,
    type: type,
    time: DateTime.fromMillisecondsSinceEpoch(milliseconds),
  );
}
