import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../apps/app_service.dart';
import '../launcher/launcher_controller.dart';
import 'blocking/blocking_engine.dart';
import 'blocking/onboarding/permission_flow.dart';
import 'blocking/onboarding/permission_status.dart';
import 'blocking/rule_store.dart';
import 'blocking/rules_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.appService,
    required this.launcherController,
  });

  final AppService appService;
  final LauncherController launcherController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final RuleStore _ruleStore = RuleStore();
  final BlockingService _blockingService = BlockingService();

  bool _launcherEnabled = false;
  bool _launcherChanging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshLauncher());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLauncher());
    }
  }

  Future<void> _refreshLauncher() async {
    final enabled = await widget.launcherController.isEnabled;
    if (mounted) setState(() => _launcherEnabled = enabled);
  }

  Future<void> _openBlockingSetup() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PermissionFlow(
          permissionStatus: PermissionStatus(),
          ruleStore: _ruleStore,
          blockingService: _blockingService,
        ),
      ),
    );
  }

  Future<void> _openRules() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            RulesScreen(ruleStore: _ruleStore, appService: widget.appService),
      ),
    );
  }

  Future<void> _setLauncherEnabled(bool enabled) async {
    setState(() => _launcherChanging = true);
    try {
      await widget.launcherController.setEnabled(enabled);
      if (mounted) setState(() => _launcherEnabled = enabled);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not update the launcher.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _launcherChanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SerenSync')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('App blocking'),
            subtitle: const Text('Permissions and blocking service'),
            onTap: _openBlockingSetup,
          ),
          ListTile(
            title: const Text('Blocking rules'),
            subtitle: const Text('Choose apps and set limits'),
            onTap: _openRules,
          ),
          const Divider(),
          SwitchListTile(
            key: const ValueKey('launcher-toggle'),
            title: const Text('Minimal launcher'),
            subtitle: const Text('Use SerenSync as your Home app'),
            value: _launcherEnabled,
            onChanged: _launcherChanging ? null : _setLauncherEnabled,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_ruleStore.close());
    super.dispose();
  }
}
