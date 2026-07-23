import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _settingsTitles = <String>[
    'Monochrome Mode',
    'Hidden Apps',
    'Renamed Apps',
    'Locked Apps',
    'Apps Timer',
    'Notification Filter',
    'Apps Usage',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white, thickness: 1),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 7),
        itemCount: _settingsTitles.length,
        itemBuilder: (context, index) {
          final title = _settingsTitles[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListTile(
              title: Text(title),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PlaceholderSettingsScreen(title: title),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaceholderSettingsScreen extends StatelessWidget {
  final String title;

  const _PlaceholderSettingsScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Page')),
    );
  }
}
