import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blocking_colors.dart';
import '../rule.dart';

class ConditionEditorScreen extends StatefulWidget {
  final Trigger trigger;

  const ConditionEditorScreen({super.key, required this.trigger});

  @override
  State<ConditionEditorScreen> createState() => _ConditionEditorScreenState();
}

class _ConditionEditorScreenState extends State<ConditionEditorScreen> {
  late Trigger _trigger;

  @override
  void initState() {
    super.initState();
    _trigger = widget.trigger;
  }

  String get _title => switch (_trigger) {
    Schedule() => 'Active time',
    UsageQuota() => 'Usage limit',
    LaunchQuota() => 'Launch count',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlockingColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: BlockingColors.background,
        title: Text(_title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: TriggerEditor(
          trigger: _trigger,
          onChanged: (trigger) => setState(() => _trigger = trigger),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: BlockingColors.background,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
            key: const ValueKey('condition-done'),
            onPressed: () => Navigator.of(context).pop(_trigger),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: BlockingColors.accent,
              foregroundColor: BlockingColors.onAccent,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return switch (trigger) {
      final Schedule schedule => _ScheduleEditor(
        schedule: schedule,
        onChanged: onChanged,
      ),
      final UsageQuota quota => _usageEditor(quota),
      final LaunchQuota quota => _launchEditor(quota),
    };
  }

  Widget _usageEditor(UsageQuota quota) {
    return Column(
      children: [
        _NumberLimitCard(
          fieldKey: 'usage-minutes',
          value: quota.limit.inMinutes,
          step: 5,
          unit: 'minutes per day',
          onChanged: (minutes) =>
              onChanged(UsageQuota(Duration(minutes: minutes))),
        ),
        const SizedBox(height: 18),
        const _DailyResetCard(),
        const SizedBox(height: 18),
        const _InfoMessage('The usage limit is shared by all selected apps.'),
      ],
    );
  }

  Widget _launchEditor(LaunchQuota quota) {
    return Column(
      children: [
        _NumberLimitCard(
          fieldKey: 'launch-count',
          value: quota.limit,
          step: 1,
          unit: 'opens per day',
          onChanged: (count) => onChanged(LaunchQuota(count)),
        ),
        const SizedBox(height: 18),
        const _DailyResetCard(),
        const SizedBox(height: 18),
        const _InfoMessage(
          'App launches are counted across all selected apps.',
        ),
      ],
    );
  }
}

class _NumberLimitCard extends StatefulWidget {
  final String fieldKey;
  final int value;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  const _NumberLimitCard({
    required this.fieldKey,
    required this.value,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_NumberLimitCard> createState() => _NumberLimitCardState();
}

class _NumberLimitCardState extends State<_NumberLimitCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_NumberLimitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  void _setValue(int value) {
    final next = value.clamp(1, 999);
    _controller.text = '$next';
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: () => _setValue(widget.value - widget.step),
          ),
          Expanded(
            child: Column(
              children: [
                TextField(
                  key: ValueKey(widget.fieldKey),
                  controller: _controller,
                  cursorColor: BlockingColors.accent,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (text) {
                    final value = int.tryParse(text);
                    if (value != null && value > 0) widget.onChanged(value);
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  widget.unit,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: () => _setValue(widget.value + widget.step),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(54, 54),
        backgroundColor: BlockingColors.surfaceRaised,
        foregroundColor: BlockingColors.accent,
      ),
      icon: Icon(icon),
    );
  }
}

class _DailyResetCard extends StatelessWidget {
  const _DailyResetCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Text(
            'Resets',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Spacer(),
          Text('Daily at midnight', style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  final String message;

  const _InfoMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: BlockingColors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: BlockingColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  final Schedule schedule;
  final ValueChanged<Trigger> onChanged;

  const _ScheduleEditor({required this.schedule, required this.onChanged});

  void _toggleWeekday(int weekday, bool selected) {
    final weekdays = Set<int>.of(schedule.weekdays);
    selected ? weekdays.add(weekday) : weekdays.remove(weekday);
    _replaceSchedule(weekdays: weekdays);
  }

  void _replaceSchedule({
    Set<int>? weekdays,
    List<ScheduleTime>? times,
    bool? allDay,
  }) {
    final nextTimes = times ?? schedule.times;
    onChanged(
      Schedule(
        weekdays: weekdays ?? schedule.weekdays,
        startMinute: nextTimes.first.startMinute,
        endMinute: nextTimes.first.endMinute,
        additionalTimes: nextTimes.skip(1).toList(),
        allDay: allDay ?? schedule.allDay,
      ),
    );
  }

  void _changeTime({
    required int index,
    required bool start,
    required int minute,
  }) {
    final times = schedule.times.toList();
    final current = times[index];
    times[index] = ScheduleTime(
      startMinute: start ? minute : current.startMinute,
      endMinute: start ? current.endMinute : minute,
    );
    _replaceSchedule(times: times);
  }

  void _addTime() {
    final times = schedule.times.toList();
    final start = times.last.endMinute;
    times.add(
      ScheduleTime(startMinute: start, endMinute: (start + 60) % (24 * 60)),
    );
    _replaceSchedule(times: times);
  }

  void _removeTime(int index) {
    final times = schedule.times.toList()..removeAt(index);
    _replaceSchedule(times: times);
  }

  @override
  Widget build(BuildContext context) {
    final hasOvernightWindow = schedule.times.any(
      (time) => time.endMinute < time.startMinute,
    );
    return Column(
      children: [
        _timeCard(),
        const SizedBox(height: 18),
        _daysCard(),
        const SizedBox(height: 18),
        _InfoMessage(
          schedule.allDay
              ? 'Apps are blocked all day on the selected days.'
              : hasOvernightWindow
              ? 'This schedule includes a window that ends the following day.'
              : 'Apps are blocked only during these active times.',
        ),
      ],
    );
  }

  Widget _timeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Times',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Text(
                'All day',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Switch(
                key: const ValueKey('schedule-all-day'),
                value: schedule.allDay,
                activeTrackColor: BlockingColors.accent,
                activeThumbColor: BlockingColors.onAccent,
                inactiveTrackColor: BlockingColors.surfaceRaised,
                inactiveThumbColor: Colors.white70,
                onChanged: (value) => _replaceSchedule(allDay: value),
              ),
            ],
          ),
          if (!schedule.allDay) ...[
            const SizedBox(height: 16),
            for (var index = 0; index < schedule.times.length; index++) ...[
              if (index > 0) const Divider(height: 28, color: Colors.white12),
              Row(
                children: [
                  Expanded(child: _timeEditor(index: index, start: true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('—', style: TextStyle(fontSize: 22)),
                  ),
                  Expanded(child: _timeEditor(index: index, start: false)),
                  if (schedule.times.length > 1) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      key: ValueKey('schedule-remove-time-$index'),
                      tooltip: 'Remove time',
                      onPressed: () => _removeTime(index),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                key: const ValueKey('schedule-add-time'),
                onPressed: _addTime,
                style: TextButton.styleFrom(
                  foregroundColor: BlockingColors.accent,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add time'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeEditor({required int index, required bool start}) {
    final time = schedule.times[index];
    final keyPrefix = start ? 'schedule-start' : 'schedule-end';
    final keySuffix = index == 0 ? '' : '-$index';
    final minute = start ? time.startMinute : time.endMinute;
    final hour = minute ~/ 60;
    final minuteOfHour = minute % 60;
    return Row(
      children: [
        Expanded(
          child: _timeField(
            key: '$keyPrefix-hour$keySuffix',
            value: hour,
            max: 23,
            onChanged: (value) => _changeTime(
              index: index,
              start: start,
              minute: value * 60 + minuteOfHour,
            ),
          ),
        ),
        const Text(':', style: TextStyle(fontSize: 20)),
        Expanded(
          child: _timeField(
            key: '$keyPrefix-minute$keySuffix',
            value: minuteOfHour,
            max: 59,
            onChanged: (value) => _changeTime(
              index: index,
              start: start,
              minute: hour * 60 + value,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeField({
    required String key,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      key: ValueKey(key),
      initialValue: value.toString().padLeft(2, '0'),
      cursorColor: BlockingColors.accent,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        filled: true,
        fillColor: BlockingColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14),
      ),
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

  Widget _daysCard() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Days',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                weekdaySummary(schedule.weekdays),
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(child: _weekdayButton(index + 1, labels[index])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekdayButton(int weekday, String label) {
    final selected = schedule.weekdays.contains(weekday);
    return AspectRatio(
      aspectRatio: 1,
      child: TextButton(
        key: ValueKey('weekday-$weekday'),
        onPressed: () => _toggleWeekday(weekday, !selected),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: selected ? BlockingColors.onAccent : Colors.white,
          backgroundColor: selected
              ? BlockingColors.accent
              : BlockingColors.surfaceRaised,
          shape: const CircleBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}

TextInputFormatter _maxValueFormatter(int max) {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    final value = int.tryParse(newValue.text);
    return value != null && value <= max ? newValue : oldValue;
  });
}
