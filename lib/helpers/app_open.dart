import 'package:device_apps/device_apps.dart';

Future<void> openAppByName(String app) async {
  final apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true, includeSystemApps: true);

  final appData = apps.firstWhere((appNS) => appNS.appName == app);

  DeviceApps.openApp(appData.packageName);
}
