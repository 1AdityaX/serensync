import 'package:apps_handler/apps_handler.dart';

import 'app_store.dart';
import 'installed_app.dart';

/// The single boundary between the Flutter UI and the native apps plugin.
class AppService {
  AppService({AppStore? store}) : _store = store ?? AppStore();

  final AppStore _store;
  List<InstalledApp>? _cachedApps;
  Future<List<InstalledApp>>? _appsLoad;
  bool _refreshPending = false;

  Future<List<InstalledApp>> readPersistedApps() {
    return _store.readAll();
  }

  Future<List<InstalledApp>> getInstalledApps({bool forceRefresh = false}) {
    if (forceRefresh) _refreshPending = true;

    final cachedApps = _cachedApps;
    if (!forceRefresh && cachedApps != null) {
      return Future.value(cachedApps);
    }

    // Package broadcasts can arrive close together (for example, while an app
    // is being updated). Reuse an active scan instead of querying Android more
    // than once at the same time.
    final activeLoad = _appsLoad;
    if (activeLoad != null) {
      return activeLoad;
    }

    final appsLoad = _loadUntilCurrent();
    _appsLoad = appsLoad;
    return appsLoad.whenComplete(() {
      if (identical(_appsLoad, appsLoad)) {
        _appsLoad = null;
      }
    });
  }

  Future<List<InstalledApp>> _loadUntilCurrent() async {
    List<InstalledApp> apps;
    do {
      _refreshPending = false;
      apps = await _loadInstalledApps();
    } while (_refreshPending);
    return apps;
  }

  Future<List<InstalledApp>> _loadInstalledApps() async {
    final pluginApps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    final apps = [
      for (final app in pluginApps)
        InstalledApp(
          displayName: app.appName,
          packageName: app.packageName,
          activityName: app.activityName,
        ),
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));
    final installedApps = List<InstalledApp>.unmodifiable(apps);
    await _store.replaceAll(installedApps);
    return _cachedApps = installedApps;
  }

  Future<void> openApp(InstalledApp app) async {
    // The plugin API requires a full AppInfo but uses only these launch fields.
    await AppsHandler.openApp(
      AppInfo(
        appName: app.displayName,
        packageName: app.packageName,
        activityName: app.activityName,
        category: '',
        versionName: null,
        versionCode: 0,
        dataDir: '',
        systemApp: false,
        installerPackageName: null,
        enabled: true,
        installTime: 0,
        updateTime: 0,
      ),
    );
  }

  Future<void> openAppSettings(String packageName) async {
    await AppsHandler.openAppSettings(packageName);
  }

  Future<void> uninstallApp(String packageName) async {
    await AppsHandler.uninstallApp(packageName);
  }

  Stream<AppEvent> get appChanges => AppsHandler.appChanges;
}
