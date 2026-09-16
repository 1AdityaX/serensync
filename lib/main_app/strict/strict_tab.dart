import 'dart:async';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blocking/blocking_colors.dart';
import '../blocking/blocking_engine.dart';
import '../blocking/rule.dart';
import '../blocking/rule_store.dart';
import 'strict_mode.dart';
import 'strict_mode_store.dart';
import 'uninstall_guard.dart';

const _timerLengths = <Duration>[
  Duration(hours: 1),
  Duration(hours: 3),
  Duration(hours: 8),
  Duration(hours: 24),
  Duration(days: 3),
  Duration(days: 7),
];
const _cooldowns = <Duration?>[
  null,
  Duration(minutes: 10),
  Duration(hours: 1),
  Duration(hours: 24),
];

class StrictTab extends StatefulWidget {
  const StrictTab({
    super.key,
    required this.ruleStore,
    required this.blockingService,
    required this.strictModeStore,
    required this.onChanged,
    this.isCharging,
    this.uninstallGuard,
  });

  final RuleStore ruleStore;
  final BlockingService blockingService;
  final StrictModeStore strictModeStore;

  /// Called after strict mode starts or ends, so the rest of the app can
  /// pick up the new locks.
  final VoidCallback onChanged;

  /// Defaults to the battery state; tests inject a value.
  final Future<bool> Function()? isCharging;

  /// Defaults to the device administrator; tests inject a fake.
  final UninstallGuard? uninstallGuard;

  @override
  State<StrictTab> createState() => _StrictTabState();
}

// A phone at its charge limit is plugged in without charging.
Future<bool> _batteryCharging() async {
  return switch (await Battery().batteryState) {
    BatteryState.charging ||
    BatteryState.full ||
    BatteryState.connectedNotCharging => true,
    _ => false,
  };
}

class _StrictTabState extends State<StrictTab> with WidgetsBindingObserver {
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _pinConfirm = TextEditingController();
  late final UninstallGuard _uninstallGuard =
      widget.uninstallGuard ?? UninstallGuard();
  final Set<UnlockCondition> _conditions = {UnlockCondition.timer};
  final Set<StrictLock> _locks = {StrictLock.rules};
  Duration _timerLength = _timerLengths.first;
  Duration? _cooldown;
  String? _activationMessage;
  bool _loaded = false;
  StrictMode? _strict;
  List<BlockRule> _rules = const [];
  bool _emergencyUsed = false;
  String? _unlockMessage;
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
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final strict = await widget.strictModeStore.read();
    final rules = await widget.ruleStore.readAll();
    final emergencyUsed = await widget.strictModeStore.emergencyUsed;
    if (!mounted) return;
    setState(() {
      _strict = strict;
      _rules = rules;
      _emergencyUsed = emergencyUsed;
      _loaded = true;
    });
    _syncTicker();
  }

  // Countdowns for the timer and the cooldown redraw once a second.
  void _syncTicker() {
    final strict = _strict;
    final until = strict?.until;
    final counting =
        strict != null &&
        ((until != null && DateTime.now().isBefore(until)) ||
            strict.unlockRequestedAt != null);
    if (counting) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Set<StrictLock> get _effectiveLocks =>
      effectiveLocks(_locks, conditions: _conditions, cooldown: _cooldown);

  bool get _settingsForced => effectiveLocks(
    _locks.difference(const {StrictLock.settings}),
    conditions: _conditions,
    cooldown: _cooldown,
  ).contains(StrictLock.settings);

  bool get _hasScheduleRule =>
      _rules.any((rule) => rule.enabled && rule.trigger is Schedule);

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
      _unlockMessage = null;
      _activationMessage = null;
    });
    _syncTicker();
  }

  bool get _pinValid =>
      RegExp(r'^\d{4,8}$').hasMatch(_pin.text) && _pin.text == _pinConfirm.text;

  bool get _canActivate =>
      _conditions.isNotEmpty &&
      _effectiveLocks.isNotEmpty &&
      (!_conditions.contains(UnlockCondition.pin) || _pinValid);

  Future<void> _activate() async {
    final locks = _effectiveLocks;
    if (locks.contains(StrictLock.uninstall) &&
        !await _uninstallGuard.activate()) {
      if (!mounted) return;
      setState(
        () => _activationMessage =
            'Blocking uninstalls needs SerenSync as a device admin. Allow '
            'it when Android asks, or turn that lock off.',
      );
      return;
    }
    final now = DateTime.now();
    await _write(
      StrictMode(
        conditions: Set.of(_conditions),
        locks: locks,
        activatedAt: now,
        until: _conditions.contains(UnlockCondition.timer)
            ? now.add(_timerLength)
            : null,
        cooldown: _cooldown,
        pin: _conditions.contains(UnlockCondition.pin)
            ? PinHash.create(_pin.text, Random.secure())
            : null,
      ),
    );
    _pin.clear();
    _pinConfirm.clear();
  }

  Future<void> _unlock(StrictMode strict) async {
    final now = DateTime.now();
    String? pin;
    if (strict.conditions.contains(UnlockCondition.pin)) {
      pin = await _askPin();
      if (pin == null || !mounted) return;
    }
    final unmet = unmetConditions(
      strict,
      now: now,
      charging:
          strict.conditions.contains(UnlockCondition.charger) &&
          await (widget.isCharging ?? _batteryCharging)(),
      pinEntered: pin != null && strict.pin!.matches(pin),
      schedulesRunning: schedulesRunning(_rules, now),
    );
    if (unmet.isEmpty) {
      await _write(null);
      return;
    }
    if (!mounted) return;
    setState(() => _unlockMessage = _unmetMessage(unmet));
  }

  Future<String?> _askPin() {
    return showDialog<String>(
      context: context,
      builder: (context) => const _PinDialog(),
    );
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
      builder: (_) => _RetypeDialog(text: text),
    );
    if ((typed ?? false) && mounted) await _write(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(color: BlockingColors.accent),
      );
    }
    final strict = _strict;
    if (strict == null) return _setup();
    final now = DateTime.now();
    if (strictModeEnded(strict, now)) return _ended();
    return _active(strict, now);
  }

  Widget _setup() {
    final needsPin = _conditions.contains(UnlockCondition.pin);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const Text(
          'Strict mode',
          style: TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Locks your blocks so they cannot be undone on a whim. Choose what '
          'it takes to unlock, and what stays locked meanwhile.',
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: BlockingColors.textMuted,
          ),
        ),
        const _Label('Unlock with'),
        _Chips<UnlockCondition>(
          values: UnlockCondition.values,
          selected: _conditions,
          label: _conditionLabel,
          keyPrefix: 'strict-condition',
          enabled: (condition) =>
              condition != UnlockCondition.followSchedules || _hasScheduleRule,
          onToggle: (condition, selected) => setState(() {
            selected
                ? _conditions.add(condition)
                : _conditions.remove(condition);
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            [
              if (_conditions.length > 1) 'All of these are needed to unlock.',
              if (!_hasScheduleRule)
                'Following schedules needs an enabled time schedule.',
            ].join(' '),
            style: const TextStyle(
              fontSize: 13,
              color: BlockingColors.textMuted,
            ),
          ),
        ),
        if (_conditions.contains(UnlockCondition.timer)) ...[
          const _Label('For'),
          _Chips<Duration>(
            values: _timerLengths,
            selected: {_timerLength},
            label: _lengthLabel,
            keyPrefix: 'strict-timer',
            onToggle: (length, _) => setState(() => _timerLength = length),
          ),
        ],
        if (needsPin) ...[
          const _Label('PIN'),
          _PinField(
            key: const ValueKey('strict-pin'),
            controller: _pin,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
          _PinField(
            key: const ValueKey('strict-pin-confirm'),
            controller: _pinConfirm,
            hint: 'Confirm PIN',
            onChanged: () => setState(() {}),
          ),
          if (_pin.text.isNotEmpty && !_pinValid)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Use 4 to 8 digits and enter the same PIN twice.',
                style: TextStyle(fontSize: 13, color: BlockingColors.rising),
              ),
            ),
        ],
        const _Label('Cooldown'),
        _Chips<Duration?>(
          values: _cooldowns,
          selected: {_cooldown},
          label: (cooldown) =>
              cooldown == null ? 'Off' : _lengthLabel(cooldown),
          keyPrefix: 'strict-cooldown',
          onToggle: (cooldown, _) => setState(() => _cooldown = cooldown),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Unlocking waits this long after you ask for it.',
            style: TextStyle(fontSize: 13, color: BlockingColors.textMuted),
          ),
        ),
        const _Label('While strict'),
        for (final lock in StrictLock.values)
          SwitchListTile(
            key: ValueKey('strict-lock-${lock.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(_lockTitle(lock)),
            subtitle: Text(
              lock == StrictLock.settings && _settingsForced
                  ? 'Kept on: the clock and the device admin are changed here.'
                  : _lockDetail(lock),
              style: const TextStyle(color: BlockingColors.textMuted),
            ),
            value: _effectiveLocks.contains(lock),
            activeTrackColor: BlockingColors.accent,
            activeThumbColor: BlockingColors.onAccent,
            onChanged: lock == StrictLock.settings && _settingsForced
                ? null
                : (value) => setState(() {
                    value ? _locks.add(lock) : _locks.remove(lock);
                  }),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Nothing here stops Safe mode or a computer with developer tools.',
            style: TextStyle(fontSize: 13, color: BlockingColors.textMuted),
          ),
        ),
        if (_activationMessage case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              message,
              key: const ValueKey('strict-activation-message'),
              style: const TextStyle(color: BlockingColors.rising),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('strict-activate'),
          onPressed: _canActivate ? () => unawaited(_activate()) : null,
          style: _primaryStyle,
          child: const Text('Activate'),
        ),
      ],
    );
  }

  Widget _active(StrictMode strict, DateTime now) {
    final remaining = cooldownRemaining(strict, now);
    final waiting = remaining != null && strict.unlockRequestedAt != null;
    final ready = remaining == null || remaining == Duration.zero;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const Icon(Icons.shield, size: 56, color: BlockingColors.accent),
        const SizedBox(height: 16),
        const Text(
          'Strict mode is on',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _statusLine(strict, now),
          key: const ValueKey('strict-status'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.45,
            color: BlockingColors.textMuted,
          ),
        ),
        const _Label('Locked'),
        for (final lock in StrictLock.values)
          if (strict.locks.contains(lock))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: BlockingColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_lockTitle(lock))),
                ],
              ),
            ),
        const SizedBox(height: 32),
        if (_unlockMessage case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              message,
              key: const ValueKey('strict-unlock-message'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: BlockingColors.rising),
            ),
          ),
        if (waiting && !ready)
          Text(
            'Unlock opens in ${_clock(remaining)}.',
            key: const ValueKey('strict-cooldown'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BlockingColors.textMuted),
          ),
        if (waiting && !ready)
          TextButton(
            key: const ValueKey('strict-cancel-unlock'),
            onPressed: () => unawaited(_write(strict.withUnlockRequest(null))),
            style: TextButton.styleFrom(
              foregroundColor: BlockingColors.textMuted,
            ),
            child: const Text('Cancel request'),
          )
        else
          OutlinedButton(
            key: const ValueKey('strict-unlock'),
            onPressed: () => unawaited(
              ready ? _unlock(strict) : _write(strict.withUnlockRequest(now)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: BlockingColors.outline),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(ready ? 'Unlock' : 'Request unlock'),
          ),
        TextButton(
          key: const ValueKey('strict-emergency'),
          onPressed: () => unawaited(_emergency()),
          style: TextButton.styleFrom(
            foregroundColor: BlockingColors.textMuted,
          ),
          child: const Text('Emergency unlock'),
        ),
      ],
    );
  }

  Widget _ended() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(
            Icons.shield_outlined,
            size: 56,
            color: BlockingColors.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'Strict mode has ended',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your blocks are back to normal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: BlockingColors.textMuted,
            ),
          ),
          const Spacer(),
          FilledButton(
            key: const ValueKey('strict-done'),
            onPressed: () => unawaited(_write(null)),
            style: _primaryStyle,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _statusLine(StrictMode strict, DateTime now) {
    final parts = <String>[
      if (strict.until case final until? when now.isBefore(until))
        'Ends in ${_remainingLabel(until.difference(now))}',
      if (strict.conditions.contains(UnlockCondition.followSchedules))
        'Guards screens while your schedules run',
      if (strict.conditions.contains(UnlockCondition.pin) &&
          strict.conditions.contains(UnlockCondition.charger))
        'Unlock with your PIN while charging'
      else if (strict.conditions.contains(UnlockCondition.pin))
        'Unlock with your PIN'
      else if (strict.conditions.contains(UnlockCondition.charger))
        'Unlock while charging',
      if (strict.cooldown case final cooldown?)
        'Unlocking waits ${_lengthLabel(cooldown)}',
    ];
    return parts.join('. ');
  }
}

String _remainingLabel(Duration remaining) {
  final minutes = Duration(minutes: (remaining.inSeconds / 60).ceil());
  if (minutes.inDays >= 1) {
    return '${minutes.inDays}d ${minutes.inHours.remainder(24)}h';
  }
  return ruleDuration(minutes);
}

String _unmetMessage(Set<UnlockCondition> unmet) {
  return [
    for (final condition in unmet)
      switch (condition) {
        UnlockCondition.pin => 'That PIN is wrong.',
        UnlockCondition.charger => 'Plug in a charger first.',
        UnlockCondition.timer => 'The timer has not ended yet.',
        UnlockCondition.followSchedules => 'Wait until your schedules end.',
      },
  ].join(' ');
}

String _conditionLabel(UnlockCondition condition) {
  return switch (condition) {
    UnlockCondition.pin => 'PIN',
    UnlockCondition.charger => 'Charger',
    UnlockCondition.timer => 'Timer',
    UnlockCondition.followSchedules => 'Follow schedules',
  };
}

String _lockTitle(StrictLock lock) {
  return switch (lock) {
    StrictLock.rules => 'Lock blocks',
    StrictLock.settings => 'Block device settings',
    StrictLock.uninstall => 'Block uninstalling',
    StrictLock.recents => 'Block recent apps',
    StrictLock.newApps => 'Block new apps',
  };
}

String _lockDetail(StrictLock lock) {
  return switch (lock) {
    StrictLock.rules =>
      'Blocks can be added to or tightened, but not paused, deleted, or '
          'loosened.',
    StrictLock.settings => 'The Settings app shows the block screen.',
    StrictLock.uninstall =>
      'SerenSync becomes a device admin, so Android refuses to uninstall it.',
    StrictLock.recents =>
      'The recent apps screen shows the block screen while SerenSync is the '
          'home app.',
    StrictLock.newApps => 'Apps installed from now on are blocked.',
  };
}

String _lengthLabel(Duration length) {
  if (length.inDays >= 1) {
    return length.inDays == 1 ? '1 day' : '${length.inDays} days';
  }
  if (length.inHours >= 1) {
    return length.inHours == 1 ? '1 hour' : '${length.inHours} hours';
  }
  return '${length.inMinutes} min';
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

final _primaryStyle = FilledButton.styleFrom(
  backgroundColor: BlockingColors.accent,
  foregroundColor: BlockingColors.onAccent,
  disabledBackgroundColor: BlockingColors.surfaceRaised,
  disabledForegroundColor: Colors.white38,
  shape: const StadiumBorder(),
  padding: const EdgeInsets.symmetric(vertical: 16),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
);

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: BlockingColors.textMuted,
        ),
      ),
    );
  }
}

class _Chips<T> extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.label,
    required this.keyPrefix,
    this.enabled,
    required this.onToggle,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T value) label;
  final String keyPrefix;
  final bool Function(T value)? enabled;
  final void Function(T value, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          FilterChip(
            key: ValueKey('$keyPrefix-${_keyName(value)}'),
            label: Text(label(value)),
            selected: selected.contains(value),
            onSelected: (enabled?.call(value) ?? true)
                ? (isSelected) => onToggle(value, isSelected)
                : null,
            showCheckmark: false,
            selectedColor: BlockingColors.accent,
            backgroundColor: BlockingColors.surface,
            labelStyle: TextStyle(
              color: selected.contains(value)
                  ? BlockingColors.onAccent
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: selected.contains(value)
                  ? BlockingColors.accent
                  : BlockingColors.outline,
            ),
            shape: const StadiumBorder(),
          ),
      ],
    );
  }

  String _keyName(T value) {
    return switch (value) {
      final Enum value => value.name,
      final Duration value => '${value.inMinutes}m',
      null => 'off',
      _ => '$value',
    };
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    super.key,
    required this.controller,
    this.hint = 'PIN',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      cursorColor: BlockingColors.accent,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: BlockingColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BlockingColors.accent),
        ),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter your PIN'),
      content: _PinField(
        key: const ValueKey('strict-pin-entry'),
        controller: _controller,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('strict-pin-submit'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Unlock'),
        ),
      ],
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
    question:
        'Could it wait until the timer ends, a charger is nearby, or the '
        'PIN holder is around?',
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
      title: Text('Emergency ${_step + 1} of ${_emergencySteps.length}'),
      content: Text(step.question),
      actions: [
        TextButton(
          key: const ValueKey('strict-emergency-stay'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(step.stay),
        ),
        TextButton(
          key: const ValueKey('strict-emergency-proceed'),
          onPressed: () {
            if (_step == _emergencySteps.length - 1) {
              Navigator.of(context).pop(true);
            } else {
              setState(() => _step++);
            }
          },
          child: Text(step.proceed),
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

  @override
  Widget build(BuildContext context) {
    final matches = _controller.text == widget.text;
    return AlertDialog(
      title: const Text('Retype to unlock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('strict-retype'),
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            maxLines: 3,
            cursorColor: BlockingColors.accent,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Type it here'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
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
