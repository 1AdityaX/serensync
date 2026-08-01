import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../apps/app_service.dart';
import '../../apps/installed_app.dart';
import 'blocking_colors.dart';
import 'blocking_engine.dart';
import 'rule.dart';
import 'rule_store.dart';
import 'widgets/app_picker.dart';
import 'widgets/trigger_editor.dart';

class RuleEditorScreen extends StatefulWidget {
  final RuleStore ruleStore;
  final AppService appService;
  final BlockRule? rule;

  const RuleEditorScreen({
    super.key,
    required this.ruleStore,
    required this.appService,
    this.rule,
  });

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  late final TextEditingController _nameController;
  late Set<String> _packages;
  late Trigger _trigger;
  late Future<List<InstalledApp>> _appsLoad;
  List<InstalledApp> _installedApps = const [];
  bool _saving = false;
  bool _saveError = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _packages = Set<String>.of(rule?.packages ?? const <String>{});
    _trigger = rule?.trigger ?? TriggerEditor.defaultSchedule;
    _appsLoad = widget.appService.getInstalledApps();
  }

  bool get _canSave => !_saving && _packages.isNotEmpty;

  String get _derivedName {
    final names = [
      for (final app in _installedApps)
        if (_packages.contains(app.packageName)) app.displayName,
    ];
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} + ${names.length - 2} more';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    final existingRule = widget.rule;
    final name = _nameController.text.trim();
    final rule = BlockRule(
      id: existingRule?.id ?? 0,
      name: name.isEmpty ? _derivedName : name,
      packages: _packages,
      trigger: _trigger,
      enabled: existingRule?.enabled ?? true,
    );
    try {
      if (existingRule == null) {
        await widget.ruleStore.insert(rule);
      } else {
        await widget.ruleStore.update(rule);
      }
      FlutterForegroundTask.sendDataToTask(rulesChangedSignal);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = true;
      });
    }
  }

  Future<void> _editCondition() async {
    final trigger = await Navigator.of(context).push<Trigger>(
      MaterialPageRoute(
        builder: (_) => ConditionEditorScreen(trigger: _trigger),
      ),
    );
    if (trigger != null && mounted) setState(() => _trigger = trigger);
  }

  Future<void> _selectApps(List<InstalledApp> apps) async {
    final packages = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) =>
            AppPickerScreen(apps: apps, selectedPackages: _packages),
      ),
    );
    if (packages != null && mounted) setState(() => _packages = packages);
  }

  void _changeTriggerType(String? type) {
    setState(() {
      _trigger = switch (type) {
        'usage' => const UsageQuota(Duration(minutes: 30)),
        'launch' => const LaunchQuota(5),
        _ => TriggerEditor.defaultSchedule,
      };
    });
  }

  String get _triggerType => switch (_trigger) {
    Schedule() => 'schedule',
    UsageQuota() => 'usage',
    LaunchQuota() => 'launch',
  };

  IconData get _conditionIcon => switch (_trigger) {
    Schedule() => Icons.schedule,
    UsageQuota() => Icons.hourglass_bottom,
    LaunchQuota() => Icons.open_in_new,
  };

  (String, String) get _conditionSummary => switch (_trigger) {
    final Schedule schedule when schedule.allDay => (
      'All day',
      weekdaySummary(schedule.weekdays),
    ),
    final Schedule schedule when schedule.times.length > 1 => (
      '${schedule.times.length} time windows',
      weekdaySummary(schedule.weekdays),
    ),
    final Schedule schedule => (
      '${ruleTime(schedule.startMinute)}–${ruleTime(schedule.endMinute)}',
      weekdaySummary(schedule.weekdays),
    ),
    final UsageQuota quota => (
      '${ruleDuration(quota.limit)} / day',
      'All day long',
    ),
    final LaunchQuota quota => ('${quota.limit}× / day', 'All day long'),
  };

  String? get _conditionNote => switch (_trigger) {
    UsageQuota() => 'The usage limit is shared by all selected apps.',
    LaunchQuota() => 'App launches are counted across all selected apps.',
    Schedule() => null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlockingColors.background,
      appBar: AppBar(
        backgroundColor: BlockingColors.background,
        centerTitle: true,
        title: Text(widget.rule == null ? 'New schedule' : 'Edit schedule'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          _nameField(),
          const SizedBox(height: 30),
          _conditionSection(),
          const SizedBox(height: 30),
          const Divider(color: Colors.white12),
          const SizedBox(height: 24),
          _blockingSection(),
          if (_saveError) ...[
            const SizedBox(height: 20),
            const _ErrorMessage(),
          ],
        ],
      ),
      bottomNavigationBar: _bottomAction(),
    );
  }

  Widget _nameField() {
    return TextField(
      key: const ValueKey('rule-name'),
      controller: _nameController,
      cursorColor: BlockingColors.accent,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: _derivedName.isEmpty ? 'Schedule name' : _derivedName,
        filled: true,
        fillColor: BlockingColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: BlockingColors.accent),
        ),
      ),
    );
  }

  Widget _conditionSection() {
    final (primary, secondary) = _conditionSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Condition',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('trigger-type'),
                value: _triggerType,
                dropdownColor: BlockingColors.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                ),
                style: const TextStyle(
                  color: BlockingColors.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                items: const [
                  DropdownMenuItem(value: 'schedule', child: Text('Time')),
                  DropdownMenuItem(value: 'usage', child: Text('Usage limit')),
                  DropdownMenuItem(
                    value: 'launch',
                    child: Text('Launch count'),
                  ),
                ],
                onChanged: _changeTriggerType,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: BlockingColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('condition-summary'),
            onTap: _editCondition,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: BlockingColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_conditionIcon, color: BlockingColors.onAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primary,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          secondary,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
        ),
        if (_conditionNote case final note?) ...[
          const SizedBox(height: 14),
          Container(
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
                  child: Text(
                    note,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _blockingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blocking',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select the apps you want this schedule to block.',
          style: TextStyle(color: Colors.white60, fontSize: 15),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<InstalledApp>>(
          future: _appsLoad,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _installedApps = snapshot.data!;
              return Material(
                color: BlockingColors.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: const ValueKey('apps-summary'),
                  minTileHeight: 84,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text(
                    'Apps',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_packages.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                  onTap: () => _selectApps(snapshot.data!),
                ),
              );
            }
            if (snapshot.hasError) {
              return _AppsLoadError(
                onRetry: () => setState(
                  () => _appsLoad = widget.appService.getInstalledApps(),
                ),
              );
            }
            return const _AppsLoading();
          },
        ),
      ],
    );
  }

  Widget _bottomAction() {
    return SafeArea(
      top: false,
      child: Container(
        color: BlockingColors.background,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: FilledButton(
          key: const ValueKey('rule-save'),
          onPressed: _canSave ? _save : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: BlockingColors.accent,
            foregroundColor: BlockingColors.onAccent,
            disabledBackgroundColor: BlockingColors.surfaceRaised,
            disabledForegroundColor: Colors.white38,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BlockingColors.onAccent,
                  ),
                )
              : Text(widget.rule == null ? 'Create' : 'Save changes'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _AppsLoading extends StatelessWidget {
  const _AppsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Loading apps…')),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BlockingColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppsLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _AppsLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('Could not load your apps.')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: BlockingColors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: BlockingColors.accent),
          SizedBox(width: 12),
          Expanded(child: Text('Could not save this schedule. Try again.')),
        ],
      ),
    );
  }
}
