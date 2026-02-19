import 'package:flutter/material.dart';
import '../../domain/models/settings_item.dart';

class SettingsListItem extends StatelessWidget {
  final SettingsItem item;

  const SettingsListItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: ListTile(
        title: Text(item.title),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: item.builder),
        ),
      ),
    );
  }
}
