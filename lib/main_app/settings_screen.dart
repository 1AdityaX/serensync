import 'dart:async';

import 'package:flutter/material.dart';

import '../apps/app_service.dart';
import 'blocking/blocking_engine.dart';
import 'blocking/onboarding/permission_flow.dart';
import 'blocking/onboarding/permission_status.dart';
import 'blocking/rule_store.dart';
import 'blocking/rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppService appService;

  const SettingsScreen({super.key, required this.appService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final RuleStore _ruleStore = RuleStore();

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
      body: ListView(
        padding: const EdgeInsets.only(top: 7),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListTile(
              title: const Text('App blocking'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PermissionFlow(
                    permissionStatus: PermissionStatus(),
                    ruleStore: _ruleStore,
                    blockingService: BlockingService(),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListTile(
              title: const Text('Blocking rules'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RulesScreen(
                    ruleStore: _ruleStore,
                    appService: widget.appService,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_ruleStore.close());
    super.dispose();
  }
}
