import 'dart:async';

import 'package:flutter/material.dart';

import '../apps/app_service.dart';
import '../blocking/blocking_engine.dart';
import '../blocking/rule_store.dart';
import '../blocking/rules_screen.dart';
import '../onboarding/permission_flow.dart';
import '../onboarding/permission_status.dart';

class SettingsScreen extends StatefulWidget {
  final AppService appService;

  const SettingsScreen({super.key, required this.appService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final RuleStore _ruleStore = RuleStore();

  static const _settingsTitles = <String>[
    'Monochrome Mode',
    'Hidden Apps',
    'Renamed Apps',
    'App blocking',
    'Blocking rules',
    'Notification Filter',
    'Apps Usage',
  ];

  void _openSetting(BuildContext context, String title) {
    final screen = switch (title) {
      'App blocking' => PermissionFlow(
        permissionStatus: PermissionStatus(),
        ruleStore: _ruleStore,
        blockingService: BlockingService(),
      ),
      'Blocking rules' => RulesScreen(
        ruleStore: _ruleStore,
        appService: widget.appService,
      ),
      _ => _PlaceholderSettingsScreen(title: title),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white, thickness: 1),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 7),
        itemCount: _settingsTitles.length,
        itemBuilder: (context, index) {
          final title = _settingsTitles[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListTile(
              title: Text(title),
              onTap: () => _openSetting(context, title),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_ruleStore.close());
    super.dispose();
  }
}

class _PlaceholderSettingsScreen extends StatelessWidget {
  final String title;

  const _PlaceholderSettingsScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Page')),
    );
  }
}
