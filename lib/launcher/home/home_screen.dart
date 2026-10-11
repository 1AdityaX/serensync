import 'package:flutter/material.dart';

import '../../main_app/blocking/blocking_colors.dart';
import '../../main_app/common/glyphs.dart';
import 'home_shortcuts.dart';
import 'widgets/clock_widget.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenDialer;
  final VoidCallback onOpenCamera;

  const HomeScreen({
    super.key,
    this.onOpenDialer = openDialer,
    this.onOpenCamera = openCamera,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 2),
          const ClockWidget(),
          const Spacer(flex: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: Row(
              children: [
                _Shortcut(
                  glyph: Glyphs.phone,
                  label: 'Phone',
                  onPressed: onOpenDialer,
                ),
                Expanded(
                  child: Glyph(
                    Glyphs.swipe,
                    size: 20,
                    color: BlockingColors.textMuted,
                    semanticLabel: 'Swipe for apps',
                  ),
                ),
                _Shortcut(
                  glyph: Glyphs.camera,
                  label: 'Camera',
                  onPressed: onOpenCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.glyph,
    required this.label,
    required this.onPressed,
  });

  final Glyphs glyph;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      icon: Glyph(glyph, size: 26),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(60, 60),
        foregroundColor: BlockingColors.text,
      ),
    );
  }
}
