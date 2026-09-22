import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/blocking_engine.dart';
import '../blocking/rule.dart';
import '../blocking/rule_store.dart';
import '../blocking/widgets/note.dart';
import '../pomodoro/timer_dial.dart';
import 'strict_mode.dart';
import 'strict_mode_store.dart';
import 'uninstall_guard.dart';

const _caveat =
    'Nothing here stops Safe mode or a computer with developer tools.';
const _adminRefused =
    'Blocking uninstalls needs SerenSync as a device admin. Allow it, or '
    'leave that lock off.';
const _minTimer = Duration(minutes: 5);
const _maxLength = Duration(days: 99);
const _quickTimers = <Duration>[
  Duration(hours: 1),
  Duration(hours: 3),
  Duration(hours: 8),
  Duration(days: 1),
  Duration(days: 3),
  Duration(days: 7),
];
const _quickCooldowns = <Duration>[
  Duration.zero,
  Duration(minutes: 10),
  Duration(hours: 1),
  Duration(days: 1),
];
const _pageTurn = Duration(milliseconds: 320);

/// The setup walks through these; the timer and PIN steps are exclusive.
enum _Step { end, timer, pin, cooldown, locks, review }

class StrictTab extends StatefulWidget {
  const StrictTab({
    super.key,
    required this.ruleStore,
    required this.blockingService,
    required this.strictModeStore,
    required this.onChanged,
    this.uninstallGuard,
  });

  final RuleStore ruleStore;
  final BlockingService blockingService;
  final StrictModeStore strictModeStore;

  /// Called after strict mode starts, changes or ends, so the rest of the app
  /// can pick up the new locks.
  final VoidCallback onChanged;

  /// Defaults to the device administrator; tests inject a fake.
  final UninstallGuard? uninstallGuard;

  @override
  State<StrictTab> createState() => _StrictTabState();
}

class _StrictTabState extends State<StrictTab> with WidgetsBindingObserver {
  late final UninstallGuard _uninstallGuard =
      widget.uninstallGuard ?? UninstallGuard();
  final PageController _pages = PageController();
  final Set<StrictLock> _locks = {};
  bool _timed = true;
  Duration _timerLength = const Duration(hours: 1);
  Duration _cooldown = Duration.zero;
  String _pinEntry = '';
  String? _pinFirst;
  String? _pin;
  bool _pinMismatch = false;
  int _stepIndex = 0;
  String? _message;
  bool _loaded = false;
  StrictMode? _strict;
  bool _emergencyUsed = false;
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
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final strict = await widget.strictModeStore.read();
    final emergencyUsed = await widget.strictModeStore.emergencyUsed;
    if (!mounted) return;
    setState(() {
      _strict = strict;
      _emergencyUsed = emergencyUsed;
      _loaded = true;
    });
    _syncTicker();
  }

  bool get _counting {
    final strict = _strict;
    if (strict == null) return false;
    final now = DateTime.now();
    if (strict.timed) return now.isBefore(strict.until!);
    return strict.unlockRequestedAt != null &&
        cooldownRemaining(strict, now)! > Duration.zero;
  }

  // Countdowns for the timer and the cooldown redraw once a second, until
  // the last one runs out.
  void _syncTicker() {
    if (_counting) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_counting) {
          _ticker?.cancel();
          _ticker = null;
        }
        setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  List<_Step> get _steps => [
    _Step.end,
    if (_timed) _Step.timer,
    if (!_timed) ...[_Step.pin, _Step.cooldown],
    _Step.locks,
    _Step.review,
  ];

  Duration? get _cooldownOrNull =>
      !_timed && _cooldown > Duration.zero ? _cooldown : null;

  Set<StrictLock> get _effectiveLocks =>
      effectiveLocks(_locks, timed: _timed, cooldown: _cooldownOrNull);

  /// Settings would be locked even without being chosen.
  bool get _settingsForced => effectiveLocks(
    _locks.difference({StrictLock.settings}),
    timed: _timed,
    cooldown: _cooldownOrNull,
  ).contains(StrictLock.settings);

  /// Wording for [_settingsForced], in the order the model checks.
  List<String> get _forcedSettingsCauses => [
    if (_timed) 'the timer',
    if (_cooldownOrNull != null) 'the cooldown',
    if (_locks.contains(StrictLock.uninstall)) 'the uninstall lock',
    if (_locks.contains(StrictLock.newApps)) 'the new-apps lock',
  ];

  bool get _pinReady =>
      _pinEntry.length >= 4 ||
      (_pin != null && _pinFirst == null && _pinEntry.isEmpty);

  void _goTo(int index) {
    setState(() => _stepIndex = index);
    unawaited(
      _pages.animateToPage(
        index,
        duration: _duration(context, _pageTurn.inMilliseconds),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _next() {
    if (_steps[_stepIndex] == _Step.pin && !_confirmPin()) return;
    _goTo(_stepIndex + 1);
  }

  /// First pass stores the entry, second pass has to match it.
  bool _confirmPin() {
    if (_pinEntry.isEmpty && _pin != null) return true;
    final first = _pinFirst;
    if (first == null) {
      setState(() {
        _pinFirst = _pinEntry;
        _pinEntry = '';
        _pinMismatch = false;
      });
      return false;
    }
    if (first == _pinEntry) {
      setState(() {
        _pin = first;
        _pinFirst = null;
        _pinEntry = '';
      });
      return true;
    }
    setState(() {
      _pinFirst = null;
      _pinEntry = '';
      _pinMismatch = true;
    });
    return false;
  }

  void _back() {
    setState(() {
      _pinFirst = null;
      _pinEntry = '';
      _pinMismatch = false;
    });
    _goTo(_stepIndex - 1);
  }

  Future<void> _write(StrictMode? strict) async {
    final previous = _strict;
    await widget.strictModeStore.write(strict);
    if (strict == null &&
        (previous?.locks.contains(StrictLock.uninstall) ?? false)) {
      await _uninstallGuard.deactivate();
    }
    await widget.blockingService.sync(widget.ruleStore);
    widget.onChanged();
    if (!mounted) return;
    setState(() {
      _strict = strict;
      _message = null;
    });
    _syncTicker();
  }

  Future<void> _activate() async {
    final locks = _effectiveLocks;
    if (locks.contains(StrictLock.uninstall) &&
        !await _uninstallGuard.activate()) {
      if (mounted) setState(() => _message = _adminRefused);
      return;
    }
    final now = DateTime.now();
    await _write(
      StrictMode(
        locks: locks,
        activatedAt: now,
        until: _timed ? now.add(_timerLength) : null,
        pin: _timed ? null : PinHash.create(_pin!, Random.secure()),
        cooldown: _cooldownOrNull,
      ),
    );
    if (!mounted) return;
    setState(() {
      _pin = null;
      _stepIndex = 0;
    });
    _pages.jumpToPage(0);
  }

  /// Locks can only be added while strict mode runs, so each one is confirmed.
  Future<void> _addLock(StrictMode strict, StrictLock lock) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmLock(lock),
    );
    if (!(confirmed ?? false) || !mounted) return;
    if (lock == StrictLock.uninstall && !await _uninstallGuard.activate()) {
      if (mounted) setState(() => _message = _adminRefused);
      return;
    }
    await _write(
      strict.withLocks(
        effectiveLocks(
          {...strict.locks, lock},
          timed: strict.timed,
          cooldown: strict.cooldown,
        ),
      ),
    );
  }

  Future<void> _unlock(StrictMode strict) async {
    final pin = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _PinSheet(),
    );
    if (pin == null || !mounted) return;
    if (strict.pin!.matches(pin)) {
      await _write(null);
    } else {
      setState(() => _message = 'That PIN is wrong.');
    }
  }

  Future<void> _emergency() async {
    if (!_emergencyUsed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _EmergencyQuestions(),
      );
      if (!(confirmed ?? false) || !mounted) return;
      await widget.strictModeStore.markEmergencyUsed();
      _emergencyUsed = true;
      await _write(null);
      return;
    }
    final text = emergencyText(Random.secure());
    final typed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RetypeDialog(text: text),
    );
    if ((typed ?? false) && mounted) await _write(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final strict = _strict;
    final now = DateTime.now();
    if (strict == null) return _flow();
    if (strictModeEnded(strict, now)) {
      return _Entrance(key: const ValueKey('ended'), child: _ended(strict));
    }
    return _Entrance(
      key: const ValueKey('active'),
      child: _active(strict, now),
    );
  }

  Widget _flow() {
    final steps = _steps;
    return PopScope(
      canPop: _stepIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Column(
        children: [
          _Progress(step: _stepIndex, total: steps.length),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              itemBuilder: (_, index) => _page(steps[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(_Step step) {
    final now = DateTime.now();
    final l10n = MaterialLocalizations.of(context);
    return switch (step) {
      _Step.end => _StepPage(
        title: 'How will it end?',
        body: 'Your blocks stay locked until then.',
        footer: _PlanLine(_planSentence(now, l10n)),
        primaryLabel: 'Continue',
        onPrimary: _next,
        children: [
          _Stagger(
            index: 0,
            child: _OptionCard(
              key: const ValueKey('strict-end-timer'),
              icon: Icons.timer_outlined,
              title: 'Timer',
              detail: 'Ends by itself. Nothing ends it earlier.',
              selected: _timed,
              onTap: () => setState(() => _timed = true),
            ),
          ),
          _Stagger(
            index: 1,
            child: _OptionCard(
              key: const ValueKey('strict-end-pin'),
              icon: Icons.key_outlined,
              title: 'PIN',
              detail: 'Ends with a PIN. Give it to someone you trust.',
              selected: !_timed,
              onTap: () => setState(() => _timed = false),
            ),
          ),
        ],
      ),
      _Step.timer => _StepPage(
        title: 'For how long?',
        footer: _PlanLine(
          'Ends ${_untilLabel(now.add(_timerLength), now, l10n)}.',
        ),
        primaryLabel: 'Continue',
        onPrimary: _next,
        onBack: _back,
        children: [
          _BigLength(_lengthLabel(_timerLength)),
          const SizedBox(height: 16),
          _DurationWheels(
            keyPrefix: 'strict-timer',
            value: _timerLength,
            minimum: _minTimer,
            onChanged: (length) => setState(() => _timerLength = length),
          ),
          const SizedBox(height: 16),
          _QuickPicks(
            keyPrefix: 'strict-quick',
            options: _quickTimers,
            value: _timerLength,
            onChanged: (length) => setState(() => _timerLength = length),
          ),
        ],
      ),
      _Step.pin => _StepPage(
        title: _pinFirst == null ? 'Choose a PIN' : 'Confirm your PIN',
        body: _pinFirst == null
            ? 'Four to eight digits. Someone you trust should keep it.'
            : null,
        primaryLabel: 'Continue',
        onPrimary: _pinReady ? _next : null,
        onBack: _back,
        children: [
          const SizedBox(height: 8),
          _PinDots(
            digits: _pinEntry,
            mismatch: _pinMismatch,
            message: _pinMismatch
                ? 'Those did not match. Start again.'
                : _pin != null && _pinFirst == null && _pinEntry.isEmpty
                ? 'PIN set. Type a new one to change it.'
                : null,
          ),
          const SizedBox(height: 8),
          _Keypad(
            digits: _pinEntry,
            onChanged: (digits) => setState(() {
              _pinEntry = digits;
              _pinMismatch = false;
            }),
          ),
        ],
      ),
      _Step.cooldown => _StepPage(
        title: 'Wait before unlocking?',
        body: 'The PIN only counts this long after you ask to unlock.',
        footer: _PlanLine(
          _cooldown == Duration.zero
              ? 'No wait. The PIN unlocks at once.'
              : 'Unlocking waits ${_lengthLabel(_cooldown)} after you ask.',
        ),
        primaryLabel: 'Continue',
        onPrimary: _next,
        onBack: _back,
        children: [
          _BigLength(_cooldownLabel(_cooldown)),
          const SizedBox(height: 16),
          _DurationWheels(
            keyPrefix: 'strict-cooldown',
            value: _cooldown,
            minimum: Duration.zero,
            onChanged: (length) => setState(() => _cooldown = length),
          ),
          const SizedBox(height: 16),
          _QuickPicks(
            keyPrefix: 'strict-cool',
            options: _quickCooldowns,
            value: _cooldown,
            label: _cooldownLabel,
            onChanged: (length) => setState(() => _cooldown = length),
          ),
        ],
      ),
      _Step.locks => _StepPage(
        title: 'What stays locked?',
        body:
            'Your blocks are locked either way. These can be added later, '
            'never removed.',
        primaryLabel: 'Continue',
        onPrimary: _next,
        onBack: _back,
        children: [
          _Dial(
            size: 150,
            fraction: _effectiveLocks.length / StrictLock.values.length,
            color: BlockingColors.accent,
            child: _GlyphCenter(
              label: '${_effectiveLocks.length} of ${StrictLock.values.length}',
            ),
          ),
          const SizedBox(height: 20),
          for (final (index, lock) in StrictLock.values.indexed)
            _Stagger(
              index: index,
              child: lock == StrictLock.settings && _settingsForced
                  ? _lockCard(
                      lock,
                      on: true,
                      detail: 'Kept on by ${_join(_forcedSettingsCauses)}.',
                      onChanged: null,
                    )
                  : _lockCard(
                      lock,
                      on: _effectiveLocks.contains(lock),
                      onChanged: (on) => setState(() {
                        on ? _locks.add(lock) : _locks.remove(lock);
                      }),
                    ),
            ),
        ],
      ),
      _Step.review => _StepPage(
        title: _timed
            ? 'Lock for ${_lengthLabel(_timerLength)}?'
            : 'Lock until the PIN?',
        body: 'Undoing this is meant to be hard.',
        primaryKey: const ValueKey('strict-activate'),
        primaryLabel: _timed
            ? 'Lock for ${_lengthLabel(_timerLength)}'
            : 'Lock now',
        onPrimary: () => unawaited(_activate()),
        onBack: _back,
        children: [
          _Dial(
            size: 150,
            fraction: 1,
            color: BlockingColors.accent,
            child: _GlyphCenter(
              label: _timed ? _lengthLabel(_timerLength) : 'Until the PIN',
            ),
          ),
          const SizedBox(height: 20),
          _Card(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final fact in _reviewFacts(now, l10n)) _FactRow(fact),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Note(message: _caveat),
          if (_message case final message?) ...[
            const SizedBox(height: 14),
            Note(
              icon: Icons.error_outline,
              iconColor: BlockingColors.rising,
              message: message,
            ),
          ],
        ],
      ),
    };
  }

  Widget _lockCard(
    StrictLock lock, {
    required bool on,
    required ValueChanged<bool>? onChanged,
    String? detail,
  }) {
    return _ToggleCard(
      switchKey: ValueKey('strict-lock-${lock.name}'),
      icon: _lockIcon(lock),
      title: _lockTitle(lock),
      detail: detail ?? _lockDetail(lock),
      value: on,
      onChanged: onChanged,
    );
  }

  List<_Fact> _reviewFacts(DateTime now, MaterialLocalizations l10n) {
    final locks = _effectiveLocks;
    final cooldown = _cooldownOrNull;
    return [
      (
        icon: Icons.event,
        eyebrow: 'Ends',
        value: _timed
            ? '${_untilLabel(now.add(_timerLength), now, l10n)}. Nothing '
                  'ends it earlier.'
            : cooldown == null
            ? 'When the PIN is entered.'
            : 'When the PIN is entered, ${_lengthLabel(cooldown)} after you '
                  'ask to unlock.',
      ),
      (
        icon: Icons.lock_outline,
        eyebrow: 'Locked',
        value: [
          'Your blocks',
          for (final lock in StrictLock.values)
            if (locks.contains(lock))
              lock == StrictLock.settings && _settingsForced
                  ? '${_lockTitle(lock)} (kept on)'
                  : _lockTitle(lock),
        ].join(' · '),
      ),
      if (locks.contains(StrictLock.uninstall))
        (
          icon: Icons.admin_panel_settings_outlined,
          eyebrow: 'Device admin',
          value:
              'Android will ask for it. Allow it, or the lock does not '
              'start.',
        ),
      (
        icon: Icons.health_and_safety_outlined,
        eyebrow: 'Emergency exit',
        value: _emergencyUsed
            ? 'Means retyping $emergencyTextLength random characters.'
            : 'Once, after three questions. Then it means retyping '
                  '$emergencyTextLength random characters.',
      ),
    ];
  }

  /// The commitment in words; the review page shows the same text.
  String _planSentence(DateTime now, MaterialLocalizations l10n) {
    if (_timed) {
      return 'Locks for ${_lengthLabel(_timerLength)}, until '
          '${_untilLabel(now.add(_timerLength), now, l10n)}. Ends on its own.';
    }
    final cooldown = _cooldownOrNull;
    return cooldown == null
        ? 'Locks until the PIN is entered.'
        : 'Locks until the PIN is entered, ${_lengthLabel(cooldown)} after '
              'you ask to unlock.';
  }

  Widget _active(StrictMode strict, DateTime now) {
    final l10n = MaterialLocalizations.of(context);
    final remaining = cooldownRemaining(strict, now);
    final pending =
        strict.unlockRequestedAt != null &&
        remaining != null &&
        remaining > Duration.zero;
    final ready = remaining == null || remaining == Duration.zero;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Eyebrow('Strict mode is on'),
                _activeDial(strict, now, l10n, pending: pending, ready: ready),
                const SizedBox(height: 28),
                const _Eyebrow('Side doors', centred: false),
                const SizedBox(height: 10),
                for (final lock in StrictLock.values)
                  if (strict.locks.contains(lock))
                    _lockCard(lock, on: true, onChanged: null)
                  else
                    _lockCard(
                      lock,
                      on: false,
                      onChanged: (_) => unawaited(_addLock(strict, lock)),
                    ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('strict-emergency'),
                  onPressed: () => unawaited(_emergency()),
                  style: TextButton.styleFrom(
                    foregroundColor: BlockingColors.textMuted,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Emergency unlock'),
                ),
              ],
            ),
          ),
        ),
        if (!strict.timed || _message != null)
          _StickyBar(
            children: [
              if (_message case final message?)
                Note(
                  icon: Icons.error_outline,
                  iconColor: BlockingColors.rising,
                  message: message,
                ),
              if (!strict.timed && pending)
                OutlinedButton(
                  key: const ValueKey('strict-cancel-unlock'),
                  onPressed: () =>
                      unawaited(_write(strict.withUnlockRequest(null))),
                  child: const Text('Cancel request'),
                )
              else if (!strict.timed)
                OutlinedButton(
                  key: const ValueKey('strict-unlock'),
                  onPressed: () => unawaited(
                    ready
                        ? _unlock(strict)
                        : _write(strict.withUnlockRequest(now)),
                  ),
                  child: Text(ready ? 'Unlock' : 'Request unlock'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _activeDial(
    StrictMode strict,
    DateTime now,
    MaterialLocalizations l10n, {
    required bool pending,
    required bool ready,
  }) {
    if (pending) {
      final remaining = cooldownRemaining(strict, now)!;
      final opensAt = strict.unlockRequestedAt!.add(strict.cooldown!);
      return _Dial(
        size: 240,
        fraction: remaining.inMilliseconds / strict.cooldown!.inMilliseconds,
        color: BlockingColors.textMuted,
        semanticsLabel:
            'Unlock opens in ${_clock(remaining)}, at ${ruleTime(_minuteOfDay(opensAt))}',
        child: _RingCenter(
          big: ruleTime(_minuteOfDay(opensAt)),
          small: 'Unlock opens in ${_clock(remaining)}',
          footnote: _sameDay(opensAt, now)
              ? null
              : _untilLabel(opensAt, now, l10n),
        ),
      );
    }
    if (strict.timed) {
      final until = strict.until!;
      final remaining = until.difference(now);
      return _Dial(
        size: 240,
        fraction:
            remaining.inMilliseconds /
            until.difference(strict.activatedAt).inMilliseconds,
        color: BlockingColors.accent,
        semanticsLabel:
            'Ends in ${_remainingLabel(remaining)}, at ${ruleTime(_minuteOfDay(until))}',
        child: _RingCenter(
          big: _remainingLabel(remaining),
          small: 'until ${_untilLabel(until, now, l10n)}',
        ),
      );
    }
    final cooldown = strict.cooldown;
    return _Dial(
      size: 240,
      fraction: 1,
      color: BlockingColors.accent,
      semanticsLabel: 'Locked',
      child: _GlyphCenter(
        label: ready && strict.unlockRequestedAt != null
            ? 'Unlock is open'
            : cooldown == null
            ? 'Until the PIN'
            : 'PIN after a ${_lengthLabel(cooldown)} wait',
        size: const Size(40, 46),
        labelSize: 15,
      ),
    );
  }

  Widget _ended(StrictMode strict) {
    final held = strict.until!.difference(strict.activatedAt);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Dial(
                    size: 200,
                    fraction: 1,
                    color: BlockingColors.accent,
                    semanticsLabel: 'Strict mode has ended',
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: _duration(context, 400),
                      curve: Easing.emphasizedDecelerate,
                      builder: (_, open, _) => _LockGlyph(
                        open: open,
                        color: BlockingColors.accent,
                        size: const Size(44, 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Strict mode has ended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You held it for ${_lengthLabel(held)}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: BlockingColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StickyBar(
          children: [
            FilledButton(
              key: const ValueKey('strict-done'),
              onPressed: () => unawaited(_write(null)),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}

typedef _Fact = ({IconData icon, String eyebrow, String value});

String _lockTitle(StrictLock lock) {
  return switch (lock) {
    StrictLock.settings => 'Block device settings',
    StrictLock.uninstall => 'Block uninstalling',
    StrictLock.recents => 'Block recent apps',
    StrictLock.newApps => 'Block new apps',
  };
}

IconData _lockIcon(StrictLock lock) {
  return switch (lock) {
    StrictLock.settings => Icons.settings_outlined,
    StrictLock.uninstall => Icons.admin_panel_settings_outlined,
    StrictLock.recents => Icons.view_carousel_outlined,
    StrictLock.newApps => Icons.download_outlined,
  };
}

String _lockDetail(StrictLock lock) {
  return switch (lock) {
    StrictLock.settings => 'The Settings app is blocked.',
    StrictLock.uninstall =>
      'SerenSync cannot be uninstalled. Needs device admin.',
    StrictLock.recents => 'The recent apps screen is blocked.',
    StrictLock.newApps => 'Apps installed from now on are blocked.',
  };
}

/// "3 hours", "1 day 4 h", "2 h 30 min", "45 min".
String _lengthLabel(Duration length) {
  final days = length.inDays;
  final hours = length.inHours.remainder(24);
  final minutes = length.inMinutes.remainder(60);
  final wholeHours = days == 0 && minutes == 0;
  final parts = [
    if (days > 0) days == 1 ? '1 day' : '$days days',
    if (hours > 0)
      wholeHours ? (hours == 1 ? '1 hour' : '$hours hours') : '$hours h',
    if (minutes > 0) '$minutes min',
  ];
  return parts.isEmpty ? '0 min' : parts.join(' ');
}

String _cooldownLabel(Duration length) =>
    length == Duration.zero ? 'None' : _lengthLabel(length);

String _remainingLabel(Duration remaining) {
  final minutes = Duration(minutes: (remaining.inSeconds / 60).ceil());
  if (minutes.inDays >= 1) {
    return '${minutes.inDays}d ${minutes.inHours.remainder(24)}h';
  }
  return ruleDuration(minutes);
}

String _clock(Duration duration) {
  final seconds = (duration.inMilliseconds / 1000).ceil();
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}

int _minuteOfDay(DateTime time) => time.hour * 60 + time.minute;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _untilLabel(DateTime until, DateTime now, MaterialLocalizations l10n) {
  final time = ruleTime(_minuteOfDay(until));
  if (_sameDay(until, now)) return 'today at $time';
  if (_sameDay(until, now.add(const Duration(days: 1)))) {
    return 'tomorrow at $time';
  }
  return '${l10n.formatMediumDate(until)} at $time';
}

String _join(List<String> parts) {
  return switch (parts.length) {
    1 => parts.single,
    2 => '${parts.first} and ${parts.last}',
    _ => '${parts.take(parts.length - 1).join(', ')}, and ${parts.last}',
  };
}

Duration _duration(BuildContext context, int milliseconds) {
  return MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

/// Dialog actions sit in a row, so they are smaller than the page buttons.
final _dialogAction = FilledButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
);

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: _duration(context, 250),
                height: 3,
                decoration: BoxDecoration(
                  color: index <= step
                      ? BlockingColors.accent
                      : BlockingColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (index < total - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

/// Everything scrolls except the actions pinned underneath, so no step can
/// outgrow the screen.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.title,
    this.body,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey = const ValueKey('strict-next'),
    this.onBack,
    this.footer,
  });

  final String title;
  final String? body;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key primaryKey;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  if (body case final body?) ...[
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: BlockingColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
          ),
          if (footer case final footer?) ...[
            const SizedBox(height: 10),
            footer,
          ],
          const SizedBox(height: 10),
          FilledButton(
            key: primaryKey,
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
          if (onBack != null)
            TextButton(
              key: const ValueKey('strict-back'),
              onPressed: onBack,
              style: TextButton.styleFrom(
                foregroundColor: BlockingColors.textMuted,
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('Back'),
            ),
        ],
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _duration(context, 150),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: BlockingColors.textMuted,
        ),
      ),
    );
  }
}

/// The chosen length, large, swapping as the wheels move.
class _BigLength extends StatelessWidget {
  const _BigLength(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: AnimatedSwitcher(
        duration: _duration(context, 150),
        child: _FitText(
          text,
          key: ValueKey(text),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

/// A single line that shrinks rather than wraps or overflows.
class _FitText extends StatelessWidget {
  const _FitText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}

/// Lifts a list item into place shortly after the ones above it.
class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.12).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration(context, 500),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Fades and lifts a freshly shown state into place.
class _Entrance extends StatelessWidget {
  const _Entrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration(context, 210),
      curve: Easing.emphasizedDecelerate,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? BlockingColors.accent : BlockingColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BlockingColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: BlockingColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Badge(icon: icon, tint: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: _CardText(title: title, detail: detail),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: _duration(context, 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected
                        ? BlockingColors.accent
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? BlockingColors.accent
                          : BlockingColors.outline,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: BlockingColors.onAccent,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Without [onChanged] the switch shows as locked in place.
class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    final tint = value ? BlockingColors.accent : BlockingColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BlockingColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: BlockingColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                _Badge(icon: locked ? Icons.lock : icon, tint: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: _CardText(title: title, detail: detail),
                ),
                Switch(
                  key: switchKey,
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: BlockingColors.accent,
                  activeThumbColor: BlockingColors.onAccent,
                  inactiveTrackColor: BlockingColors.surfaceRaised,
                  inactiveThumbColor: Colors.white70,
                  trackColor: locked
                      ? WidgetStatePropertyAll(
                          BlockingColors.accent.withValues(alpha: 0.45),
                        )
                      : null,
                  thumbColor: locked
                      ? const WidgetStatePropertyAll(BlockingColors.onAccent)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const _CardText({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: BlockingColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _duration(context, 160),
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: tint),
    );
  }
}

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({
    required this.keyPrefix,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label = _lengthLabel,
  });

  final String keyPrefix;
  final List<Duration> options;
  final Duration value;
  final ValueChanged<Duration> onChanged;
  final String Function(Duration) label;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ActionChip(
            key: ValueKey('$keyPrefix-${option.inMinutes}m'),
            label: Text(label(option)),
            onPressed: () => onChanged(option),
            backgroundColor: option == value
                ? BlockingColors.accent
                : BlockingColors.surfaceRaised,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: option == value ? BlockingColors.onAccent : Colors.white,
            ),
            side: BorderSide(
              color: option == value
                  ? BlockingColors.accent
                  : BlockingColors.outline,
            ),
            shape: const StadiumBorder(),
          ),
      ],
    );
  }
}

/// Days, hours and minutes wheels, up to 99 days.
class _DurationWheels extends StatefulWidget {
  const _DurationWheels({
    required this.keyPrefix,
    required this.value,
    required this.minimum,
    required this.onChanged,
  });

  final String keyPrefix;
  final Duration value;
  final Duration minimum;
  final ValueChanged<Duration> onChanged;

  @override
  State<_DurationWheels> createState() => _DurationWheelsState();
}

class _DurationWheelsState extends State<_DurationWheels> {
  late final FixedExtentScrollController _days = FixedExtentScrollController(
    initialItem: widget.value.inDays,
  );
  late final FixedExtentScrollController _hours = FixedExtentScrollController(
    initialItem: widget.value.inHours.remainder(24),
  );
  late final FixedExtentScrollController _minutes = FixedExtentScrollController(
    initialItem: widget.value.inMinutes.remainder(60),
  );
  late int _day = widget.value.inDays;
  late int _hour = widget.value.inHours.remainder(24);
  late int _minute = widget.value.inMinutes.remainder(60);
  bool _following = false;

  @override
  void didUpdateWidget(_DurationWheels old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _follow(widget.value);
  }

  // A quick pick or a clamp moved the value; the wheels catch up. Jumping
  // fires the wheels' change callbacks synchronously, mid-build, so they are
  // muted while it happens.
  void _follow(Duration value) {
    _day = value.inDays;
    _hour = value.inHours.remainder(24);
    _minute = value.inMinutes.remainder(60);
    _following = true;
    _jump(_days, _day);
    _jump(_hours, _hour);
    _jump(_minutes, _minute);
    _following = false;
  }

  void _jump(FixedExtentScrollController controller, int item) {
    if (controller.hasClients && controller.selectedItem != item) {
      controller.jumpToItem(item);
    }
  }

  void _emit() {
    if (_following) return;
    final value = Duration(days: _day, hours: _hour, minutes: _minute);
    widget.onChanged(value < widget.minimum ? widget.minimum : value);
  }

  @override
  void dispose() {
    _days.dispose();
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Row(
        children: [
          _Wheel(
            key: ValueKey('${widget.keyPrefix}-days'),
            controller: _days,
            count: _maxLength.inDays + 1,
            unit: 'days',
            onChanged: (index) {
              _day = index;
              _emit();
            },
          ),
          _Wheel(
            key: ValueKey('${widget.keyPrefix}-hours'),
            controller: _hours,
            count: 24,
            unit: 'hours',
            onChanged: (index) {
              _hour = index;
              _emit();
            },
          ),
          _Wheel(
            key: ValueKey('${widget.keyPrefix}-minutes'),
            controller: _minutes,
            count: 60,
            unit: 'min',
            onChanged: (index) {
              _minute = index;
              _emit();
            },
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    super.key,
    required this.controller,
    required this.count,
    required this.unit,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Read outside the picker, which would otherwise impose Cupertino's type.
    final style = DefaultTextStyle.of(context).style.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Expanded(
      child: Column(
        children: [
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BlockingColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 156,
            child: CupertinoPicker(
              scrollController: controller,
              itemExtent: 44,
              squeeze: 1.2,
              useMagnifier: true,
              magnification: 1.1,
              backgroundColor: Colors.transparent,
              selectionOverlay: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: BlockingColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSelectedItemChanged: onChanged,
              children: [
                for (var index = 0; index < count; index++)
                  Center(
                    child: Text(index.toString().padLeft(2, '0'), style: style),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The padlock closes as the first four digits arrive.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.digits, this.message, this.mismatch = false});

  final String digits;
  final String? message;
  final bool mismatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 1 - min(digits.length, 4) / 4),
          duration: _duration(context, 300),
          curve: Curves.easeOutCubic,
          builder: (_, open, _) => _LockGlyph(
            open: open,
            color: BlockingColors.accent,
            size: const Size(40, 46),
          ),
        ),
        const SizedBox(height: 24),
        _Shake(
          trigger: mismatch ? 1 : 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < max(4, digits.length); index++)
                AnimatedContainer(
                  duration: _duration(context, 120),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < digits.length
                        ? BlockingColors.accent
                        : Colors.transparent,
                    border: Border.all(
                      color: index < digits.length
                          ? BlockingColors.accent
                          : BlockingColors.outline,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              message ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: mismatch
                    ? BlockingColors.rising
                    : BlockingColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Appends up to eight digits to [digits] and trims one on backspace.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.digits, required this.onChanged});

  final String digits;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: SizedBox(
            height: 54,
            child: Material(
              color: onTap == null
                  ? Colors.transparent
                  : BlockingColors.surfaceRaised,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: onTap == null
                    ? null
                    : ValueKey('strict-key-${icon == null ? label : 'back'}'),
                onTap: onTap,
                child: Center(
                  child: icon == null
                      ? Text(
                          label,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Icon(icon, size: 22, color: BlockingColors.textMuted),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void digit(String value) {
      if (digits.length < 8) onChanged(digits + value);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, onTap: () => digit(d))]),
        Row(
          children: [
            key(''),
            key('0', onTap: () => digit('0')),
            key(
              '',
              icon: Icons.backspace_outlined,
              onTap: digits.isEmpty
                  ? null
                  : () => onChanged(digits.substring(0, digits.length - 1)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Nudges its child sideways each time [trigger] changes.
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: trigger == 0 ? 1 : 0, end: 1),
      duration: _duration(context, 400),
      child: child,
      builder: (_, value, child) => Transform.translate(
        offset: Offset(sin(value * pi * 4) * 10 * (1 - value), 0),
        child: child,
      ),
    );
  }
}

/// Asks for the PIN when unlocking.
class _PinSheet extends StatefulWidget {
  const _PinSheet();

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _digits = '';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your PIN',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _PinDots(digits: _digits),
          const SizedBox(height: 8),
          _Keypad(
            digits: _digits,
            onChanged: (digits) => setState(() => _digits = digits),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('strict-pin-submit'),
            onPressed: _digits.length >= 4
                ? () => Navigator.of(context).pop(_digits)
                : null,
            child: const Text('Unlock'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: BlockingColors.textMuted,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// The ring every state is built around; the arc animates to its fraction.
class _Dial extends StatelessWidget {
  const _Dial({
    required this.size,
    required this.fraction,
    required this.color,
    required this.child,
    this.semanticsLabel,
  });

  final double size;
  final double fraction;
  final Color color;
  final Widget child;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: semanticsLabel,
        excludeSemantics: semanticsLabel != null,
        child: SizedBox(
          width: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
            duration: _duration(context, 600),
            curve: Curves.easeOutCubic,
            child: child,
            builder: (_, value, child) =>
                TimerDial(fraction: value, color: color, child: child!),
          ),
        ),
      ),
    );
  }
}

class _GlyphCenter extends StatelessWidget {
  const _GlyphCenter({
    required this.label,
    this.size = const Size(28, 32),
    this.labelSize = 13,
  });

  final String label;
  final Size size;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LockGlyph(open: 0, color: BlockingColors.accent, size: size),
          const SizedBox(height: 6),
          _FitText(
            label,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
              color: BlockingColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingCenter extends StatelessWidget {
  const _RingCenter({required this.big, required this.small, this.footnote});

  final String big;
  final String small;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FitText(
            big,
            style: const TextStyle(
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          _FitText(
            small,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BlockingColors.textMuted,
            ),
          ),
          if (footnote case final footnote?)
            _FitText(
              footnote,
              style: const TextStyle(
                fontSize: 12,
                color: BlockingColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// A padlock in the onboarding illustration style; [open] lifts the shackle.
class _LockGlyph extends StatelessWidget {
  const _LockGlyph({
    required this.open,
    required this.color,
    required this.size,
  });

  final double open;
  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _LockGlyphPainter(open: open, color: color),
    );
  }
}

class _LockGlyphPainter extends CustomPainter {
  const _LockGlyphPainter({required this.open, required this.color});

  final double open;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, h * 0.42, w, h),
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(body, Paint()..color = BlockingColors.surfaceRaised);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
    final keyhole = Paint()..color = color;
    canvas.drawCircle(Offset(w * 0.5, h * 0.66), w * 0.07, keyhole);
    canvas.drawRect(
      Rect.fromLTRB(w * 0.47, h * 0.66, w * 0.53, h * 0.82),
      keyhole,
    );

    final shackle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    final radius = w * 0.3;
    final top = h * 0.42;
    canvas.save();
    // Lift and swing the shackle around its right foot as the lock opens.
    canvas.translate(w * 0.8, top);
    canvas.rotate(-28 * pi / 180 * open);
    canvas.translate(-w * 0.8, -top - h * 0.14 * open);
    final path = Path()
      ..moveTo(w * 0.2, top)
      ..lineTo(w * 0.2, top - h * 0.02)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(w * 0.5, top - h * 0.02),
          radius: radius,
        ),
        pi,
        pi,
        false,
      )
      ..lineTo(w * 0.8, top);
    canvas.drawPath(path, shackle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LockGlyphPainter old) =>
      old.open != open || old.color != color;
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.centred = true});

  final String text;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: centred ? 12 : 0),
      child: Text(
        text,
        textAlign: centred ? TextAlign.center : TextAlign.start,
        style: sectionLabel,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlockingColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BlockingColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StickyBar extends StatelessWidget {
  const _StickyBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: children,
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.fact);

  final _Fact fact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BlockingColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(fact.icon, size: 18, color: BlockingColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.eyebrow,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BlockingColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fact.value,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _emergencySteps = <({String question, String proceed, String stay})>[
  (
    question: 'Is this a real emergency, or an urge that will pass?',
    proceed: 'A real emergency',
    stay: 'An urge',
  ),
  (
    question: 'Could it wait until the timer ends or the PIN holder is around?',
    proceed: 'It cannot wait',
    stay: 'It can wait',
  ),
  (
    question:
        'This easy unlock works once. Next time you will retype '
        '$emergencyTextLength random characters.',
    proceed: 'Unlock now',
    stay: 'Keep strict mode',
  ),
];

class _ConfirmLock extends StatelessWidget {
  const _ConfirmLock(this.lock);

  final StrictLock lock;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Turn on ${_lockTitle(lock).toLowerCase()}?'),
      content: Text(
        '${_lockDetail(lock)}\n\nThis cannot be undone until strict mode ends.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('strict-lock-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: BlockingColors.textMuted,
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('strict-lock-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: _dialogAction,
          child: const Text('Turn on'),
        ),
      ],
    );
  }
}

class _EmergencyQuestions extends StatefulWidget {
  const _EmergencyQuestions();

  @override
  State<_EmergencyQuestions> createState() => _EmergencyQuestionsState();
}

class _EmergencyQuestionsState extends State<_EmergencyQuestions> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final step = _emergencySteps[_step];
    return AlertDialog(
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      title: Text('Emergency ${_step + 1} of ${_emergencySteps.length}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < _emergencySteps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index <= _step
                          ? BlockingColors.accent
                          : Colors.transparent,
                      border: Border.all(
                        color: index <= _step
                            ? BlockingColors.accent
                            : BlockingColors.outline,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: _duration(context, 200),
            child: Text(
              step.question,
              key: ValueKey(_step),
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Take a breath. There is no rush to answer.',
            style: TextStyle(fontSize: 13, color: BlockingColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('strict-emergency-proceed'),
          onPressed: () {
            if (_step == _emergencySteps.length - 1) {
              Navigator.of(context).pop(true);
            } else {
              setState(() => _step++);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: BlockingColors.textMuted,
            minimumSize: const Size(0, 48),
          ),
          child: Text(step.proceed),
        ),
        FilledButton(
          key: const ValueKey('strict-emergency-stay'),
          onPressed: () => Navigator.of(context).pop(false),
          style: _dialogAction,
          child: Text(step.stay),
        ),
      ],
    );
  }
}

class _RetypeDialog extends StatefulWidget {
  const _RetypeDialog({required this.text});

  final String text;

  @override
  State<_RetypeDialog> createState() => _RetypeDialogState();
}

class _RetypeDialogState extends State<_RetypeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _matched {
    final typed = _controller.text;
    var index = 0;
    while (index < typed.length &&
        index < widget.text.length &&
        typed[index] == widget.text[index]) {
      index++;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final typed = _controller.text;
    final matched = _matched;
    final matches = typed == widget.text;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      scrollable: true,
      title: const Text('Retype to unlock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Type the $emergencyTextLength characters below. Paste is off; '
            'this is meant to be slow.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: BlockingColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BlockingColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.text,
              style: mono.copyWith(height: 1.6, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('strict-retype'),
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: false,
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            keyboardType: TextInputType.visiblePassword,
            maxLines: 3,
            cursorColor: BlockingColors.accent,
            style: mono,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Type it here',
              filled: true,
              fillColor: BlockingColors.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: matched / widget.text.length,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
            color: BlockingColors.accent,
            backgroundColor: BlockingColors.outline,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  matched < typed.length
                      ? 'Mismatch at character ${matched + 1}'
                      : '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: BlockingColors.rising,
                  ),
                ),
              ),
              Text(
                '${typed.length} / ${widget.text.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: BlockingColors.textMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: BlockingColors.textMuted,
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('strict-retype-submit'),
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
