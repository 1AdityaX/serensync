import 'package:flutter/material.dart';

class BlockedAppsScreen extends StatelessWidget {
  const BlockedAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Blocked Apps')),
      body: Center(child: Text('Blocked Apps Page')),
    );
  }
}
