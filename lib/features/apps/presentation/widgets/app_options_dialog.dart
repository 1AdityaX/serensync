import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apps_handler/apps_handler.dart';
import '../providers/app_provider.dart';

class AppOptionsDialog extends ConsumerWidget {
  final AppInfo app;

  const AppOptionsDialog({
    super.key,
    required this.app,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(appRepositoryProvider);

    return Dialog(
      child: Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          color: Colors.black,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
              ),
              child: ListTile(
                title: Center(child: Text(app.appName)),
              ),
            ),
            ListTile(
              title: const Text('Settings'),
              leading: const Icon(Icons.settings_outlined),
              onTap: () {
                repo.openAppSettings(app.packageName);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Uninstall'),
              leading: const Icon(Icons.delete_outline),
              onTap: () {
                repo.uninstallApp(app.packageName);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Hide app'),
              leading: const Icon(Icons.visibility_off_outlined),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              title: const Text('Lock App'),
              leading: const Icon(Icons.lock_outline),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
