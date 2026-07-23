import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import 'app_service.dart';
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
  List<AppInfo>? _apps;
  Object? _loadError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _subscribeToAppChanges();
    _loadApps();
  }

  @override
  void didUpdateWidget(AppsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appService != widget.appService) {
      _appChangesSubscription?.cancel();
      _subscribeToAppChanges();
      _apps = null;
      _loadApps();
    }
  }

  void _subscribeToAppChanges() {
    _appChangesSubscription = widget.appService.appChanges.listen(
      (_) => _loadApps(forceRefresh: true),
    );
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  List<AppInfo> get _filteredApps {
    final apps = _apps ?? const <AppInfo>[];
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return apps;
    return apps
        .where((app) => app.appName.toLowerCase().contains(query))
        .toList();
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openApp(AppInfo app) async {
    setState(() => _searchQuery = '');
    await widget.appService.openApp(app.packageName);
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
    if (_loadError != null && _apps == null) {
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

    if (_apps == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final apps = _filteredApps;
    return ListView.builder(
      padding: const EdgeInsets.only(left: 35),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(app.appName),
          onTap: () => _openApp(app),
          onLongPress: () => showDialog<void>(
            context: context,
            builder: (_) =>
                AppOptionsDialog(app: app, appService: widget.appService),
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
