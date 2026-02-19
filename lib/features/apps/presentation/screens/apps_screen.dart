import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apps_handler/apps_handler.dart';
import '../providers/app_provider.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/app_options_dialog.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredApps = ref.watch(filteredAppsProvider);

    return Scaffold(
      appBar: AppBar(title: const AppSearchBar()),
      body: filteredApps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Error loading apps')),
        data: (apps) => ListView.builder(
          padding: const EdgeInsets.only(left: 35),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(app.appName),
              onTap: () {
                ref.read(appRepositoryProvider).openApp(app.packageName);
                ref.read(searchQueryProvider.notifier).clear();
              },
              onLongPress: () => _showAppOptions(context, app),
            );
          },
        ),
      ),
    );
  }

  void _showAppOptions(BuildContext context, AppInfo app) {
    showDialog(
      context: context,
      builder: (_) => AppOptionsDialog(app: app),
    );
  }
}
