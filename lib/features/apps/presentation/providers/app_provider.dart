import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apps_handler/apps_handler.dart';
import '../../data/repositories/app_repository_impl.dart';
import '../../domain/repositories/app_repository.dart';

final appRepositoryProvider = Provider<AppRepository>(
  (ref) => AppRepositoryImpl(),
);

final appsProvider = AsyncNotifierProvider<AppsNotifier, List<AppInfo>>(
  AppsNotifier.new,
);

class AppsNotifier extends AsyncNotifier<List<AppInfo>> {
  @override
  Future<List<AppInfo>> build() async {
    final repo = ref.read(appRepositoryProvider);
    final sub = repo.appChanges.listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);
    return repo.getInstalledApps();
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;

  void clear() => state = '';
}

final filteredAppsProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  return ref.watch(appsProvider).whenData(
    (apps) => query.isEmpty
        ? apps
        : apps.where((a) => a.appName.toLowerCase().contains(query)).toList(),
  );
});
