import 'dart:async';

import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../apps/app_service.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/onboarding/permission_status.dart';
import '../blocking/rule.dart';
import '../blocking/rule_store.dart';
import '../common/cards.dart';
import '../common/glyph_map.dart';
import '../common/glyphs.dart';
import '../common/illustrations.dart';
import '../pomodoro/pomodoro_session.dart';
import '../pomodoro/pomodoro_store.dart';
import '../stats/usage_report.dart';
import '../strict/strict_mode.dart';
import '../strict/strict_mode_store.dart';

/// Today's screen time next to yesterday's up to the same time of day.
typedef TodayUsage = ({UsageReport today, Duration yesterday});

/// Reads [TodayUsage] from Android, or null without usage access.
Future<TodayUsage?> readTodayUsage() async {
  if (!(await UsageStats.checkUsagePermission() ?? false)) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final events = await readUsageEvents(yesterday, now);
  return (
    today: summarizeUsage(events: events, bucketStarts: [today], end: now),
    yesterday: summarizeUsage(
      events: events,
      bucketStarts: [yesterday],
      end: DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        now.hour,
        now.minute,
      ),
    ).total,
  );
}

/// The landing tab: a greeting, what is protecting the user right now, how
/// the day is going, and one tap to every main action.
class TodayTab extends StatefulWidget {
  const TodayTab({
    super.key,
    required this.appService,
    required this.ruleStore,
    required this.pomodoroStore,
    required this.strictModeStore,
    required this.permissions,
    required this.onAllow,
    required this.onCreateBlock,
    required this.onOpenFocus,
    required this.onOpenBlocks,
    required this.onOpenStrict,
    required this.onOpenInsights,
    this.usage = readTodayUsage,
  });

  final AppService appService;
  final RuleStore ruleStore;
  final PomodoroStore pomodoroStore;
  final StrictModeStore strictModeStore;
  final PermissionState? permissions;
  final ValueChanged<RequiredPermission> onAllow;
  final VoidCallback onCreateBlock;
  final VoidCallback onOpenFocus;
  final VoidCallback onOpenBlocks;
  final VoidCallback onOpenStrict;
  final VoidCallback onOpenInsights;
  final Future<TodayUsage?> Function() usage;

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> with WidgetsBindingObserver {
  List<BlockRule>? _rules;
  StrictMode? _strict;
  PomodoroSession? _session;
  TodayUsage? _usage;
  String? _topApp;

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

  // Each source is optional: a failing one leaves its card out rather than
  // taking the whole tab down.
  Future<T?> _try<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final rules = await _try(widget.ruleStore.readAll) ?? const <BlockRule>[];
    final strict = await _try(widget.strictModeStore.read);
    final session = await _try(widget.pomodoroStore.readSession);
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _strict = strict;
      _session = session;
    });
    final usage = await _try(widget.usage);
    String? topApp;
    if (usage != null && usage.today.apps.isNotEmpty) {
      final package = usage.today.apps.first.packageName;
      final apps = await _try(widget.appService.getInstalledApps);
      topApp = apps
          ?.where((app) => app.packageName == package)
          .firstOrNull
          ?.displayName;
    }
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _topApp = topApp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    if (rules == null) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final missing = [
      for (final permission in RequiredPermission.values)
        if (permission != RequiredPermission.accessibility &&
            !(widget.permissions?.granted(permission) ?? true))
          permission,
    ];
    final enabled = [
      for (final rule in rules)
        if (rule.enabled) rule,
    ];
    final usage = _usage;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        children: [
          Text(
            _greeting(now),
            style: const TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dateLabel(now),
            style: TextStyle(fontSize: 15, color: BlockingColors.textMuted),
          ),
          const SizedBox(height: 28),
          _hero(now, enabled),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SetupTile(missing: missing, onAllow: widget.onAllow),
          ],
          if (usage != null) ...[
            const SizedBox(height: 12),
            _UsageTile(
              usage: usage,
              topApp: _topApp,
              onTap: widget.onOpenInsights,
            ),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundAction(
                actionKey: 'focus',
                glyph: Glyphs.timer,
                label: 'Focus',
                onTap: widget.onOpenFocus,
              ),
              _RoundAction(
                actionKey: 'block',
                glyph: Glyphs.plus,
                label: 'Block',
                onTap: widget.onCreateBlock,
              ),
              _RoundAction(
                actionKey: 'strict',
                glyph: Glyphs.shield,
                label: 'Strict',
                onTap: widget.onOpenStrict,
              ),
              _RoundAction(
                actionKey: 'insights',
                glyph: Glyphs.insights,
                label: 'Stats',
                onTap: widget.onOpenInsights,
              ),
            ],
          ),
          if (enabled.isNotEmpty) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Blocks',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const ValueKey('today-see-blocks'),
                  tooltip: 'All blocks',
                  onPressed: widget.onOpenBlocks,
                  icon: const Glyph(Glyphs.chevronRight, size: 22),
                ),
              ],
            ),
            for (final rule in enabled.take(4))
              _BlockLine(rule: rule, now: now),
          ],
        ],
      ),
    );
  }

  Widget _hero(DateTime now, List<BlockRule> enabled) {
    final strict = _strict;
    final session = _session;
    final focus = session?.stateAt(now);
    if (session != null &&
        focus != null &&
        focus.phase != PomodoroPhase.finished) {
      final ends = ruleTime(_minute(now.add(focus.remaining)));
      return _Hero(
        scene: Scene.focus,
        fraction: focus.phase == PomodoroPhase.focus
            ? 1 - focus.remaining.inMilliseconds / focus.length.inMilliseconds
            : 1,
        title: switch (focus.phase) {
          PomodoroPhase.focus => 'Focusing',
          PomodoroPhase.waiting => 'Break over',
          _ => 'On a break',
        },
        detail: switch (focus.phase) {
          PomodoroPhase.focus =>
            'Round ${session.round} of ${session.settings.rounds} · '
                'until $ends',
          PomodoroPhase.waiting => 'Round ${session.round + 1} is ready',
          _ => 'Back at $ends',
        },
        onTap: widget.onOpenFocus,
      );
    }
    if (strict != null && !strictModeEnded(strict, now)) {
      final until = strict.until;
      return _Hero(
        scene: Scene.lock,
        title: 'Strict mode',
        detail: until == null ? 'Until the PIN' : 'Until ${_when(until, now)}',
        onTap: widget.onOpenStrict,
      );
    }
    if (enabled.isEmpty) {
      return _Hero(
        scene: Scene.phone,
        title: 'No blocks yet',
        detail: 'Close the apps that pull you in',
        action: FilledButton.icon(
          key: const ValueKey('today-create-block'),
          onPressed: widget.onCreateBlock,
          icon: const Glyph(Glyphs.plus, size: 20),
          label: const Text('New block'),
        ),
      );
    }
    final blocking = [
      for (final rule in enabled)
        if (blockingNow(rule, now)) rule.name,
    ];
    if (blocking.isEmpty) {
      return _Hero(
        scene: Scene.sunrise,
        title: 'All calm',
        detail: enabled.length == 1
            ? '1 block ready'
            : '${enabled.length} blocks ready',
        onTap: widget.onOpenBlocks,
      );
    }
    return _Hero(
      scene: Scene.shield,
      title: _names(blocking),
      detail: 'Blocked now',
      onTap: widget.onOpenBlocks,
    );
  }
}

int _minute(DateTime time) => time.hour * 60 + time.minute;

String _greeting(DateTime now) {
  final hour = now.hour;
  if (hour < 5) return 'Good night';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _dateLabel(DateTime now) =>
    '${_weekdayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}';

String _when(DateTime time, DateTime now) {
  final clock = ruleTime(_minute(time));
  final day = DateTime(time.year, time.month, time.day);
  if (day == DateTime(now.year, now.month, now.day)) return clock;
  if (day == DateTime(now.year, now.month, now.day + 1)) {
    return 'tomorrow $clock';
  }
  return '${_weekdayNames[time.weekday - 1].substring(0, 3)} '
      '${time.day} ${_monthNames[time.month - 1].substring(0, 3)}';
}

String _names(List<String> names) {
  if (names.length == 1) return names.single;
  if (names.length == 2) return '${names.first} & ${names.last}';
  return '${names.first} + ${names.length - 1}';
}

String _delta(Duration difference) =>
    ruleDuration(Duration(minutes: difference.inMinutes.abs()));

class _Hero extends StatelessWidget {
  const _Hero({
    required this.scene,
    required this.title,
    required this.detail,
    this.fraction = 0.7,
    this.onTap,
    this.action,
  });

  final Scene scene;
  final String title;
  final String detail;
  final double fraction;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return SoftCard(
      key: const ValueKey('today-hero'),
      onTap: onTap,
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Illustration(scene, size: 88, fraction: fraction),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 14,
                        color: BlockingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 18), action],
        ],
      ),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({required this.missing, required this.onAllow});

  final List<RequiredPermission> missing;
  final ValueChanged<RequiredPermission> onAllow;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      key: const ValueKey('today-setup'),
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Glyph(Glyphs.alert, size: 20, color: BlockingColors.rising),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Finish setup',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${missing.length} left',
                  style: TextStyle(
                    fontSize: 13,
                    color: BlockingColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final permission in missing)
            Row(
              children: [
                Glyph(
                  permissionGlyph(permission),
                  size: 20,
                  color: BlockingColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    permissionTitle(permission),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                TextButton(
                  key: ValueKey('today-allow-${permission.name}'),
                  onPressed: () => onAllow(permission),
                  child: const Text('Allow'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.usage,
    required this.topApp,
    required this.onTap,
  });

  final TodayUsage usage;
  final String? topApp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = usage.today.total;
    final yesterday = usage.yesterday;
    final difference = total - yesterday;
    final opens = usage.today.opens;
    final topApp = this.topApp;
    final Widget? change;
    if (yesterday == Duration.zero) {
      change = null;
    } else if (difference.inMinutes.abs() < 5) {
      change = _Change(
        glyph: null,
        label: 'Same as yesterday',
        color: BlockingColors.textMuted,
      );
    } else if (difference.isNegative) {
      change = _Change(
        glyph: Glyphs.arrowDown,
        label: _delta(difference),
        semantics: '${_delta(difference)} less than yesterday',
        color: BlockingColors.falling,
      );
    } else {
      change = _Change(
        glyph: Glyphs.arrowUp,
        label: _delta(difference),
        semantics: '${_delta(difference)} more than yesterday',
        color: BlockingColors.rising,
      );
    }
    return SoftCard(
      key: const ValueKey('today-usage'),
      onTap: onTap,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screen time',
            style: TextStyle(fontSize: 14, color: BlockingColors.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                ruleDuration(total),
                style: const TextStyle(
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1.6,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              ?change,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Glyph(Glyphs.launch, size: 18, color: BlockingColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '$opens',
                style: TextStyle(fontSize: 14, color: BlockingColors.textMuted),
                semanticsLabel: '$opens opens',
              ),
              if (topApp != null) ...[
                const SizedBox(width: 18),
                Glyph(Glyphs.apps, size: 18, color: BlockingColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    topApp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: BlockingColors.textMuted,
                    ),
                    semanticsLabel: 'Mostly $topApp',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({
    required this.glyph,
    required this.label,
    required this.color,
    this.semantics,
  });

  final Glyphs? glyph;
  final String label;
  final Color color;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final glyph = this.glyph;
    return Container(
      key: const ValueKey('today-change'),
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Glyph(glyph, size: 14, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            semanticsLabel: semantics,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.actionKey,
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final String actionKey;
  final Glyphs glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('today-action-$actionKey'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BlockingColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Glyph(glyph, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockLine extends StatelessWidget {
  const _BlockLine({required this.rule, required this.now});

  final BlockRule rule;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Glyph(triggerGlyph(rule.trigger), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              rule.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(
            label: ruleStatusShort(rule, now),
            active: blockingNow(rule, now),
          ),
        ],
      ),
    );
  }
}
