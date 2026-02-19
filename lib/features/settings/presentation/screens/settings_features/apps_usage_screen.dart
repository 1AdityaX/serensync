import 'package:flutter/material.dart';

class AppsUsageScreen extends StatelessWidget {
  const AppsUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apps Usage')),
      body: const Center(child: Text('Apps Usage Page')),
    );
  }
}
