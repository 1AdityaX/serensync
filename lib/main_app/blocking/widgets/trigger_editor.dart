import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rule.dart';

class TriggerEditor extends StatelessWidget {
  static const defaultSchedule = Schedule(
    weekdays: {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
    startMinute: 9 * 60,
    endMinute: 17 * 60,
  );

  final Trigger trigger;
  final ValueChanged<Trigger> onChanged;

  const TriggerEditor({
    super.key,
    required this.trigger,
    required this.onChanged,
  });

  String get _type => switch (trigger) {
    Schedule() => 'schedule',
    UsageQuota() => 'usage',
    LaunchQuota() => 'launch',
  };

  void _changeType(String? type) {
    onChanged(switch (type) {
      'usage' => const UsageQuota(Duration(minutes: 30)),
      'launch' => const LaunchQuota(5),
      _ => defaultSchedule,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_typePicker(), const SizedBox(height: 16), _configuration()],
    );
  }

  Widget _typePicker() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('trigger-type'),
      initialValue: _type,
      dropdownColor: const Color(0xFF191919),
      iconEnabledColor: Colors.white70,
      focusColor: Colors.transparent,
      decoration: InputDecoration(
        labelText: 'Blocking condition',
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        prefixIcon: const Icon(Icons.tune, size: 19),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white54),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'schedule', child: Text('Hours')),
        DropdownMenuItem(value: 'usage', child: Text('Daily time')),
        DropdownMenuItem(value: 'launch', child: Text('Daily opens')),
      ],
      onChanged: _changeType,
    );
  }

  Widget _configuration() {
    return switch (trigger) {
      final Schedule schedule => _ScheduleEditor(
        schedule: schedule,
        onChanged: onChanged,
      ),
      final UsageQuota quota => TextFormField(
        key: const ValueKey('usage-minutes'),
        initialValue: '${quota.limit.inMinutes}',
        cursorColor: Colors.white,
        decoration: _numberDecoration(
          'Blocked after',
          suffix: 'minutes of use today',
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          final minutes = int.tryParse(value);
          if (minutes != null && minutes > 0) {
            onChanged(UsageQuota(Duration(minutes: minutes)));
          }
        },
      ),
      final LaunchQuota quota => TextFormField(
        key: const ValueKey('launch-count'),
        initialValue: '${quota.limit}',
        cursorColor: Colors.white,
        decoration: _numberDecoration('Blocked after', suffix: 'opens today'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          final count = int.tryParse(value);
          if (count != null && count > 0) onChanged(LaunchQuota(count));
        },
      ),
    };
  }
}

InputDecoration _numberDecoration(String label, {String? suffix}) {
  return InputDecoration(
    labelText: label,
    suffixText: suffix,
    labelStyle: const TextStyle(color: Colors.white70),
    floatingLabelStyle: const TextStyle(color: Colors.white),
    filled: true,
    fillColor: const Color(0xFF1A1A1A),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white54),
    ),
  );
}

class _ScheduleEditor extends StatelessWidget {
  final Schedule schedule;
  final ValueChanged<Trigger> onChanged;

  const _ScheduleEditor({required this.schedule, required this.onChanged});

  void _toggleWeekday(int weekday, bool selected) {
    final weekdays = Set<int>.of(schedule.weekdays);
    selected ? weekdays.add(weekday) : weekdays.remove(weekday);
    onChanged(
      Schedule(
        weekdays: weekdays,
        startMinute: schedule.startMinute,
        endMinute: schedule.endMinute,
      ),
    );
  }

  void _changeTime({required bool start, required int minute}) {
    onChanged(
      Schedule(
        weekdays: schedule.weekdays,
        startMinute: start ? minute : schedule.startMinute,
        endMinute: start ? schedule.endMinute : minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overnight = schedule.endMinute < schedule.startMinute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active days',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _weekdayPicker(),
        const SizedBox(height: 14),
        _timeEditor(start: true),
        const SizedBox(height: 8),
        _timeEditor(start: false),
        if (overnight)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Overnight · ends the next day'),
          ),
      ],
    );
  }

  Widget _timeEditor({required bool start}) {
    final name = start ? 'From' : 'Until';
    final keyPrefix = start ? 'schedule-start' : 'schedule-end';
    final minute = start ? schedule.startMinute : schedule.endMinute;
    final hour = minute ~/ 60;
    final minuteOfHour = minute % 60;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(name)),
        Expanded(
          child: _timeField(
            key: '$keyPrefix-hour',
            label: 'Hour',
            value: hour,
            max: 23,
            onChanged: (value) =>
                _changeTime(start: start, minute: value * 60 + minuteOfHour),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':'),
        ),
        Expanded(
          child: _timeField(
            key: '$keyPrefix-minute',
            label: 'Minute',
            value: minuteOfHour,
            max: 59,
            onChanged: (value) =>
                _changeTime(start: start, minute: hour * 60 + value),
          ),
        ),
      ],
    );
  }

  Widget _timeField({
    required String key,
    required String label,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      key: ValueKey(key),
      initialValue: '$value',
      cursorColor: Colors.white,
      decoration: _numberDecoration(label),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _maxValueFormatter(max),
      ],
      onChanged: (text) {
        final value = int.tryParse(text);
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _weekdayPicker() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 6,
      children: [
        for (var index = 0; index < labels.length; index++)
          _weekdayChip(index + 1, labels[index]),
      ],
    );
  }

  Widget _weekdayChip(int weekday, String label) {
    final selected = schedule.weekdays.contains(weekday);
    return TextButton(
      key: ValueKey('weekday-$weekday'),
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.black : Colors.white,
        backgroundColor: selected ? Colors.white : const Color(0xFF191919),
        side: BorderSide(color: selected ? Colors.white : Colors.white24),
        shape: const StadiumBorder(),
        minimumSize: const Size(42, 38),
        padding: const EdgeInsets.symmetric(horizontal: 11),
      ),
      onPressed: () => _toggleWeekday(weekday, !selected),
      child: Text(label),
    );
  }
}

TextInputFormatter _maxValueFormatter(int max) {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    final value = int.tryParse(newValue.text);
    return value != null && value <= max ? newValue : oldValue;
  });
}
