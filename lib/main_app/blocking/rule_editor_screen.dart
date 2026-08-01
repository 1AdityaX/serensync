import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../apps/app_service.dart';
import '../../apps/installed_app.dart';
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
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.rule == null ? 'Create block' : 'Edit block'),
            const Text(
              'Choose what gets blocked and when',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('rule-save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
              disabledBackgroundColor: const Color(0xFF242424),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _canSave ? _save : null,
            child: Text(widget.rule == null ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    return Column(
      children: [
        if (_saveError)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Colors.white70),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Could not save this block. Try again.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _editor()),
      ],
    );
  }

  Widget _editor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _sectionHeader(
          number: '01',
          title: 'Block details',
          caption: 'Name it and set the condition',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              _nameField(),
              const SizedBox(height: 18),
              TriggerEditor(
                trigger: _trigger,
                onChanged: (trigger) => setState(() => _trigger = trigger),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _sectionHeader(
          number: '02',
          title: 'Apps to block',
          caption: _packages.isEmpty
              ? 'Select at least one app'
              : '${_packages.length} selected',
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF111111),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: _appPicker(),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String number,
    required String title,
    required String caption,
  }) {
    return Row(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          caption,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _nameField() {
    return TextField(
      key: const ValueKey('rule-name'),
      controller: _nameController,
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Block name',
        hintText: _derivedName,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        prefixIcon: const Icon(Icons.edit_outlined, size: 19),
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
