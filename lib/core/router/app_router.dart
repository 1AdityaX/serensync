import 'package:flutter/material.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<void> settings() => MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      );
}
