import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/blocking_engine.dart';
import '../blocking/rule.dart';
import '../blocking/rule_store.dart';
import 'pomodoro_session.dart';
import 'pomodoro_store.dart';
import 'timer_dial.dart';

class PomodoroTab extends StatefulWidget {
  const PomodoroTab({
    super.key,
    required this.ruleStore,
    required this.blockingService,
    required this.pomodoroStore,
  });

  final RuleStore ruleStore;
  final BlockingService blockingService;
  final PomodoroStore pomodoroStore;

  @override
  State<PomodoroTab> createState() => _PomodoroTabState();
}

class _PomodoroTabState extends State<PomodoroTab> with WidgetsBindingObserver {
  PomodoroSettings _settings = const PomodoroSettings();
  PomodoroSession? _session;
  List<BlockRule>? _rules;
  Set<int> _selected = <int>{};
  Timer? _ticker;

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
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.pomodoroStore.readSettings();
    final session = await widget.pomodoroStore.readSession();
    final rules = await widget.ruleStore.readAll();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _session = session;
      _rules = rules;
      _selected = session?.ruleIds ?? _selected;
    });
    _syncTicker();
  }

  void _syncTicker() {
    final counting = switch (_session?.stateAt(DateTime.now()).phase) {
      PomodoroPhase.focus ||
      PomodoroPhase.shortBreak ||
      PomodoroPhase.longBreak => true,
      _ => false,
    };
    if (counting) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(_syncTicker);
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _write(PomodoroSession? session) async {
    await widget.pomodoroStore.writeSession(session);
    await widget.blockingService.sync(widget.ruleStore);
    if (!mounted) return;
    setState(() => _session = session);
    _syncTicker();
  }

  Future<void> _start() async {
    await widget.pomodoroStore.writeSettings(_settings);
    await _write(
      PomodoroSession(
        settings: _settings,
        ruleIds: _selected,
        round: 1,
        focusStartedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _confirmEnd() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End the session?'),
        content: const Text('Blocked apps open again right away.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            key: const ValueKey('pomodoro-end-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (end ?? false) await _write(null);
  }

  void _updateSettings(PomodoroSettings settings) {
    setState(() => _settings = settings);
    unawaited(widget.pomodoroStore.writeSettings(settings));
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    if (rules == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final session = _session;
    if (session == null) {
      return _Setup(
        settings: _settings,
        rules: rules,
        selected: _selected,
        onSettings: _updateSettings,
        onSelect: (id, selected) => setState(() {
          selected ? _selected.add(id) : _selected.remove(id);
        }),
        onStart: () => unawaited(_start()),
      );
    }
    final now = DateTime.now();
    final state = session.stateAt(now);
    final names = [
      for (final rule in rules)
        if (session.ruleIds.contains(rule.id)) rule.name,
    ];
    return switch (state.phase) {
      PomodoroPhase.focus ||
      PomodoroPhase.shortBreak ||
      PomodoroPhase.longBreak => _Running(
        session: session,
        state: state,
        blockNames: names,
        onEnd: () => unawaited(_confirmEnd()),
      ),
      PomodoroPhase.waiting => _Message(
        fraction: 0,
        title: 'Break over',
        body:
            'Round ${session.round + 1} of ${session.settings.rounds} is next.',
        primary: (
          'Start round ${session.round + 1}',
          () => unawaited(_write(session.nextRound(DateTime.now()))),
        ),
        onEnd: () => unawaited(_confirmEnd()),
      ),
      PomodoroPhase.finished => _Message(
        fraction: 1,
        title: 'Session complete',
        body: '${session.settings.rounds} rounds of focus done.',
        primary: ('Done', () => unawaited(_write(null))),
      ),
    };
  }
}

class _Setup extends StatelessWidget {
  const _Setup({
    required this.settings,
    required this.rules,
    required this.selected,
    required this.onSettings,
    required this.onSelect,
    required this.onStart,
  });

  final PomodoroSettings settings;
  final List<BlockRule> rules;
  final Set<int> selected;
  final ValueChanged<PomodoroSettings> onSettings;
  final void Function(int id, bool selected) onSelect;
  final VoidCallback onStart;

  // One turn of the dial is an hour; the arc snaps to five-minute steps.
  void _setFocus(double fraction) {
    final current = settings.focus.inMinutes;
    var minutes = (fraction * 60 / 5).round() * 5;
    // Dragging across twelve o'clock pins to the nearer end.
    if (current >= 45 && minutes <= 10) minutes = 60;
    if (current <= 15 && minutes >= 50) minutes = 5;
    onSettings(
      settings.copyWith(focus: Duration(minutes: minutes.clamp(5, 60))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Center(
          child: TimerDial(
            fraction: settings.focus.inMinutes / 60,
            color: BlockingColors.accent,
            onFractionChanged: _setFocus,
            child: _DialCenter(
              clock: '${settings.focus.inMinutes}:00',
              label: 'Focus',
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _Stepper(
                label: 'Break',
                value: '${settings.shortBreak.inMinutes} min',
                onLess: settings.shortBreak.inMinutes > 1
                    ? () => onSettings(
                        settings.copyWith(
                          shortBreak:
                              settings.shortBreak - const Duration(minutes: 1),
                        ),
                      )
                    : null,
                onMore: settings.shortBreak.inMinutes < 30
                    ? () => onSettings(
                        settings.copyWith(
                          shortBreak:
                              settings.shortBreak + const Duration(minutes: 1),
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: _Stepper(
                label: 'Long break',
                value: '${settings.longBreak.inMinutes} min',
                onLess: settings.longBreak.inMinutes > 5
                    ? () => onSettings(
                        settings.copyWith(
                          longBreak:
                              settings.longBreak - const Duration(minutes: 5),
                        ),
                      )
                    : null,
                onMore: settings.longBreak.inMinutes < 60
                    ? () => onSettings(
                        settings.copyWith(
                          longBreak:
                              settings.longBreak + const Duration(minutes: 5),
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: _Stepper(
                label: 'Rounds',
                value: '${settings.rounds}',
                onLess: settings.rounds > 1
                    ? () => onSettings(
                        settings.copyWith(rounds: settings.rounds - 1),
                      )
                    : null,
                onMore: settings.rounds < 8
                    ? () => onSettings(
                        settings.copyWith(rounds: settings.rounds + 1),
                      )
                    : null,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 28, 0, 10),
          child: Text('Blocked during focus', style: sectionLabel),
        ),
        if (rules.isEmpty)
          const Text(
            'No blocks yet. The timer still runs.',
            style: TextStyle(color: BlockingColors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rule in rules)
                FilterChip(
                  key: ValueKey('pomodoro-block-${rule.id}'),
                  label: Text(rule.name),
                  selected: selected.contains(rule.id),
                  onSelected: (value) => onSelect(rule.id, value),
                  showCheckmark: false,
                  selectedColor: BlockingColors.accent,
                  backgroundColor: BlockingColors.surface,
                  labelStyle: TextStyle(
                    color: selected.contains(rule.id)
                        ? BlockingColors.onAccent
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected.contains(rule.id)
                        ? BlockingColors.accent
                        : BlockingColors.outline,
                  ),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        const SizedBox(height: 32),
        FilledButton(
          key: const ValueKey('pomodoro-primary'),
          onPressed: onStart,
          child: const Text('Start focus'),
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({
    required this.session,
    required this.state,
    required this.blockNames,
    required this.onEnd,
  });

  final PomodoroSession session;
  final PomodoroState state;
  final List<String> blockNames;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final focusing = state.phase == PomodoroPhase.focus;
    final seconds = (state.remaining.inMilliseconds / 1000).ceil();
    final blocking = blockNames.isEmpty
        ? 'Timer only'
        : focusing
        ? 'Blocking ${blockNames.join(', ')}'
        : 'Blocks released';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: TimerDial(
              fraction:
                  state.remaining.inMilliseconds / state.length.inMilliseconds,
              color: focusing
                  ? BlockingColors.accent
                  : BlockingColors.textMuted,
              child: _DialCenter(
                clock:
                    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                label: switch (state.phase) {
                  PomodoroPhase.focus => 'Focus',
                  PomodoroPhase.longBreak => 'Long break',
                  _ => 'Break',
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var round = 1; round <= session.settings.rounds; round++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          round < session.round ||
                              (round == session.round && !focusing)
                          ? BlockingColors.accent
                          : Colors.transparent,
                      border: Border.all(
                        color: round == session.round
                            ? BlockingColors.accent
                            : BlockingColors.outline,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                'Round ${session.round} of ${session.settings.rounds}',
                style: const TextStyle(
                  fontSize: 14,
                  color: BlockingColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            blocking,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: BlockingColors.textMuted,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            key: const ValueKey('pomodoro-end'),
            onPressed: onEnd,
            child: const Text('End session'),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.fraction,
    required this.title,
    required this.body,
    required this.primary,
    this.onEnd,
  });

  final double fraction;
  final String title;
  final String body;
  final (String, VoidCallback) primary;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final onEnd = this.onEnd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: TimerDial(
              fraction: fraction,
              color: BlockingColors.accent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: BlockingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            key: const ValueKey('pomodoro-primary'),
            onPressed: primary.$2,
            child: Text(primary.$1),
          ),
          if (onEnd != null)
            TextButton(
              key: const ValueKey('pomodoro-end'),
              onPressed: onEnd,
              style: TextButton.styleFrom(
                foregroundColor: BlockingColors.textMuted,
              ),
              child: const Text('End session'),
            ),
        ],
      ),
    );
  }
}

class _DialCenter extends StatelessWidget {
  const _DialCenter({required this.clock, required this.label});

  final String clock;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clock,
          key: const ValueKey('pomodoro-clock'),
          style: const TextStyle(
            fontSize: 60,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: BlockingColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onLess,
    required this.onMore,
  });

  final String label;
  final String value;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: BlockingColors.textMuted),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              IconButton(
                key: ValueKey('less-$label'),
                onPressed: onLess,
                icon: const Icon(Icons.remove, size: 18),
                color: BlockingColors.accent,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('more-$label'),
                onPressed: onMore,
                icon: const Icon(Icons.add, size: 18),
                color: BlockingColors.accent,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
