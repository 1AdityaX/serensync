import 'package:flutter/material.dart';

import '../blocking/blocking_colors.dart';
import 'glyphs.dart';
import 'illustrations.dart';

/// The flat rounded tile most content sits on.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(18),
    this.color = BlockingColors.surface,
    this.borderColor = Colors.transparent,
    this.radius = 22,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A glyph on a round tile.
class GlyphBadge extends StatelessWidget {
  const GlyphBadge(
    this.glyph, {
    super.key,
    this.color = BlockingColors.text,
    this.background = BlockingColors.background,
    this.size = 44,
  });

  final Glyphs glyph;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Glyph(glyph, size: size * 0.5, color: color),
    );
  }
}

/// A dot and a word or two, such as "Now".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? BlockingColors.accent : BlockingColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A scene, a short title and an optional action, for empty states.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.scene,
    required this.title,
    this.action,
  });

  final Scene scene;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Illustration(scene, size: 132),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 20), action],
      ],
    );
  }
}
