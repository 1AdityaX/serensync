import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../apps/app_service.dart';
import '../blocking_engine.dart';
import '../rule.dart';
import '../rule_editor_screen.dart';
import '../rule_store.dart';

class RuleList extends StatefulWidget {
  const RuleList({
    super.key,
    required this.ruleStore,
    required this.appService,
  });

  final RuleStore ruleStore;
  final AppService appService;

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
      trigger: rule.trigger,
      enabled: enabled,
    );
    await widget.ruleStore.update(replacement);
    FlutterForegroundTask.sendDataToTask(rulesChangedSignal);
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

  Future<void> _delete(BlockRule rule) async {
    await widget.ruleStore.delete(rule.id);
    FlutterForegroundTask.sendDataToTask(rulesChangedSignal);
    if (!mounted) return;
    setState(() => _rules?.removeWhere((candidate) => candidate.id == rule.id));
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
              style: TextButton.styleFrom(foregroundColor: Colors.white),
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
        child: CircularProgressIndicator(color: Colors.white),
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
            child: Text('No limits yet', style: TextStyle(color: Colors.white70)),
          ),
        if (active.isNotEmpty) ...[
          const _SectionHeader('Active blocks'),
          for (final rule in active)
            _BlockCard(
              rule: rule,
              onOpen: () => _openEditor(rule),
              onToggle: (enabled) => _toggle(rule, enabled),
              onDelete: () => _delete(rule),
            ),
        ],
        if (inactive.isNotEmpty) ...[
          const _SectionHeader('Inactive blocks'),
          for (final rule in inactive)
            _BlockCard(
              rule: rule,
              onOpen: () => _openEditor(rule),
              onToggle: (enabled) => _toggle(rule, enabled),
              onDelete: () => _delete(rule),
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
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
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
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.rule,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final BlockRule rule;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final appCount = rule.packages.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onOpen,
        title: Text(rule.name),
        subtitle: Row(
          children: [
            Icon(_triggerIcon(rule.trigger), size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${triggerSummary(rule.trigger)} · '
                '$appCount ${appCount == 1 ? 'app' : 'apps'}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: ValueKey('rule-enabled-${rule.id}'),
              value: rule.enabled,
              onChanged: onToggle,
            ),
            IconButton(
              key: ValueKey('delete-rule-${rule.id}'),
              tooltip: 'Delete ${rule.name}',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _triggerIcon(Trigger trigger) {
  return switch (trigger) {
    Schedule() => Icons.schedule,
    UsageQuota() => Icons.hourglass_bottom,
    LaunchQuota() => Icons.repeat,
  };
}
