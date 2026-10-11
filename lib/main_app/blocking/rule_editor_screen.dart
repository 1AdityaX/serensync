import 'dart:async';

import 'package:flutter/material.dart';

import '../../apps/app_service.dart';
import '../../apps/installed_app.dart';
import '../strict/strict_mode.dart';
import 'blocking_colors.dart';
import 'blocking_engine.dart';
import 'onboarding/permission_status.dart';
import 'rule.dart';
import 'rule_store.dart';
import '../../theme.dart';
import '../common/cards.dart';
import '../common/glyph_map.dart';
import '../common/glyphs.dart';
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

  /// Starting values for a new block, such as one picked from an idea.
  final String? draftName;
  final Trigger? draftTrigger;

  RuleEditorScreen({
    super.key,
    required this.ruleStore,
    required this.appService,
    required this.blockingService,
    PermissionStatus? permissionStatus,
    this.locked = false,
    this.rule,
    this.draftName,
    this.draftTrigger,
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
    _nameController = TextEditingController(
      text: rule?.name ?? widget.draftName ?? '',
    );
    _packages = Set<String>.of(rule?.packages ?? const <String>{});
    _websites = Set<String>.of(rule?.websites ?? const <String>{});
    _keywords = Set<String>.of(rule?.keywords ?? const <String>{});
    _trigger =
        rule?.trigger ?? widget.draftTrigger ?? TriggerEditor.defaultSchedule;
    _loadApps();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshAccessibility());
  }

  // App names feed the summary sentence, so they are kept once loaded.
  void _loadApps() {
    _appsLoad = widget.appService.getInstalledApps();
    unawaited(
      _appsLoad.then((apps) {
        if (mounted) setState(() => _installedApps = apps);
      }, onError: (Object _) {}),
    );
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

  void _changeTriggerType(String type) {
    if (type == _triggerType) return;
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

  List<String> get _appNames => [
    for (final app in _installedApps)
      if (_packages.contains(app.packageName)) app.displayName,
  ];

  /// The whole block in one plain sentence.
  String get _sentence {
    final things = [..._appNames, ..._websites];
    if (things.isEmpty && _keywords.isEmpty) {
      return 'Start by choosing what this block should close.';
    }
    final String what;
    if (things.isEmpty) {
      what = 'pages that mention ${_list(_keywords.toList())}';
    } else {
      what = _list(things);
    }
    final when = switch (_trigger) {
      final Schedule schedule when schedule.allDay =>
        'all day, ${_days(schedule.weekdays)}',
      final Schedule schedule when schedule.times.length > 1 =>
        'in ${schedule.times.length} time windows, ${_days(schedule.weekdays)}',
      final Schedule schedule =>
        'from ${ruleTime(schedule.startMinute)} to '
            '${ruleTime(schedule.endMinute)}, ${_days(schedule.weekdays)}',
      final UsageQuota quota =>
        'once you have used ${things.length > 1 ? 'them' : 'it'} for '
            '${ruleDuration(quota.limit)} in a day',
      final LaunchQuota quota =>
        'after ${quota.limit} ${quota.limit == 1 ? 'open' : 'opens'} in a day',
    };
    return 'Closes $what $when.';
  }

  @override
  Widget build(BuildContext context) {
    // Comparing schedules walks a whole week, so it happens once per build.
    final loosens = _loosens;
    final empty = _packages.isEmpty && !_blocksWeb;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rule == null ? 'New block' : 'Edit block'),
      ),
      // A short form, so every field is built and reachable at once.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Summary(_sentence),
            const SizedBox(height: 24),
            _targetsSection(),
            const SizedBox(height: 28),
            _conditionSection(),
            const SizedBox(height: 28),
            Text('Name', style: sectionLabel),
            const SizedBox(height: 10),
            _nameField(),
            if (widget.locked && widget.rule != null) ...[
              const SizedBox(height: 20),
              Note(
                key: const ValueKey('rule-locked'),
                icon: Icons.shield_outlined,
                message: loosens
                    ? 'This would loosen the block. Strict mode is on.'
                    : 'Strict mode: tighten only.',
              ),
            ],
            if (_saveError) ...[
              const SizedBox(height: 20),
              const Note(
                icon: Icons.error_outline,
                message: 'Couldn’t save. Try again.',
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _bottomAction(
        disabled: _saving || loosens || empty,
        hint: empty ? 'Pick something to block' : null,
      ),
    );
  }

  Widget _nameField() {
    return TextField(
      key: const ValueKey('rule-name'),
      controller: _nameController,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: _derivedName.isEmpty ? 'Optional' : _derivedName,
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
          borderSide: BorderSide(color: BlockingColors.text, width: 1.5),
        ),
      ),
    );
  }

  Widget _conditionSection() {
    final (primary, secondary) = _conditionSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('When', style: sectionLabel),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey('trigger-type'),
          children: [
            for (final (type, glyph, label) in const [
              ('schedule', Glyphs.clock, 'Time'),
              ('usage', Glyphs.hourglass, 'Limit'),
              ('launch', Glyphs.launch, 'Opens'),
            ]) ...[
              if (type != 'schedule') const SizedBox(width: 10),
              Expanded(
                child: _Square(
                  key: ValueKey('trigger-type-$type'),
                  glyph: glyph,
                  label: label,
                  selected: _triggerType == type,
                  onTap: () => _changeTriggerType(type),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SoftCard(
          key: const ValueKey('condition-summary'),
          onTap: _editCondition,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              GlyphBadge(triggerGlyph(_trigger)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BlockingColors.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              Glyph(
                Glyphs.chevronRight,
                size: 20,
                color: BlockingColors.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _targetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Block', style: sectionLabel),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FutureBuilder<List<InstalledApp>>(
                future: _appsLoad,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return _Square(
                      key: const ValueKey('apps-summary'),
                      glyph: Glyphs.apps,
                      label: 'Apps',
                      count: _packages.length,
                      onTap: () => _selectApps(snapshot.data!),
                    );
                  }
                  if (snapshot.hasError) {
                    return _Square(
                      key: const ValueKey('apps-retry'),
                      glyph: Glyphs.alert,
                      label: 'Retry',
                      onTap: () => setState(_loadApps),
                    );
                  }
                  return const _Square(
                    glyph: Glyphs.apps,
                    label: 'Apps',
                    loading: true,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Square(
                key: const ValueKey('websites-summary'),
                glyph: Glyphs.globe,
                label: 'Websites',
                count: _websites.length,
                onTap: _editWebsites,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Square(
                key: const ValueKey('keywords-summary'),
                glyph: Glyphs.search,
                label: 'Keywords',
                count: _keywords.length,
                onTap: _editKeywords,
              ),
            ),
          ],
        ),
        if (_blocksWeb && _accessibilityEnabled == false) ...[
          const SizedBox(height: 12),
          Note(
            message: 'Websites need accessibility.',
            action: TextButton(
              key: const ValueKey('allow-accessibility'),
              onPressed: _requestAccessibility,
              child: const Text('Allow'),
            ),
          ),
        ],
        if (_blocksWeb && _trigger is! Schedule) ...[
          const SizedBox(height: 12),
          const Note(
            message:
                'Websites stay blocked all day: browsing time isn’t counted.',
          ),
        ],
      ],
    );
  }

  Widget _bottomAction({required bool disabled, String? hint}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: BlockingColors.textMuted,
                  ),
                ),
              ),
            FilledButton(
              key: const ValueKey('rule-save'),
              onPressed: disabled ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BlockingColors.background,
                      ),
                    )
                  : Text(widget.rule == null ? 'Create' : 'Save'),
            ),
          ],
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

String _list(List<String> items) {
  if (items.length == 1) return items.single;
  if (items.length == 2) return '${items.first} and ${items.last}';
  return '${items.take(2).join(', ')} and ${items.length - 2} more';
}

String _days(Set<int> weekdays) {
  if (weekdays.length == 7) return 'every day';
  if (weekdays.isEmpty) return 'on no days yet';
  return 'on ${weekdaySummary(weekdays)}';
}

/// The whole block in one sentence, under the title.
class _Summary extends StatelessWidget {
  const _Summary(this.sentence);

  final String sentence;

  @override
  Widget build(BuildContext context) {
    return Text(
      sentence,
      key: const ValueKey('rule-sentence'),
      style: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: BlockingColors.textMuted,
      ),
    );
  }
}

/// A square tile: a glyph, a word, and a count or a selected state.
class _Square extends StatelessWidget {
  const _Square({
    super.key,
    required this.glyph,
    required this.label,
    this.count,
    this.selected = false,
    this.loading = false,
    this.onTap,
  });

  final Glyphs glyph;
  final String label;

  /// How many are chosen; null for tiles that are picked rather than filled.
  final int? count;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    final chosen = selected || (count ?? 0) > 0;
    final Widget corner;
    if (loading) {
      corner = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (count == null) {
      corner = const SizedBox(height: 24);
    } else if (count == 0) {
      corner = Glyph(Glyphs.plus, size: 18, color: BlockingColors.textMuted);
    } else {
      corner = Container(
        constraints: const BoxConstraints(minWidth: 24),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BlockingColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BlockingColors.onAccent,
          ),
        ),
      );
    }
    return Semantics(
      selected: selected,
      button: true,
      label: count == null ? label : '$label, $count chosen',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: SoftCard(
          onTap: onTap,
          radius: 20,
          padding: const EdgeInsets.all(14),
          color: selected ? BlockingColors.text : BlockingColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Glyph(
                    glyph,
                    size: 26,
                    color: selected
                        ? BlockingColors.background
                        : chosen
                        ? BlockingColors.text
                        : BlockingColors.textMuted,
                  ),
                  corner,
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? BlockingColors.background
                      : BlockingColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
