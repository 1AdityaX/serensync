import 'package:device_apps/device_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appsProvider = FutureProvider<List<Application>>((ref) async {
  final apps = await DeviceApps.getInstalledApplications(
    onlyAppsWithLaunchIntent: true,
    includeSystemApps: true,
  );
  
  // Sort the list by app name
  apps.sort((a, b) => a.appName.compareTo(b.appName));

  return apps;
});