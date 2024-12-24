import 'package:apps_handler/apps_handler.dart';

Future<void> openAppByName(String app) async {
  final apps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true, includeSystemApps: true);

  final appData = apps.firstWhere((appNS) => appNS.appName == app);

  AppsHandler.openApp(appData.packageName);
}
