import 'package:flutter/material.dart';

class AppsTimerScreen extends StatelessWidget {
  const AppsTimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apps Timer')),
      body: const Center(child: Text('Apps Timer Page')),
    );
  }
}
