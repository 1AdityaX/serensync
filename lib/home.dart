import 'package:flutter/material.dart';
import 'package:serensync/widgets/clock.dart';


class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: ClockWidget(),
    );
  }
}
