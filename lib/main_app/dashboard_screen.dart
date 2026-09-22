import 'dart:async';

import 'package:flutter/material.dart';

import '../apps/app_service.dart';
import '../theme.dart';
import 'blocking/blocking_colors.dart';
import 'blocking/blocking_engine.dart';
import 'blocking/onboarding/permission_status.dart';
import 'blocking/rule_store.dart';
import 'blocking/widgets/rule_list.dart';
import 'pomodoro/pomodoro_store.dart';
import 'pomodoro/pomodoro_tab.dart';
import 'stats/stats_tab.dart';
import 'strict/strict_mode.dart';
import 'strict/strict_mode_store.dart';
import 'strict/strict_tab.dart';

enum _DashboardTab { pomodoro, blocks, strictMode, stats, settings }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.appService,
    required this.ruleStore,
    required this.blockingService,
    required this.permissionStatus,
    required this.pomodoroStore,
    required this.strictModeStore,
  });

  final AppService appService;
  final RuleStore ruleStore;
  final BlockingService blockingService;
  final PermissionStatus permissionStatus;
  final PomodoroStore pomodoroStore;
  final StrictModeStore strictModeStore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  _DashboardTab _tab = _DashboardTab.blocks;
  PermissionState? _permissions;
  bool _rulesLocked = false;

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
  // lets the blocking service follow. The rule lock is applied first so a
  // failing permission check cannot leave the rules open.
  Future<void> _refresh() async {
    final strict = await widget.strictModeStore.read();
    final rulesLocked =
        strict != null && !strictModeEnded(strict, DateTime.now());
    if (mounted) setState(() => _rulesLocked = rulesLocked);
    final permissions = await widget.permissionStatus.check();
    if (mounted) setState(() => _permissions = permissions);
    await widget.blockingService.sync(widget.ruleStore);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_tab) {
      _DashboardTab.pomodoro => 'Pomodoro',
      _DashboardTab.blocks => 'Blocks',
      _DashboardTab.strictMode => 'Strict mode',
      _DashboardTab.stats => 'Stats',
      _DashboardTab.settings => 'Settings',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
        locked: _rulesLocked,
      ),
      _DashboardTab.strictMode => StrictTab(
        ruleStore: widget.ruleStore,
        blockingService: widget.blockingService,
        strictModeStore: widget.strictModeStore,
        onChanged: () => unawaited(_refresh()),
      ),
      _DashboardTab.stats => StatsTab(appService: widget.appService),
      _DashboardTab.settings => _SettingsTab(
        permissions: _permissions,
        onAllow: (permission) =>
            unawaited(widget.permissionStatus.request(permission)),
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
        _tab != _DashboardTab.stats && _tab != _DashboardTab.settings;
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
              child: const Text('Allow'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a permission skipped during setup can be granted later.
class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.permissions, required this.onAllow});

  final PermissionState? permissions;
  final ValueChanged<RequiredPermission> onAllow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const _SettingsHeader('Permissions'),
        for (final permission in RequiredPermission.values)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(permissionTitle(permission)),
            trailing: permissions?.granted(permission) ?? false
                ? const Icon(Icons.check, color: BlockingColors.accent)
                : TextButton(
                    onPressed: () => onAllow(permission),
                    child: const Text('Allow'),
                  ),
          ),
        const _SettingsHeader('Launcher'),
        const ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4),
          title: Text('Minimal launcher'),
          subtitle: Text(
            'Coming soon',
            style: TextStyle(color: BlockingColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
      child: Text(title, style: sectionLabel),
    );
  }
}
