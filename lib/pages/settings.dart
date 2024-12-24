import 'package:flutter/material.dart';
import 'package:serensync/pages/settingsPages/apps_timer.dart';
import 'package:serensync/pages/settingsPages/apps_usage.dart';
import 'package:serensync/pages/settingsPages/hidden_apps.dart';
import 'package:serensync/pages/settingsPages/monochrome_mode.dart';
import 'package:serensync/pages/settingsPages/renamed_apps.dart';
import 'package:serensync/pages/settingsPages/blocked_apps.dart';
import 'package:serensync/pages/settingsPages/notifications_filter.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Map of setting items to their corresponding pages
    final Map<String, Widget> settingsPages = {
      'Monochrome Mode': MonochromeModePage(),
      'Hidden Apps': HiddenAppsPage(),
      'Renamed Apps': RenamedAppsPage(),
      'Locked Apps': BlockedAppsPage(),
      'Apps Timer': AppsTimerPage(),
      'Notification filter': NotificationsFilterPage(),
      'Apps Usage': AppsUsagePage(),
    };

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          title: const Text('Settings'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Divider(
              height: 1.0,
              color: Colors.white,
              thickness: 1.0,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 7.0),
        child: ListView.builder(
          itemCount: settingsPages.length,
          itemBuilder: (context, index) {
            final entry = settingsPages.entries.elementAt(index);
            return Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: ListTile(
                title: Text(entry.key), // Key of the map (setting name)
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => entry.value), // Value of the map (corresponding page)
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
