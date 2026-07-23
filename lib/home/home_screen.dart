import 'package:flutter/material.dart';

import '../apps/app_service.dart';
import 'widgets/clock_widget.dart';

// Standard AOSP package names. Adjust for device-specific variants via settings.
const _phonePackage = 'com.android.dialer';
const _cameraPackage = 'com.android.camera2';

class HomeScreen extends StatelessWidget {
  final AppService appService;

  const HomeScreen({super.key, required this.appService});

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
            onPressed: () => appService.openApp(_phonePackage),
            iconSize: 32,
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => appService.openApp(_cameraPackage),
            iconSize: 32,
          ),
        ),
      ],
    );
  }
}
