import 'package:flutter/material.dart';

import '../../../main_app/blocking/blocking_colors.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Hours and minutes with the date beneath. Seconds are left out so the
/// home screen stays still.
class ClockWidget extends StatelessWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final now = DateTime.now();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _clockText(now),
              style: const TextStyle(
                fontSize: 88,
                height: 1,
                fontWeight: FontWeight.w300,
                letterSpacing: -4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_weekdays[now.weekday - 1]}, ${now.day} '
              '${_months[now.month - 1]}',
              style: const TextStyle(
                fontSize: 17,
                color: BlockingColors.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _clockText(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
