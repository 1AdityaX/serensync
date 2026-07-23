import 'package:flutter/material.dart';

import 'home_shortcuts.dart';
import 'widgets/clock_widget.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenDialer;
  final VoidCallback onOpenCamera;

  const HomeScreen({
    super.key,
    this.onOpenDialer = openDialer,
    this.onOpenCamera = openCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Center(child: ClockWidget()),
        Positioned(
          bottom: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.call),
            onPressed: onOpenDialer,
            iconSize: 32,
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: onOpenCamera,
            iconSize: 32,
          ),
        ),
      ],
    );
  }
}
