import 'package:apps_handler/apps_handler.dart';
import '../../domain/repositories/app_repository.dart';

class AppRepositoryImpl implements AppRepository {
  @override
  Future<List<AppInfo>> getInstalledApps() async {
    final apps = await AppsHandler.getInstalledApps(
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );
    apps.sort((a, b) => a.appName.compareTo(b.appName));
    return apps;
  }

  @override
  Future<void> openApp(String packageName) async {
    await AppsHandler.openApp(packageName);
  }

  @override
  Future<void> openAppSettings(String packageName) async {
    await AppsHandler.openAppSettings(packageName);
  }

  @override
  Future<void> uninstallApp(String packageName) async {
    await AppsHandler.uninstallApp(packageName);
  }

  @override
  Stream<AppEvent> get appChanges => AppsHandler.appChanges;
}
