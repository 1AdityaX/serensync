import 'package:flutter/material.dart';

class HiddenAppsPage extends StatelessWidget {
  const HiddenAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hidden Apps')),
      body: Center(child: Text('Hidden Apps Page')),
    );
  }
}