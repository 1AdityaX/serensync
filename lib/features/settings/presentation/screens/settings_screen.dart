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
  const SettingsScreen({super.key});

  static final List<SettingsItem> _settingsItems = [
    SettingsItem(title: 'Monochrome Mode', builder: (_) => const MonochromeModeScreen()),
    SettingsItem(title: 'Hidden Apps', builder: (_) => const HiddenAppsScreen()),
    SettingsItem(title: 'Renamed Apps', builder: (_) => const RenamedAppsScreen()),
    SettingsItem(title: 'Locked Apps', builder: (_) => const BlockedAppsScreen()),
    SettingsItem(title: 'Apps Timer', builder: (_) => const AppsTimerScreen()),
    SettingsItem(title: 'Notification Filter', builder: (_) => const NotificationsFilterScreen()),
    SettingsItem(title: 'Apps Usage', builder: (_) => const AppsUsageScreen()),
  ];

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
        itemCount: _settingsItems.length,
        itemBuilder: (context, index) => SettingsListItem(
          item: _settingsItems[index],
        ),
      ),
    );
  }
}
