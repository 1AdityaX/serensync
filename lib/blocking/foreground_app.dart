import 'package:usage_stats/usage_stats.dart';

import 'rule.dart';

typedef ForegroundState = ({String? packageName, bool screenInteractive});

const _trailingWindow = Duration(seconds: 10);
const _cacheDuration = Duration(seconds: 10);
const _activityResumed = 1;
const _screenInteractive = 15;
const _screenNonInteractive = 16;
const _keyguardShown = 17;
const _keyguardHidden = 18;

class ForegroundApp {
  final Map<String, _CachedUsage> _usageCache = <String, _CachedUsage>{};
  String? _foregroundPackage;
  bool _isScreenInteractive = true;
  DateTime? _lastEventQuery;
  DateTime? _lastScreenEvent;

  Future<ForegroundState> foregroundState(DateTime now) async {
    final previousQuery = _lastEventQuery;
    final start = previousQuery != null && !now.isBefore(previousQuery)
        ? previousQuery
        : now.subtract(_trailingWindow);
    final events = await UsageStats.queryEvents(start, now);
    _lastEventQuery = now;
    EventUsageInfo? latest;
    for (final event in events) {
      _updateScreenState(event);
      if (!_isResume(event) || event.packageName == null) {
        continue;
      }

      final timestamp = _eventTime(event);
      final latestTimestamp = latest == null ? null : _eventTime(latest);
      if (timestamp != null &&
          (latestTimestamp == null || timestamp.isAfter(latestTimestamp))) {
        latest = event;
      }
    }
    if (latest != null) {
      _foregroundPackage = latest.packageName;
    }
    return (
      packageName: _foregroundPackage,
      screenInteractive: _isScreenInteractive,
    );
  }

  Future<AppUsage> todayUsage(String packageName, DateTime now) async {
    final cached = _usageCache[packageName];
    if (cached != null &&
        !now.isBefore(cached.fetchedAt) &&
        now.difference(cached.fetchedAt) < _cacheDuration) {
      return cached.usage;
    }

    final start = DateTime(now.year, now.month, now.day);
    final stats = await UsageStats.queryUsageStats(start, now);
    final events = await UsageStats.queryEvents(start, now);
    final usage = AppUsage(
      foregroundTime: Duration(
        milliseconds: stats
            .where((info) => info.packageName == packageName)
            .fold<int>(
              0,
              (total, info) => total + _foregroundMilliseconds(info),
            ),
      ),
      launches: events
          .where(
            (event) => event.packageName == packageName && _isResume(event),
          )
          .length,
    );
    _usageCache[packageName] = _CachedUsage(usage, now);
    return usage;
  }

  void invalidateUsage() {
    _usageCache.clear();
  }

  void _updateScreenState(EventUsageInfo event) {
    final screenState = _screenState(event);
    final timestamp = _eventTime(event);
    if (screenState == null ||
        timestamp == null ||
        (_lastScreenEvent != null && !timestamp.isAfter(_lastScreenEvent!))) {
      return;
    }
    _isScreenInteractive = screenState;
    _lastScreenEvent = timestamp;
  }
}

bool _isResume(EventUsageInfo event) {
  return int.tryParse(event.eventType ?? '') == _activityResumed;
}

bool? _screenState(EventUsageInfo event) {
  return switch (int.tryParse(event.eventType ?? '')) {
    _screenInteractive || _keyguardHidden => true,
    _screenNonInteractive || _keyguardShown => false,
    _ => null,
  };
}

DateTime? _eventTime(EventUsageInfo event) {
  final milliseconds = int.tryParse(event.timeStamp ?? '');
  if (milliseconds == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

int _foregroundMilliseconds(UsageInfo info) {
  return int.tryParse(info.totalTimeInForeground ?? '') ?? 0;
}

class _CachedUsage {
  const _CachedUsage(this.usage, this.fetchedAt);

  final AppUsage usage;
  final DateTime fetchedAt;
}
