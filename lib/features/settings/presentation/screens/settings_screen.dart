import 'package:flutter/material.dart';
import '../widgets/settings_list_item.dart';
import '../../domain/models/settings_item.dart';
import 'settings_features/apps_timer_screen.dart';
import 'settings_features/apps_usage_screen.dart';
import 'settings_features/blocked_apps_screen.dart';
import 'settings_features/hidden_apps_screen.dart';
import 'settings_features/monochrome_mode_screen.dart';
import 'settings_features/notifications_filter_screen.dart';
import 'settings_features/renamed_apps_screen.dart';

class SettingsScreen extends StatelessWidget {
  final List<SettingsItem> settingsItems = const [
    SettingsItem(
      title: 'Monochrome Mode',
      page: MonochromeModeScreen(),
    ),
    SettingsItem(
      title: 'Hidden Apps',
      page: HiddenAppsScreen(),
    ),
    SettingsItem(
      title: 'Renamed Apps',
      page: RenamedAppsScreen(),
    ),
    SettingsItem(
      title: 'Locked Apps',
      page: BlockedAppsScreen(),
    ),
    SettingsItem(
      title: 'Apps Timer',
      page: AppsTimerScreen(),
    ),
    SettingsItem(
      title: 'Notification Filter',
      page: NotificationsFilterScreen(),
    ),
    SettingsItem(
      title: 'Apps Usage',
      page: AppsUsageScreen(),
    ),
  ];

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: Colors.white, thickness: 1.0),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 7.0),
        itemCount: settingsItems.length,
        itemBuilder: (context, index) => SettingsListItem(
          item: settingsItems[index],
        ),
      ),
    );
  }
}
