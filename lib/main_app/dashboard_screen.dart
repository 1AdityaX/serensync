import 'dart:async';

import 'package:flutter/material.dart';

import '../apps/app_service.dart';
import 'blocking/blocking_colors.dart';
import 'blocking/blocking_engine.dart';
import 'blocking/onboarding/permission_status.dart';
import 'blocking/rule_editor_screen.dart';
import 'blocking/rule_store.dart';
import 'blocking/widgets/rule_list.dart';
import 'common/cards.dart';
import 'common/glyphs.dart';
import 'pomodoro/pomodoro_store.dart';
import 'pomodoro/pomodoro_tab.dart';
import 'settings/appearance.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_tab.dart';
import 'strict/strict_mode.dart';
import 'strict/strict_mode_store.dart';
import 'strict/strict_tab.dart';
import 'today/today_tab.dart';

enum _DashboardTab { today, focus, blocks, strictMode, insights }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.appearance,
    required this.appService,
    required this.ruleStore,
    required this.blockingService,
    required this.permissionStatus,
    required this.pomodoroStore,
    required this.strictModeStore,
    this.todayUsage = readTodayUsage,
  });

  final AppearanceController appearance;
  final AppService appService;
  final RuleStore ruleStore;
  final BlockingService blockingService;
  final PermissionStatus permissionStatus;
  final PomodoroStore pomodoroStore;
  final StrictModeStore strictModeStore;
  final Future<TodayUsage?> Function() todayUsage;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  _DashboardTab _tab = _DashboardTab.today;
  PermissionState? _permissions;
  bool _rulesLocked = false;

  // Bumped to rebuild a tab from scratch after something outside it changed.
  int _generation = 0;

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

  void _show(_DashboardTab tab) => setState(() => _tab = tab);

  Future<void> _allow(RequiredPermission permission) async {
    await widget.permissionStatus.request(permission);
    await _refresh();
  }

  Future<void> _createBlock() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RuleEditorScreen(
          ruleStore: widget.ruleStore,
          appService: widget.appService,
          blockingService: widget.blockingService,
          permissionStatus: widget.permissionStatus,
          locked: _rulesLocked,
        ),
      ),
    );
    if ((saved ?? false) && mounted) {
      setState(() {
        _generation++;
        _tab = _DashboardTab.blocks;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          permissionStatus: widget.permissionStatus,
          appearance: widget.appearance,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_tab) {
      _DashboardTab.today => '',
      _DashboardTab.focus => 'Focus',
      _DashboardTab.blocks => 'Blocks',
      _DashboardTab.strictMode => 'Strict mode',
      _DashboardTab.insights => 'Insights',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const ValueKey('open-settings'),
            tooltip: 'Settings',
            onPressed: () => unawaited(_openSettings()),
            icon: const Glyph(Glyphs.settings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) => _show(_DashboardTab.values[index]),
        destinations: const [
          NavigationDestination(icon: Glyph(Glyphs.sun), label: 'Today'),
          NavigationDestination(icon: Glyph(Glyphs.timer), label: 'Focus'),
          NavigationDestination(icon: Glyph(Glyphs.block), label: 'Blocks'),
          NavigationDestination(icon: Glyph(Glyphs.shield), label: 'Strict'),
          NavigationDestination(
            icon: Glyph(Glyphs.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final key = ValueKey('${_tab.name}-$_generation');
    final body = switch (_tab) {
      _DashboardTab.today => TodayTab(
        key: key,
        appService: widget.appService,
        ruleStore: widget.ruleStore,
        pomodoroStore: widget.pomodoroStore,
        strictModeStore: widget.strictModeStore,
        permissions: _permissions,
        usage: widget.todayUsage,
        onAllow: (permission) => unawaited(_allow(permission)),
        onCreateBlock: () => unawaited(_createBlock()),
        onOpenFocus: () => _show(_DashboardTab.focus),
        onOpenBlocks: () => _show(_DashboardTab.blocks),
        onOpenStrict: () => _show(_DashboardTab.strictMode),
        onOpenInsights: () => _show(_DashboardTab.insights),
      ),
      _DashboardTab.focus => PomodoroTab(
        key: key,
        ruleStore: widget.ruleStore,
        blockingService: widget.blockingService,
        pomodoroStore: widget.pomodoroStore,
      ),
      _DashboardTab.blocks => RuleList(
        key: key,
        ruleStore: widget.ruleStore,
        appService: widget.appService,
        blockingService: widget.blockingService,
        locked: _rulesLocked,
      ),
      _DashboardTab.strictMode => StrictTab(
        key: key,
        ruleStore: widget.ruleStore,
        blockingService: widget.blockingService,
        strictModeStore: widget.strictModeStore,
        onChanged: () => unawaited(_refresh()),
      ),
      _DashboardTab.insights => StatsTab(
        key: key,
        appService: widget.appService,
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
        _tab == _DashboardTab.focus ||
        _tab == _DashboardTab.blocks ||
        _tab == _DashboardTab.strictMode;
    if (missing == null || !enforces) return body;
    return Column(
      children: [
        _PermissionBanner(
          permission: missing,
          onAllow: () => unawaited(_allow(missing)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        radius: 18,
        child: Row(
          children: [
            Glyph(Glyphs.alert, size: 20, color: BlockingColors.rising),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                permissionTitle(permission),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
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
