import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';

import '../../apps/installed_app.dart';

class AppOptionsDialog extends StatelessWidget {
  final InstalledApp app;

  const AppOptionsDialog({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(app.displayName),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      children: <Widget>[
        ListTile(
          title: const Text('App info', style: TextStyle(fontSize: 16)),
          leading: const Icon(Icons.info_outline),
          onTap: () {
            unawaited(AppsHandler.openAppSettings(app.packageName));
            Navigator.of(context).pop();
          },
        ),
        ListTile(
          title: const Text('Uninstall', style: TextStyle(fontSize: 16)),
          leading: const Icon(Icons.delete_outline),
          onTap: () {
            unawaited(AppsHandler.uninstallApp(app.packageName));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
