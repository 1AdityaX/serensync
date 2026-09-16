import 'package:flutter/material.dart';

import '../../../apps/app_service.dart';
import '../blocking_colors.dart';
import '../blocking_engine.dart';
import '../rule.dart';
import '../rule_editor_screen.dart';
import '../rule_store.dart';

class RuleList extends StatefulWidget {
  const RuleList({
    super.key,
    required this.ruleStore,
    required this.appService,
    required this.blockingService,
  });

  final RuleStore ruleStore;
  final AppService appService;
  final BlockingService blockingService;

  @override
  State<RuleList> createState() => _RuleListState();
}

class _RuleListState extends State<RuleList> {
  List<BlockRule>? _rules;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final rules = await widget.ruleStore.readAll();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _openEditor([BlockRule? rule]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RuleEditorScreen(
          ruleStore: widget.ruleStore,
          appService: widget.appService,
          blockingService: widget.blockingService,
          rule: rule,
        ),
      ),
    );
    if (saved ?? false) await _loadRules();
  }

  Future<void> _toggle(BlockRule rule, bool enabled) async {
    final replacement = BlockRule(
      id: rule.id,
      name: rule.name,
      packages: rule.packages,
      websites: rule.websites,
      keywords: rule.keywords,
      trigger: rule.trigger,
      enabled: enabled,
    );
    await widget.ruleStore.update(replacement);
    await widget.blockingService.sync(widget.ruleStore);
    if (!mounted) return;
    setState(() {
      final rules = _rules;
      if (rules == null) return;
      _rules = [
        for (final candidate in rules)
          if (candidate.id == rule.id) replacement else candidate,
      ];
    });
  }

  Future<void> _duplicate(BlockRule rule) async {
    await widget.ruleStore.insert(
      BlockRule(
        id: 0,
        name: '${rule.name} (copy)',
        packages: rule.packages,
        websites: rule.websites,
        keywords: rule.keywords,
        trigger: rule.trigger,
        enabled: rule.enabled,
      ),
    );
    await widget.blockingService.sync(widget.ruleStore);
    await _loadRules();
  }

  Future<void> _delete(BlockRule rule) async {
    await widget.ruleStore.delete(rule.id);
    await widget.blockingService.sync(widget.ruleStore);
    if (!mounted) return;
    setState(() => _rules?.removeWhere((candidate) => candidate.id == rule.id));
  }

  Future<void> _act(BlockRule rule, _BlockAction action) {
    return switch (action) {
      _BlockAction.edit => _openEditor(rule),
      _BlockAction.pause => _toggle(rule, false),
      _BlockAction.block => _toggle(rule, true),
      _BlockAction.duplicate => _duplicate(rule),
      _BlockAction.delete => _delete(rule),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null && _rules == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load your limits.'),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: BlockingColors.accent,
              ),
              onPressed: _loadRules,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final rules = _rules;
    if (rules == null) {
      return const Center(
        child: CircularProgressIndicator(color: BlockingColors.accent),
      );
    }

    final active = [
      for (final rule in rules)
        if (rule.enabled) rule,
    ];
    final inactive = [
      for (final rule in rules)
        if (!rule.enabled) rule,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CreateBlockButton(onPressed: () => _openEditor()),
        if (rules.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'No limits yet',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        if (active.isNotEmpty) ...[
          const _SectionHeader('Active blocks'),
          for (final rule in active)
            _BlockCard(
              rule: rule,
              onOpen: () => _openEditor(rule),
              onAction: (action) => _act(rule, action),
            ),
        ],
        if (inactive.isNotEmpty) ...[
          const _SectionHeader('Paused blocks'),
          for (final rule in inactive)
            _BlockCard(
              rule: rule,
              onOpen: () => _openEditor(rule),
              onAction: (action) => _act(rule, action),
            ),
        ],
      ],
    );
  }
}

class _CreateBlockButton extends StatelessWidget {
  const _CreateBlockButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const ValueKey('create-block'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: BlockingColors.accent,
          side: const BorderSide(color: BlockingColors.accent),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Create a block'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: BlockingColors.textMuted,
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.rule,
    required this.onOpen,
    required this.onAction,
  });

  final BlockRule rule;
  final VoidCallback onOpen;
  final ValueChanged<_BlockAction> onAction;

  @override
  Widget build(BuildContext context) {
    final tint = rule.enabled
        ? BlockingColors.accent
        : BlockingColors.textMuted;
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
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _triggerIcon(rule.trigger),
                    size: 20,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${triggerSummary(rule.trigger)}\n'
                        '${_targetSummary(rule)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: BlockingColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _BlockMenu(rule: rule, onSelected: onAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BlockAction { edit, pause, block, duplicate, delete }

const _danger = Color(0xFFF28B82);

class _BlockMenu extends StatelessWidget {
  const _BlockMenu({required this.rule, required this.onSelected});

  final BlockRule rule;
  final ValueChanged<_BlockAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BlockAction>(
      key: ValueKey('rule-menu-${rule.id}'),
      tooltip: 'Options for ${rule.name}',
      icon: const Icon(Icons.more_vert, color: BlockingColors.textMuted),
      position: PopupMenuPosition.under,
      color: BlockingColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: BlockingColors.outline),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        _item(_BlockAction.edit, Icons.edit_outlined, 'Edit'),
        if (rule.enabled)
          _item(_BlockAction.pause, Icons.pause_circle_outline, 'Pause')
        else
          _item(_BlockAction.block, Icons.block, 'Block'),
        _item(_BlockAction.duplicate, Icons.content_copy_outlined, 'Duplicate'),
        _item(_BlockAction.delete, Icons.delete_outline, 'Delete', _danger),
      ],
    );
  }

  PopupMenuItem<_BlockAction> _item(
    _BlockAction action,
    IconData icon,
    String label, [
    Color color = Colors.white,
  ]) {
    return PopupMenuItem(
      key: ValueKey('rule-${action.name}'),
      value: action,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

String _targetSummary(BlockRule rule) {
  final parts = <String>[
    if (rule.packages.isNotEmpty) _count(rule.packages.length, 'app', 'apps'),
    if (rule.websites.isNotEmpty) _count(rule.websites.length, 'site', 'sites'),
    if (rule.keywords.isNotEmpty)
      _count(rule.keywords.length, 'keyword', 'keywords'),
  ];
  return parts.join(' · ');
}

String _count(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}

IconData _triggerIcon(Trigger trigger) {
  return switch (trigger) {
    Schedule() => Icons.schedule,
    UsageQuota() => Icons.hourglass_bottom,
    LaunchQuota() => Icons.repeat,
  };
}
