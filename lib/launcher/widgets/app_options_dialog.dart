import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';

import '../../apps/installed_app.dart';

class AppOptionsDialog extends StatelessWidget {
  final InstalledApp app;

  const AppOptionsDialog({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: Colors.white)),
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
              child: ListTile(title: Center(child: Text(app.displayName))),
            ),
            ListTile(
              title: const Text('Settings'),
              leading: const Icon(Icons.settings_outlined),
              onTap: () {
                unawaited(AppsHandler.openAppSettings(app.packageName));
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Uninstall'),
              leading: const Icon(Icons.delete_outline),
              onTap: () {
                unawaited(AppsHandler.uninstallApp(app.packageName));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
