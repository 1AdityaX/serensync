import 'package:apps_handler/apps_handler.dart';

/// The single boundary between the Flutter UI and the native apps plugin.
class AppService {
  List<AppInfo>? _cachedApps;
  Future<List<AppInfo>>? _appsLoad;

  Future<List<AppInfo>> getInstalledApps({bool forceRefresh = false}) {
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

    final appsLoad = _loadInstalledApps();
    _appsLoad = appsLoad;
    return appsLoad.whenComplete(() {
      if (identical(_appsLoad, appsLoad)) {
        _appsLoad = null;
      }
    });
  }

  Future<List<AppInfo>> _loadInstalledApps() async {
    final apps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return _cachedApps = List.unmodifiable(apps);
  }

  Future<void> openApp(String packageName) async {
    await AppsHandler.openApp(packageName);
  }

  Future<void> openAppSettings(String packageName) async {
    await AppsHandler.openAppSettings(packageName);
  }

  Future<void> uninstallApp(String packageName) async {
    await AppsHandler.uninstallApp(packageName);
  }

  Stream<AppEvent> get appChanges => AppsHandler.appChanges;
}
