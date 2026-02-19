import 'package:flutter/material.dart';

class HiddenAppsScreen extends StatelessWidget {
  const HiddenAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hidden Apps')),
      body: const Center(child: Text('Hidden Apps Page')),
    );
  }
}
