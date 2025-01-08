import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_provider.dart'; // Add this import
import '../widgets/clock_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appService = ref.read(appServiceProvider);

    return Stack(
      children: [
        const Center(
          child: ClockWidget(),
        ),
        Positioned(
          bottom: 16.0,
          left: 16.0,
          child: IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => appService.openAppByName('Phone'),
              iconSize: 32.0),
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: () => appService.openAppByName('Camera'),
              iconSize: 32.0),
        ),
      ],
    );
  }
}
