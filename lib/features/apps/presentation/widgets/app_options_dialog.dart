import 'package:flutter/material.dart';
import 'package:apps_handler/apps_handler.dart';

class AppOptionsDialog extends StatelessWidget {
  final AppInfo app;

  const AppOptionsDialog({
    super.key,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(0),
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
            Material(
              child: ListTile(
                title: const Text('Settings'),
                leading: const Icon(Icons.settings_outlined),
                onTap: () {
                  AppsHandler.openAppSettings(app.packageName);
                  Navigator.of(context).pop();
                },
              ),
            ),
            Material(
              child: ListTile(
                title: const Text('Uninstall'),
                leading: const Icon(Icons.delete_outline),
                onTap: () {
                  AppsHandler.uninstallApp(app.packageName);
                  Navigator.of(context).pop();
                },
              ),
            ),
            Material(
              child: ListTile(
                title: const Text('Hide app'),
                leading: const Icon(Icons.visibility_off_outlined),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            Material(
              child: ListTile(
                title: const Text('Lock App'),
                leading: const Icon(Icons.lock_outline),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
