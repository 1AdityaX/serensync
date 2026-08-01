import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../apps/app_service.dart';
import '../apps/installed_app.dart';
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
  List<InstalledApp> _installedApps = const <InstalledApp>[];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rule == null ? 'New limit' : 'Edit limit'),
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
      body: _body(),
    );
  }

  Widget _body() {
    return Column(
      children: [
        if (_saveError)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Could not save. Try again.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        Expanded(child: _editor()),
      ],
    );
  }

  Widget _editor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nameField(),
          const SizedBox(height: 12),
          TriggerEditor(
            trigger: _trigger,
            onChanged: (trigger) => setState(() => _trigger = trigger),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Expanded(child: _appPicker()),
        ],
      ),
    );
  }

  Widget _nameField() {
    return TextField(
      key: const ValueKey('rule-name'),
      controller: _nameController,
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Name (optional)',
        hintText: _derivedName,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _appPicker() {
    return FutureBuilder<List<InstalledApp>>(
      future: _appsLoad,
      builder: (context, snapshot) {
        final apps = snapshot.data;
        if (apps != null) {
          _installedApps = apps;
          return AppPicker(
            apps: apps,
            selectedPackages: _packages,
            onChanged: (packages) => setState(() => _packages = packages),
          );
        }
        if (snapshot.hasError) return _appLoadError();
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );
  }

  Widget _appLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load your apps.'),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => setState(
              () => _appsLoad = widget.appService.getInstalledApps(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
