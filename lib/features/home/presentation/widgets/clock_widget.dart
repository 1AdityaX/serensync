import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class ClockWidget extends StatelessWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        return Text(
          DateFormat('HH:mm:ss').format(DateTime.now()),
          style: const TextStyle(fontSize: 50),
        );
      },
    );
  }
}
