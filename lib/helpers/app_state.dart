import 'package:device_apps/device_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appsProvider = AsyncNotifierProvider<AppsNotifier, List<Application>>(() {
  return AppsNotifier();
});

class AppsNotifier extends AsyncNotifier<List<Application>> {
  @override
  Future<List<Application>> build() async {
    // Listen to app install/uninstall events
    DeviceApps.listenToAppsChanges().listen((event) {
      // Refresh the apps list when changes occur
      ref.invalidateSelf();
    });
    return _loadApps();
  }

  Future<List<Application>> _loadApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  }
}