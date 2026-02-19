import 'package:flutter/widgets.dart';

class SettingsItem {
  final String title;
  final WidgetBuilder builder;

  const SettingsItem({
    required this.title,
    required this.builder,
  });
}
