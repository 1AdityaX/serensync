import 'package:flutter/material.dart';

class AppsUsagePage extends StatelessWidget {
  const AppsUsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Apps Usage')),
      body: Center(child: Text('Apps Usage Page')),
    );
  }
}