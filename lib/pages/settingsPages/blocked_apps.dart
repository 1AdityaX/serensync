import 'package:flutter/material.dart';

class BlockedAppsPage extends StatelessWidget {
  const BlockedAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Blocked Apps')),
      body: Center(child: Text('Blocked Apps Page')),
    );
  }
}