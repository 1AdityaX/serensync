import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apps_handler/apps_handler.dart';
import '../services/app_service.dart';

final appServiceProvider = Provider<AppService>((ref) => AppService());

final appsProvider = AsyncNotifierProvider<AppsNotifier, List<AppInfo>>(() {
  return AppsNotifier();
});

class AppsNotifier extends AsyncNotifier<List<AppInfo>> {
  @override
  Future<List<AppInfo>> build() async {
    ref.read(appServiceProvider).appChanges.listen((event) {
      ref.invalidateSelf();
    });
    return ref.read(appServiceProvider).getInstalledApps();
  }
}
