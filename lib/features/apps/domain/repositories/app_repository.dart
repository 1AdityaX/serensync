import 'package:apps_handler/apps_handler.dart';

abstract class AppRepository {
  Future<List<AppInfo>> getInstalledApps();
  Future<void> openApp(String packageName);
  Future<void> openAppSettings(String packageName);
  Future<void> uninstallApp(String packageName);
  Stream<AppEvent> get appChanges;
}
