import 'package:flutter/material.dart';

class MonochromeModeScreen extends StatelessWidget {
  const MonochromeModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monochrome Mode')),
      body: const Center(child: Text('Monochrome Mode Page')),
    );
  }
}
