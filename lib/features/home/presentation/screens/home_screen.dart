import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apps/presentation/providers/app_provider.dart';
import '../widgets/clock_widget.dart';

// Standard AOSP package names. Adjust for device-specific variants via settings.
const _phonePackage = 'com.android.dialer';
const _cameraPackage = 'com.android.camera2';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const Center(child: ClockWidget()),
        Positioned(
          bottom: 16.0,
          left: 16.0,
          child: IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => ref.read(appRepositoryProvider).openApp(_phonePackage),
            iconSize: 32.0,
          ),
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => ref.read(appRepositoryProvider).openApp(_cameraPackage),
            iconSize: 32.0,
          ),
        ),
      ],
    );
  }
}
