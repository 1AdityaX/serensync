import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../blocking_engine.dart';
import '../rule_store.dart';
import 'permission_status.dart';

class PermissionFlow extends StatefulWidget {
  const PermissionFlow({
    super.key,
    required this.permissionStatus,
    required this.ruleStore,
    required this.blockingService,
  });

  final PermissionStatus permissionStatus;
  final RuleStore ruleStore;
  final BlockingService blockingService;

  @override
  State<PermissionFlow> createState() => _PermissionFlowState();
}

class _PermissionFlowState extends State<PermissionFlow>
    with WidgetsBindingObserver {
  PermissionState? _permissions;
  bool _hasEnabledRule = false;
  bool _serviceRunning = false;
  String? _startError;

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

  Future<void> _refresh() async {
    final permissions = await widget.permissionStatus.check();
    final rules = await widget.ruleStore.readAll();
    final serviceRunning = await widget.blockingService.isRunning;
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _hasEnabledRule = rules.any((rule) => rule.enabled);
      _serviceRunning = serviceRunning;
    });
  }

  Future<void> _request(RequiredPermission permission) async {
    await widget.permissionStatus.request(permission);
    await _refresh();
  }

  Future<void> _start() async {
    final result = await widget.blockingService.start();
    if (!mounted) return;
    setState(() {
      _startError = switch (result) {
        ServiceRequestSuccess() => null,
        ServiceRequestFailure(:final error) =>
          'Unable to start blocking: $error',
      };
    });
    await _refresh();
  }

  Future<void> _stop() async {
    await widget.blockingService.stop();
    await _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return Scaffold(
      appBar: AppBar(title: const Text('App blocking')),
      body: permissions == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'Grant these permissions before SerenSync can block apps.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                for (final permission in RequiredPermission.values)
                  _PermissionTile(
                    permission: permission,
                    granted: permissions.granted(permission),
                    onRequest: () => _request(permission),
                  ),
                const Divider(color: Colors.white),
                _BlockingControl(
                  permissions: permissions,
                  hasEnabledRule: _hasEnabledRule,
                  running: _serviceRunning,
                  startError: _startError,
                  onStart: _start,
                  onStop: _stop,
                ),
              ],
            ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.granted,
    required this.onRequest,
  });

  final RequiredPermission permission;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final details = switch (permission) {
      RequiredPermission.usageAccess => (
        title: 'Usage access',
        reason: 'Detect which app is open and read today\'s use.',
      ),
      RequiredPermission.overlay => (
        title: 'Display over other apps',
        reason: 'Show the blocking screen over a restricted app.',
      ),
      RequiredPermission.notifications => (
        title: 'Notifications',
        reason: 'Keep the required blocking notification visible.',
      ),
      RequiredPermission.batteryOptimisation => (
        title: 'Battery optimisation',
        reason: 'Keep blocking active when Android saves battery.',
      ),
    };
    return ListTile(
      title: Text(details.title),
      subtitle: Text(details.reason),
      trailing: granted
          ? const Text('Granted', style: TextStyle(color: Colors.white70))
          : TextButton(
              key: ValueKey('grant-${permission.name}'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: onRequest,
              child: const Text('Allow'),
            ),
    );
  }
}

class _BlockingControl extends StatelessWidget {
  const _BlockingControl({
    required this.permissions,
    required this.hasEnabledRule,
    required this.running,
    required this.startError,
    required this.onStart,
    required this.onStop,
  });

  final PermissionState permissions;
  final bool hasEnabledRule;
  final bool running;
  final String? startError;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final hasEnforcementPermissions =
        permissions.usageAccess && permissions.overlay;
    final canStart = permissions.allGranted && hasEnabledRule;
    final enforcing = running && hasEnforcementPermissions && hasEnabledRule;
    final status = enforcing
        ? 'Blocking is on'
        : running
        ? 'Blocking is on but cannot enforce'
        : 'Blocking is off';
    final detail = !hasEnforcementPermissions
        ? 'Grant ${_missingEnforcementPermissions()} before SerenSync can enforce.'
        : !hasEnabledRule
        ? 'Enable a blocking rule before SerenSync can enforce.'
        : !permissions.allGranted
        ? 'SerenSync is enforcing your enabled rules. Grant ${_missingPermissions()} to keep it running.'
        : enforcing
        ? 'SerenSync is enforcing your enabled rules.'
        : 'Turn on blocking to enforce your enabled rules.';
    final error = startError;
    return ListTile(
      title: Text(status),
      subtitle: error == null
          ? Text(detail)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[Text(detail), Text(error)],
            ),
      trailing: TextButton(
        key: const ValueKey('blocking-toggle'),
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        onPressed: running
            ? onStop
            : canStart
            ? onStart
            : null,
        child: Text(running ? 'Turn off' : 'Turn on'),
      ),
    );
  }

  String _missingPermissions() {
    final missing = <String>[
      if (!permissions.usageAccess) 'usage access',
      if (!permissions.overlay) 'display-over-other-apps permission',
      if (!permissions.notifications) 'notification permission',
      if (!permissions.batteryOptimisation) 'battery optimisation',
    ];
    return missing.join(' and ');
  }

  String _missingEnforcementPermissions() {
    final missing = <String>[
      if (!permissions.usageAccess) 'usage access',
      if (!permissions.overlay) 'display-over-other-apps permission',
    ];
    return missing.join(' and ');
  }
}
