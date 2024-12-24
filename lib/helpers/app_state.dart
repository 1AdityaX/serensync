import 'package:apps_handler/apps_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appsProvider = AsyncNotifierProvider<AppsNotifier, List<AppInfo>>(() {
  return AppsNotifier();
});

class AppsNotifier extends AsyncNotifier<List<AppInfo>> {
  @override
  Future<List<AppInfo>> build() async {
    // Listen to app install/uninstall events
    AppsHandler.appChanges.listen((event) {
      // Refresh the apps list when changes occur
      ref.invalidateSelf();
    });
    return _loadApps();
  }

  Future<List<AppInfo>> _loadApps() async {
    final apps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  }
}