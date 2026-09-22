import 'dart:async';

import 'package:flutter/material.dart';

import '../../apps/app_service.dart';
import '../../apps/installed_app.dart';
import '../../theme.dart';
import '../strict/strict_mode.dart';
import 'blocking_colors.dart';
import 'blocking_engine.dart';
import 'onboarding/permission_status.dart';
import 'rule.dart';
import 'rule_store.dart';
import 'widgets/app_picker.dart';
import 'widgets/note.dart';
import 'widgets/trigger_editor.dart';
import 'widgets/web_target_picker.dart';

class RuleEditorScreen extends StatefulWidget {
  final RuleStore ruleStore;
  final AppService appService;
  final BlockingService blockingService;
  final PermissionStatus permissionStatus;
  final BlockRule? rule;

  /// While strict mode locks the rules, an existing block saves only when
  /// the change tightens it.
  final bool locked;

  RuleEditorScreen({
    super.key,
    required this.ruleStore,
    required this.appService,
    required this.blockingService,
    PermissionStatus? permissionStatus,
    this.locked = false,
    this.rule,
  }) : permissionStatus = permissionStatus ?? PermissionStatus();

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _nameController;
  late Set<String> _packages;
  late Set<String> _websites;
  late Set<String> _keywords;
  late Trigger _trigger;
  late Future<List<InstalledApp>> _appsLoad;
  List<InstalledApp> _installedApps = const [];
  bool? _accessibilityEnabled;
  bool _saving = false;
  bool _saveError = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _packages = Set<String>.of(rule?.packages ?? const <String>{});
    _websites = Set<String>.of(rule?.websites ?? const <String>{});
    _keywords = Set<String>.of(rule?.keywords ?? const <String>{});
    _trigger = rule?.trigger ?? TriggerEditor.defaultSchedule;
    _appsLoad = widget.appService.getInstalledApps();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshAccessibility());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshAccessibility());
  }

  Future<void> _refreshAccessibility() async {
    final permissions = await widget.permissionStatus.check();
    if (mounted) {
      setState(() => _accessibilityEnabled = permissions.accessibility);
    }
  }

  Future<void> _requestAccessibility() async {
    await widget.permissionStatus.request(RequiredPermission.accessibility);
    await _refreshAccessibility();
  }

  bool get _blocksWeb => _websites.isNotEmpty || _keywords.isNotEmpty;

  bool get _loosens {
    final existing = widget.rule;
    return widget.locked && existing != null && !tightens(existing, _rule());
  }

  bool get _canSave =>
      !_saving && (_packages.isNotEmpty || _blocksWeb) && !_loosens;

  String get _derivedName {
    final names = [
      for (final app in _installedApps)
        if (_packages.contains(app.packageName)) app.displayName,
      ..._websites,
      ..._keywords,
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
    final rule = _rule();
    try {
      if (existingRule == null) {
        await widget.ruleStore.insert(rule);
      } else {
        await widget.ruleStore.update(rule);
      }
      await widget.blockingService.sync(widget.ruleStore);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = true;
      });
    }
  }

  BlockRule _rule() {
    final existingRule = widget.rule;
    final name = _nameController.text.trim();
    return BlockRule(
      id: existingRule?.id ?? 0,
      name: name.isEmpty ? _derivedName : name,
      packages: _packages,
      websites: _websites,
      keywords: _keywords,
      trigger: _trigger,
      enabled: existingRule?.enabled ?? true,
    );
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

  Future<void> _editWebsites() async {
    final websites = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => WebTargetPicker(
          title: 'Websites',
          hint: 'Add a website, like instagram.com',
          invalidMessage: 'Enter a website such as instagram.com.',
          values: _websites,
          normalize: (input) => parseAddress(input)?.host,
        ),
      ),
    );
    if (websites != null && mounted) setState(() => _websites = websites);
  }

  Future<void> _editKeywords() async {
    final keywords = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => WebTargetPicker(
          title: 'Keywords',
          hint: 'Add a keyword, like casino',
          invalidMessage: 'Enter a keyword.',
          values: _keywords,
          normalize: (input) {
            final keyword = input.trim().toLowerCase();
            return keyword.isEmpty ? null : keyword;
          },
        ),
      ),
    );
    if (keywords != null && mounted) setState(() => _keywords = keywords);
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
    LaunchQuota() => Icons.repeat,
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
      '${ruleDuration(quota.limit)} a day',
      'Shared by every app in this block',
    ),
    final LaunchQuota quota => (
      '${quota.limit} opens a day',
      'Counted across every app in this block',
    ),
  };

  @override
  Widget build(BuildContext context) {
    // Comparing schedules walks a whole week, so it happens once per build.
    final loosens = _loosens;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rule == null ? 'New block' : 'Edit block'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _nameField(),
          const SizedBox(height: 28),
          _conditionSection(),
          const SizedBox(height: 28),
          _targetsSection(),
          if (widget.locked && widget.rule != null) ...[
            const SizedBox(height: 20),
            Note(
              key: const ValueKey('rule-locked'),
              icon: Icons.shield,
              message: loosens
                  ? 'This change would loosen the block. Strict mode is on.'
                  : 'Strict mode is on. This block can be tightened, not '
                        'loosened.',
            ),
          ],
          if (_saveError) ...[
            const SizedBox(height: 20),
            const Note(
              icon: Icons.error_outline,
              message: 'Could not save. Try again.',
            ),
          ],
        ],
      ),
      bottomNavigationBar: _bottomAction(
        _saving || loosens || (_packages.isEmpty && !_blocksWeb),
      ),
    );
  }

  Widget _nameField() {
    return TextField(
      key: const ValueKey('rule-name'),
      controller: _nameController,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: _derivedName.isEmpty ? 'Name' : _derivedName,
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
            const Expanded(child: Text('When', style: sectionLabel)),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('trigger-type'),
                value: _triggerType,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: BlockingColors.textMuted,
                ),
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: BlockingColors.accent,
                  fontSize: 15,
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
        const SizedBox(height: 8),
        Material(
          color: BlockingColors.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('condition-summary'),
            onTap: _editCondition,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BlockingColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _conditionIcon,
                      size: 20,
                      color: BlockingColors.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primary,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          secondary,
                          style: const TextStyle(
                            color: BlockingColors.textMuted,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: BlockingColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _targetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What to block', style: sectionLabel),
        const SizedBox(height: 8),
        FutureBuilder<List<InstalledApp>>(
          future: _appsLoad,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _installedApps = snapshot.data!;
              return _TargetTile(
                key: const ValueKey('apps-summary'),
                title: 'Apps',
                count: _packages.length,
                onTap: () => _selectApps(snapshot.data!),
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
        const SizedBox(height: 10),
        _TargetTile(
          key: const ValueKey('websites-summary'),
          title: 'Websites',
          count: _websites.length,
          onTap: _editWebsites,
        ),
        const SizedBox(height: 10),
        _TargetTile(
          key: const ValueKey('keywords-summary'),
          title: 'Keywords',
          count: _keywords.length,
          onTap: _editKeywords,
        ),
        if (_blocksWeb && _accessibilityEnabled == false) ...[
          const SizedBox(height: 14),
          Note(
            message:
                'Allow accessibility so SerenSync can read the address bar '
                'and block websites and keywords.',
            action: TextButton(
              key: const ValueKey('allow-accessibility'),
              onPressed: _requestAccessibility,
              child: const Text('Allow'),
            ),
          ),
        ],
        if (_blocksWeb && _trigger is! Schedule) ...[
          const SizedBox(height: 14),
          const Note(
            message:
                'Websites and keywords are blocked all day, because '
                'browsing time does not count towards the limit.',
          ),
        ],
      ],
    );
  }

  Widget _bottomAction(bool disabled) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: FilledButton(
          key: const ValueKey('rule-save'),
          onPressed: disabled ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BlockingColors.onAccent,
                  ),
                )
              : Text(widget.rule == null ? 'Create' : 'Save'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }
}

class _TargetTile extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _TargetTile({
    super.key,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlockingColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 72,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count == 0 ? 'None' : '$count',
              style: const TextStyle(
                color: BlockingColors.textMuted,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: BlockingColors.textMuted),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AppsLoading extends StatelessWidget {
  const _AppsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
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
            child: CircularProgressIndicator(strokeWidth: 2),
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
