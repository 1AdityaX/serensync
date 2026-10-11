import 'package:flutter/material.dart';

import '../blocking_colors.dart';

class Note extends StatelessWidget {
  const Note({
    super.key,
    this.icon = Icons.info_outline,
    this.iconColor,
    required this.message,
    this.action,
  });

  final IconData icon;

  /// Defaults to the accent.
  final Color? iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? BlockingColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: BlockingColors.textMuted,
              ),
            ),
          ),
          if (action case final action?) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}
