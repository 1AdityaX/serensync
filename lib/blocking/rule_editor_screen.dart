import 'package:flutter/material.dart';

import '../apps/app_service.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '')
      ..addListener(_nameChanged);
    _packages = Set<String>.of(rule?.packages ?? const <String>{});
    _trigger = rule?.trigger ?? TriggerEditor.defaultSchedule;
  }

  bool get _canSave =>
      !_saving &&
      _nameController.text.trim().isNotEmpty &&
      _packages.isNotEmpty;

  void _nameChanged() => setState(() {});

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final existingRule = widget.rule;
    final rule = BlockRule(
      id: existingRule?.id ?? 0,
      name: _nameController.text.trim(),
      packages: _packages,
      trigger: _trigger,
      enabled: existingRule?.enabled ?? true,
    );
    if (existingRule == null) {
      await widget.ruleStore.insert(rule);
    } else {
      await widget.ruleStore.update(rule);
    }
    signalRulesChanged();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rule == null ? 'New rule' : 'Edit rule'),
        actions: [
          TextButton(
            key: const ValueKey('rule-save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
            ),
            onPressed: _canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('rule-name'),
              controller: _nameController,
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                labelText: 'Rule name',
                labelStyle: TextStyle(color: Colors.white70),
                floatingLabelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TriggerEditor(
              trigger: _trigger,
              onChanged: (trigger) => setState(() => _trigger = trigger),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Expanded(
              child: AppPicker(
                appService: widget.appService,
                selectedPackages: _packages,
                onChanged: (packages) => setState(() => _packages = packages),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_nameChanged)
      ..dispose();
    super.dispose();
  }
}
