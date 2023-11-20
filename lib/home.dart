import 'package:flutter/material.dart';
import 'package:serensync/helpers/app_open.dart';
import 'package:serensync/widgets/clock.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({Key? key});

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                openAppByName('Contacts');
              },
              iconSize: 32.0),
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: () {
                openAppByName('Camera');
              },
              iconSize: 32.0),
        ),
      ],
    );
  }
}
