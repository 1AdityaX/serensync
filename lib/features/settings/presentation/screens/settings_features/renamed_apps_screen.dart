import 'package:flutter/material.dart';

class RenamedAppsScreen extends StatelessWidget {
  const RenamedAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Renamed Apps')),
      body: const Center(child: Text('Renamed Apps Page')),
    );
  }
}
