import 'dart:async';

import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../apps/app_service.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/rule.dart';
import 'usage_report.dart';
import 'widgets/app_usage_list.dart';
import 'widgets/usage_bar_chart.dart';

enum _Range { day, week }

const _historyDays = 6;
const _weekLength = 7;
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _rising = Color(0xFFF0A868);
const _falling = Color(0xFF6FD08C);

typedef _Window = ({
  List<DateTime> starts,
  DateTime end,
  DateTime previousStart,
});

/// A loaded period. Kept whole so the chart labels can never describe a
/// different period from the report they sit under.
class _View {
  const _View({
    required this.range,
    required this.starts,
    required this.report,
    required this.previousTotal,
    required this.names,
  });

  final _Range range;
  final List<DateTime> starts;
  final UsageReport report;
  final Duration previousTotal;
  final Map<String, String> names;
}

class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.appService});

  final AppService appService;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> with WidgetsBindingObserver {
  _Range _range = _Range.day;
  int _daysBack = 0;
  bool _usageAccess = true;
  Object? _loadError;
  _View? _view;
  int? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _Window _window() {
    final now = DateTime.now();
    if (_range == _Range.day) {
      final day = DateTime(now.year, now.month, now.day - _daysBack);
      final nextDay = DateTime(day.year, day.month, day.day + 1);
      return (
        starts: [
          for (var hour = 0; hour < 24; hour++)
            DateTime(day.year, day.month, day.day, hour),
        ],
        end: nextDay.isAfter(now) ? now : nextDay,
        previousStart: DateTime(day.year, day.month, day.day - 1),
      );
    }
    return (
      starts: [
        for (var back = _weekLength - 1; back >= 0; back--)
          DateTime(now.year, now.month, now.day - back),
      ],
      end: now,
      previousStart: DateTime(now.year, now.month, now.day - _weekLength * 2),
    );
  }

  Future<void> _load() async {
    if (!(await UsageStats.checkUsagePermission() ?? false)) {
      if (mounted) setState(() => _usageAccess = false);
      return;
    }

    final range = _range;
    final window = _window();
    try {
      final events = await readUsageEvents(window.previousStart, window.end);
      final apps = await widget.appService.getInstalledApps();
      if (!mounted) return;
      setState(() {
        _usageAccess = true;
        _loadError = null;
        _view = _View(
          range: range,
          starts: window.starts,
          report: summarizeUsage(
            events: events,
            bucketStarts: window.starts,
            end: window.end,
          ),
          previousTotal: summarizeUsage(
            events: events,
            bucketStarts: [window.previousStart],
            end: window.starts.first,
          ).total,
          names: {for (final app in apps) app.packageName: app.displayName},
        );
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _showRange(_Range range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _daysBack = 0;
      _selected = null;
    });
    unawaited(_load());
  }

  void _shiftDay(int days) {
    setState(() {
      _daysBack += days;
      _selected = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    if (!_usageAccess) {
      return _UsageAccessGate(
        onGrant: () => unawaited(UsageStats.grantUsagePermission()),
      );
    }

    final view = _view;
    if (view == null) {
      return Center(
        child: _loadError == null
            ? const CircularProgressIndicator(color: BlockingColors.accent)
            : _Retry(onRetry: () => unawaited(_load())),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: BlockingColors.accent,
      backgroundColor: BlockingColors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _RangeToggle(range: _range, onChanged: _showRange),
          _periodNavigator(),
          const SizedBox(height: 14),
          _overview(view),
          const SizedBox(height: 14),
          _tiles(view),
          const SizedBox(height: 28),
          const Text(
            'Most used',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (view.report.apps.isEmpty)
            const _EmptyUsage()
          else
            AppUsageList(
              apps: view.report.apps,
              names: view.names,
              appService: widget.appService,
            ),
        ],
      ),
    );
  }

  Widget _periodNavigator() {
    if (_range == _Range.week) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: Text(
            'Last 7 days',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BlockingColors.textMuted,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            onPressed: _daysBack < _historyDays ? () => _shiftDay(1) : null,
          ),
          Expanded(
            child: Text(
              _dayLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right,
            onPressed: _daysBack > 0 ? () => _shiftDay(-1) : null,
          ),
        ],
      ),
    );
  }

  String _dayLabel() {
    if (_daysBack == 0) return 'Today';
    if (_daysBack == 1) return 'Yesterday';
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day - _daysBack);
    return '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';
  }

  Widget _overview(_View view) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCREEN TIME',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: BlockingColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Total(view.report.total),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _changeChip(view),
              ),
            ],
          ),
          const SizedBox(height: 20),
          UsageBarChart(
            buckets: view.report.buckets,
            labels: _labels(view),
            names: _bucketNames(view),
            selectedIndex: _selected,
            currentIndex: _currentBucket(view),
            onSelected: (index) => setState(() => _selected = index),
          ),
        ],
      ),
    );
  }

  Widget _changeChip(_View view) {
    if (view.previousTotal == Duration.zero) return const SizedBox.shrink();
    final change =
        ((view.report.total - view.previousTotal).inSeconds /
                view.previousTotal.inSeconds *
                100)
            .round();
    final color = change > 0 ? _rising : _falling;
    final period = view.range == _Range.day ? 'yesterday' : 'last week';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${change.abs()}% vs $period',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _labels(_View view) {
    if (view.range == _Range.day) {
      return [
        for (var hour = 0; hour < view.starts.length; hour++)
          if (hour % 6 == 0) hour.toString().padLeft(2, '0') else '',
      ];
    }
    return [for (final day in view.starts) _weekdays[day.weekday - 1][0]];
  }

  List<String> _bucketNames(_View view) {
    if (view.range == _Range.day) {
      return [
        for (var hour = 0; hour < view.starts.length; hour++)
          ruleTime(hour * 60),
      ];
    }
    return [for (final day in view.starts) _weekdays[day.weekday - 1]];
  }

  int? _currentBucket(_View view) {
    final now = DateTime.now();
    if (view.range == _Range.week) return _weekLength - 1;
    final start = view.starts.first;
    final isToday =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    return isToday ? now.hour : null;
  }

  Widget _tiles(_View view) {
    final busiest = _busiestBucket(view.report);
    final isDay = view.range == _Range.day;
    return Row(
      children: [
        Expanded(
          child: _Tile(
            label: isDay ? 'Busiest hour' : 'Daily average',
            value: isDay
                ? (busiest == null ? '—' : ruleTime(busiest * 60))
                : ruleDuration(view.report.total ~/ _weekLength),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(label: 'App opens', value: '${view.report.opens}'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            label: isDay ? 'Apps used' : 'Busiest day',
            value: isDay
                ? '${view.report.apps.length}'
                : (busiest == null
                      ? '—'
                      : _weekdays[view.starts[busiest].weekday - 1]),
          ),
        ),
      ],
    );
  }

  int? _busiestBucket(UsageReport report) {
    int? busiest;
    for (var index = 0; index < report.buckets.length; index++) {
      if (report.buckets[index] > Duration.zero &&
          (busiest == null ||
              report.buckets[index] > report.buckets[busiest])) {
        busiest = index;
      }
    }
    return busiest;
  }
}

class _Total extends StatelessWidget {
  const _Total(this.total);

  final Duration total;

  @override
  Widget build(BuildContext context) {
    const figure = TextStyle(
      fontSize: 40,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      color: Colors.white,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const unit = TextStyle(
      fontSize: 17,
      height: 1,
      fontWeight: FontWeight.w600,
      color: BlockingColors.textMuted,
    );
    final hours = total.inHours;
    return Text.rich(
      TextSpan(
        children: [
          if (hours > 0) ...[
            TextSpan(text: '$hours', style: figure),
            const TextSpan(text: 'h ', style: unit),
          ],
          TextSpan(text: '${total.inMinutes.remainder(60)}', style: figure),
          const TextSpan(text: 'm', style: unit),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.range, required this.onChanged});

  final _Range range;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Row(
        children: [
          for (final option in _Range.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('stats-range-${option.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == range
                        ? BlockingColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    option == _Range.day ? 'Day' : 'Week',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: option == range
                          ? BlockingColors.onAccent
                          : BlockingColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: Colors.white,
      disabledColor: BlockingColors.outline,
      style: IconButton.styleFrom(
        backgroundColor: BlockingColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: BlockingColors.outline),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: BlockingColors.textMuted,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'No app activity recorded yet.',
          style: TextStyle(color: BlockingColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Could not read your usage.'),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: BlockingColors.accent),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _UsageAccessGate extends StatelessWidget {
  const _UsageAccessGate({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BlockingColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights,
                color: BlockingColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Usage access needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'SerenSync reads Android usage data on your device to show how '
              'long you spend in each app. Nothing leaves your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: BlockingColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('grant-usage-access'),
              onPressed: onGrant,
              style: FilledButton.styleFrom(
                backgroundColor: BlockingColors.accent,
                foregroundColor: BlockingColors.onAccent,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Grant usage access'),
            ),
          ],
        ),
      ),
    );
  }
}
