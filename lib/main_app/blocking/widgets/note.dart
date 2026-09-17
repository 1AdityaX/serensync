import 'package:flutter/material.dart';

import '../blocking_colors.dart';

class Note extends StatelessWidget {
  const Note({
    super.key,
    this.icon = Icons.info_outline,
    this.iconColor = BlockingColors.accent,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: BlockingColors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white70)),
          ),
          if (action case final action?) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}
