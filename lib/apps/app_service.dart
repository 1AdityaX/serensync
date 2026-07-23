import 'package:apps_handler/apps_handler.dart';

/// The single boundary between the Flutter UI and the native apps plugin.
class AppService {
  const AppService();

  Future<List<AppInfo>> getInstalledApps() async {
    final apps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
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
