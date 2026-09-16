import 'dart:async';

import 'package:flutter/material.dart';

import '../apps/app_service.dart';
import 'blocking/blocking_colors.dart';
import 'blocking/blocking_engine.dart';
import 'blocking/onboarding/permission_status.dart';
import 'blocking/rule_store.dart';
import 'blocking/widgets/rule_list.dart';
import 'pomodoro/pomodoro_store.dart';
import 'pomodoro/pomodoro_tab.dart';
import 'stats/stats_tab.dart';

enum _DashboardTab { pomodoro, blocks, strictMode, stats, settings }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.appService,
    required this.ruleStore,
    required this.blockingService,
    required this.permissionStatus,
    required this.pomodoroStore,
  });

  final AppService appService;
  final RuleStore ruleStore;
  final BlockingService blockingService;
  final PermissionStatus permissionStatus;
  final PomodoroStore pomodoroStore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  _DashboardTab _tab = _DashboardTab.blocks;
  PermissionState? _permissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  // Permissions change outside the app, so every return re-checks them and
  // lets the blocking service follow.
  Future<void> _refresh() async {
    final permissions = await widget.permissionStatus.check();
    if (mounted) setState(() => _permissions = permissions);
    await widget.blockingService.sync(widget.ruleStore);
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
    final body = switch (_tab) {
      _DashboardTab.pomodoro => PomodoroTab(
        ruleStore: widget.ruleStore,
        blockingService: widget.blockingService,
        pomodoroStore: widget.pomodoroStore,
      ),
      _DashboardTab.blocks => RuleList(
        ruleStore: widget.ruleStore,
        appService: widget.appService,
        blockingService: widget.blockingService,
      ),
      _DashboardTab.strictMode => const _ComingSoonTab(title: 'Strict mode'),
      _DashboardTab.stats => StatsTab(appService: widget.appService),
      _DashboardTab.settings => ListView(
        children: const [
          ListTile(
            title: Text('Minimal launcher'),
            subtitle: Text('Coming soon'),
          ),
        ],
      ),
    };
    final permissions = _permissions;
    final missing = permissions == null
        ? null
        : !permissions.usageAccess
        ? RequiredPermission.usageAccess
        : !permissions.overlay
        ? RequiredPermission.overlay
        : null;
    final enforces =
        _tab == _DashboardTab.pomodoro || _tab == _DashboardTab.blocks;
    if (missing == null || !enforces) return body;
    return Column(
      children: [
        _PermissionBanner(
          permission: missing,
          onAllow: () => unawaited(widget.permissionStatus.request(missing)),
        ),
        Expanded(child: body),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.permission, required this.onAllow});

  final RequiredPermission permission;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlockingColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Blocking needs ${permissionTitle(permission).toLowerCase()}.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            TextButton(
              key: const ValueKey('permission-banner-allow'),
              onPressed: onAllow,
              style: TextButton.styleFrom(
                foregroundColor: BlockingColors.accent,
              ),
              child: const Text('Allow'),
            ),
          ],
        ),
      ),
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
