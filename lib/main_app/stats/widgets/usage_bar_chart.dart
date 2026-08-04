import 'package:flutter/material.dart';

import '../../blocking/blocking_colors.dart';
import '../../blocking/rule.dart';

const _chartHeight = 148.0;
const _emptyBarHeight = 3.0;
const _barGap = 2.0;
const _maxBarWidth = 26.0;

class UsageBarChart extends StatelessWidget {
  const UsageBarChart({
    super.key,
    required this.buckets,
    required this.labels,
    required this.names,
    required this.selectedIndex,
    required this.onSelected,
    this.currentIndex,
  });

  final List<Duration> buckets;

  /// One entry per bucket, empty where the axis stays blank.
  final List<String> labels;

  /// One entry per bucket, read out in the callout above the selected bar.
  final List<String> names;

  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  /// Bucket holding the present moment, emphasised on the axis.
  final int? currentIndex;

  @override
  Widget build(BuildContext context) {
    final peak = buckets.fold(Duration.zero, (a, b) => a > b ? a : b);
    return Column(
      children: [
        _Callout(
          text: selectedIndex == null
              ? null
              : '${names[selectedIndex!]}  ·  '
                    '${ruleDuration(buckets[selectedIndex!])}',
          position: selectedIndex == null
              ? 0
              : (selectedIndex! + 0.5) / buckets.length * 2 - 1,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _select(details.localPosition.dx, constraints.maxWidth),
            onHorizontalDragStart: (details) =>
                _select(details.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (details) =>
                _select(details.localPosition.dx, constraints.maxWidth),
            child: SizedBox(
              height: _chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < buckets.length; index++)
                    Expanded(
                      child: _Bar(
                        value: buckets[index],
                        peak: peak,
                        width: _barWidth(constraints.maxWidth),
                        dimmed: selectedIndex != null && selectedIndex != index,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    color: index == currentIndex
                        ? Colors.white
                        : BlockingColors.textMuted,
                    fontWeight: index == currentIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _barWidth(double chartWidth) {
    return (chartWidth / buckets.length - _barGap).clamp(2.0, _maxBarWidth);
  }

  void _select(double dx, double width) {
    final index = (dx / width * buckets.length).floor();
    if (index < 0 || index >= buckets.length || index == selectedIndex) return;
    onSelected(index);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.peak,
    required this.width,
    required this.dimmed,
  });

  final Duration value;
  final Duration peak;
  final double width;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final filled = value > Duration.zero && peak > Duration.zero;
    final height = filled
        ? _emptyBarHeight +
              (_chartHeight - _emptyBarHeight) *
                  (value.inSeconds / peak.inSeconds)
        : _emptyBarHeight;
    final top = dimmed
        ? BlockingColors.accent.withValues(alpha: 0.32)
        : BlockingColors.accent;
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(4),
            bottom: Radius.circular(2),
          ),
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    top,
                    top.withValues(alpha: dimmed ? 0.16 : 0.45),
                  ],
                )
              : null,
          color: filled ? null : BlockingColors.outline,
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text, required this.position});

  final String? text;

  /// Horizontal alignment of the callout, -1 at the first bar and 1 at the last.
  final double position;

  @override
  Widget build(BuildContext context) {
    final label = text;
    return SizedBox(
      height: 30,
      child: label == null
          ? const Center(
              child: Text(
                'Tap the chart to inspect',
                style: TextStyle(
                  fontSize: 11.5,
                  color: BlockingColors.textMuted,
                ),
              ),
            )
          : AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment(position, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: BlockingColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: BlockingColors.outline),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            ),
    );
  }
}
