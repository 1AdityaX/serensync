import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../apps/app_service.dart';
import '../launcher/launcher_controller.dart';
import 'blocking/blocking_engine.dart';
import 'blocking/onboarding/permission_flow.dart';
import 'blocking/onboarding/permission_status.dart';
import 'blocking/rule_store.dart';
import 'blocking/widgets/rule_list.dart';
import 'stats/stats_tab.dart';

enum _DashboardTab { pomodoro, blocks, strictMode, stats, settings }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.appService,
    required this.launcherController,
    required this.ruleStore,
  });

  final AppService appService;
  final LauncherController launcherController;
  final RuleStore ruleStore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  _DashboardTab _tab = _DashboardTab.blocks;
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
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) =>
            setState(() => _tab = _DashboardTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            label: 'Pomodoro',
          ),
          NavigationDestination(
            icon: Icon(Icons.block_outlined),
            label: 'Blocks',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            label: 'Strict',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _DashboardTab.pomodoro:
        return const _ComingSoonTab(title: 'Pomodoro');
      case _DashboardTab.blocks:
        return RuleList(
          ruleStore: widget.ruleStore,
          appService: widget.appService,
        );
      case _DashboardTab.strictMode:
        return const _ComingSoonTab(title: 'Strict mode');
      case _DashboardTab.stats:
        return StatsTab(appService: widget.appService);
      case _DashboardTab.settings:
        return _SettingsTab(
          ruleStore: widget.ruleStore,
          launcherEnabled: _launcherEnabled,
          launcherChanging: _launcherChanging,
          onLauncherChanged: _setLauncherEnabled,
        );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.ruleStore,
    required this.launcherEnabled,
    required this.launcherChanging,
    required this.onLauncherChanged,
  });

  final RuleStore ruleStore;
  final bool launcherEnabled;
  final bool launcherChanging;
  final ValueChanged<bool> onLauncherChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          key: const ValueKey('app-blocking'),
          title: const Text('App blocking'),
          subtitle: const Text('Permissions and enforcement'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PermissionFlow(
                permissionStatus: PermissionStatus(),
                ruleStore: ruleStore,
                blockingService: BlockingService(),
              ),
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('launcher-toggle'),
          title: const Text('Minimal launcher'),
          subtitle: const Text('Use SerenSync as your Home app'),
          value: launcherEnabled,
          onChanged: launcherChanging ? null : onLauncherChanged,
        ),
      ],
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title is coming soon',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
