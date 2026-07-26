import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';

import '../app_service.dart';

class AppOptionsDialog extends StatelessWidget {
  final AppInfo app;
  final AppService appService;

  const AppOptionsDialog({
    super.key,
    required this.app,
    required this.appService,
  });

  @override
  Widget build(BuildContext context) {
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
              child: ListTile(title: Center(child: Text(app.appName))),
            ),
            ListTile(
              title: const Text('Settings'),
              leading: const Icon(Icons.settings_outlined),
              onTap: () {
                appService.openAppSettings(app.packageName);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Uninstall'),
              leading: const Icon(Icons.delete_outline),
              onTap: () {
                appService.uninstallApp(app.packageName);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Hide app'),
              leading: const Icon(Icons.visibility_off_outlined),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
