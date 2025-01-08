import 'package:apps_handler/apps_handler.dart';

class AppService {
  Future<void> openAppByName(String app) async {
    final apps = await AppsHandler.getInstalledApps(
        onlyAppsWithLaunchIntent: true, includeSystemApps: true);
    final appData = apps.firstWhere((appNS) => appNS.appName == app);
    AppsHandler.openApp(appData.packageName);
  }

  Future<List<AppInfo>> getInstalledApps() async {
    final apps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  }

  Stream<AppEvent> get appChanges => AppsHandler.appChanges;
}
