import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../apps/app_service.dart';
import 'blocking_engine.dart';
import 'rule.dart';
import 'rule_editor_screen.dart';
import 'rule_store.dart';

class RulesScreen extends StatefulWidget {
  final RuleStore ruleStore;
  final AppService appService;

  const RulesScreen({
    super.key,
    required this.ruleStore,
    required this.appService,
  });

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('App limits'),
        actions: [
          IconButton(
            key: const ValueKey('add-rule'),
            tooltip: 'New limit',
            icon: const Icon(Icons.add),
            onPressed: _openEditor,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No limits yet'),
            const SizedBox(height: 8),
            const Text(
              'Pick some apps and choose\nwhen to block them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _openEditor,
              child: const Text('Add a limit'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) => _RuleTile(
        rule: rules[index],
        onOpen: () => _openEditor(rules[index]),
        onToggle: (enabled) => _toggle(rules[index], enabled),
        onDelete: () => _delete(rules[index]),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final BlockRule rule;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final appCount = rule.packages.length;
    return ListTile(
      title: Text(rule.name),
      subtitle: Text(
        '${triggerSummary(rule.trigger)} · '
        '$appCount ${appCount == 1 ? 'app' : 'apps'}',
      ),
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('rule-enabled-${rule.id}'),
            tooltip: rule.enabled
                ? 'Pause ${rule.name}'
                : 'Resume ${rule.name}',
            color: rule.enabled ? Colors.white : Colors.white70,
            icon: Icon(
              rule.enabled ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
            onPressed: () => onToggle(!rule.enabled),
          ),
          IconButton(
            key: ValueKey('delete-rule-${rule.id}'),
            tooltip: 'Delete ${rule.name}',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
