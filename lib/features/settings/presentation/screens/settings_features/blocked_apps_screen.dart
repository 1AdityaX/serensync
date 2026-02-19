import 'package:flutter/material.dart';

class BlockedAppsScreen extends StatelessWidget {
  const BlockedAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Apps')),
      body: const Center(child: Text('Blocked Apps Page')),
    );
  }
}
