import 'package:flutter/material.dart';

class MonochromeModeScreen extends StatelessWidget {
  const MonochromeModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Monochrome Mode')),
      body: Center(child: Text('Monochrome Mode Page')),
    );
  }
}
