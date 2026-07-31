import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import 'app_service.dart';
import 'installed_app.dart';
import 'widgets/app_options_dialog.dart';
import 'widgets/app_search_bar.dart';

class AppsScreen extends StatefulWidget {
  final AppService appService;

  const AppsScreen({super.key, required this.appService});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<AppEvent>? _appChangesSubscription;
  List<InstalledApp>? _apps;
  Object? _loadError;
  bool _initialScanFinished = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _appChangesSubscription = widget.appService.appChanges.listen(
      (_) => _loadApps(forceRefresh: true),
    );
    _loadInitialApps();
  }

  Future<void> _loadInitialApps() async {
    try {
      final apps = await widget.appService.readPersistedApps();
      if (!mounted) return;
      setState(() => _apps = apps);
      if (apps.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadApps());
        });
        return;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
    await _loadApps();
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    try {
      final apps = await widget.appService.getInstalledApps(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loadError = null;
        _initialScanFinished = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _initialScanFinished = true;
      });
    }
  }

  List<InstalledApp> get _filteredApps {
    final apps = _apps ?? const <InstalledApp>[];
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return apps;
    return apps
        .where((app) => app.displayName.toLowerCase().contains(query))
        .toList();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(appService: widget.appService),
      ),
    );
  }

  Future<void> _openApp(InstalledApp app) async {
    setState(() => _searchQuery = '');
    await widget.appService.openApp(app);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          query: _searchQuery,
          onChanged: (query) => setState(() => _searchQuery = query),
          onOpenSettings: _openSettings,
        ),
      ),
      body: _buildBody(),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildBody() {
    final appsAreEmpty = _apps?.isEmpty ?? true;
    if (appsAreEmpty && !_initialScanFinished) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && appsAreEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Error loading apps'),
            TextButton(onPressed: _loadApps, child: const Text('Retry')),
          ],
        ),
      );
    }

    final apps = _filteredApps;
    return ListView.builder(
      padding: const EdgeInsets.only(left: 35),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(app.displayName),
          onTap: () => _openApp(app),
          onLongPress: () => showDialog<void>(
            context: context,
            builder: (_) => AppOptionsDialog(app: app),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _appChangesSubscription?.cancel();
    super.dispose();
  }
}
