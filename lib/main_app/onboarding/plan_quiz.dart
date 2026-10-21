import 'package:flutter/material.dart';

import '../../apps/installed_app.dart';
import '../../theme.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/rule.dart';
import '../blocking/widgets/app_picker.dart';
import '../blocking/widgets/note.dart';
import '../common/glyph_map.dart';
import '../common/glyphs.dart';
import '../pomodoro/timer_dial.dart';
import 'plan.dart';
import 'window_dial.dart';

typedef Answer = ({Glyphs glyph, String label});

/// The answers so far as chips, with a dashed slot for each one still to
/// come. Tapping a chip returns to its question.
class AnswerStrip extends StatelessWidget {
  const AnswerStrip({super.key, required this.answers, required this.onTap});

  final List<Answer?> answers;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your plan', style: sectionLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < answers.length; index++)
                switch (answers[index]) {
                  null => CustomPaint(
                    size: const Size(64, 30),
                    painter: _DashedPainter(BlockingColors.outline),
                  ),
                  final answer => _Chip(
                    key: ValueKey('plan-chip-$index'),
                    answer: answer,
                    onTap: () => onTap(index),
                  ),
                },
            ],
          ),
        ],
      ),
    );
  }
}

/// Pops into place when it first appears, and again when its label changes.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.answer, required this.onTap});

  final Answer answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(answer.label),
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, 260),
      curve: Curves.easeOutBack,
      builder: (_, value, child) => Transform.scale(
        scale: 0.6 + 0.4 * value,
        child: Opacity(opacity: value.clamp(0, 1), child: child),
      ),
      child: Material(
        color: BlockingColors.background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Glyph(answer.glyph, size: 14, color: BlockingColors.accent),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    answer.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          Radius.circular(size.height / 2),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash * 2) {
        canvas.drawPath(metric.extractPath(start, start + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

/// Picking a goal answers the question, so the page has no button.
class GoalPage extends StatelessWidget {
  const GoalPage({super.key, required this.selected, required this.onPick});

  final Goal? selected;
  final ValueChanged<Goal> onPick;

  @override
  Widget build(BuildContext context) {
    return _Step(
      title: const TextSpan(text: "What's your goal?"),
      body: 'The plan is built around it.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final goal in Goal.values)
              _OptionCard(
                key: ValueKey('goal-${goal.name}'),
                glyph: goalGlyph(goal),
                title: goalTitle(goal),
                detail: goalDetail(goal),
                selected: goal == selected,
                onTap: () => onPick(goal),
              ),
          ],
        ),
      ),
    );
  }
}

class AppsPage extends StatelessWidget {
  const AppsPage({
    super.key,
    required this.apps,
    required this.failed,
    required this.selected,
    required this.onChanged,
    required this.onRetry,
    required this.onNext,
  });

  /// Null while the installed apps load.
  final List<InstalledApp>? apps;
  final bool failed;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final apps = this.apps;
    return _Step(
      title: const TextSpan(text: 'Which apps pull you in?'),
      body: 'Pick as many as you like.',
      primary: (
        selected.isEmpty ? 'Continue' : 'Continue · ${selected.length}',
        selected.isEmpty ? null : onNext,
      ),
      child: apps != null
          ? AppPicker(
              apps: apps,
              selectedPackages: selected,
              onChanged: onChanged,
            )
          : failed
          ? Note(
              icon: Icons.error_outline,
              iconColor: BlockingColors.danger,
              message: 'Your apps could not be read.',
              action: TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// A usage or launch limit on one ring, or a window with both ends.
class LimitPage extends StatelessWidget {
  const LimitPage({
    super.key,
    required this.trigger,
    required this.onChanged,
    required this.onNext,
  });

  final Trigger trigger;
  final ValueChanged<Trigger> onChanged;

  /// Null while there are no apps to limit.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final centre = limitCentre(trigger);
    return _Step(
      title: TextSpan(text: limitQuestion(trigger)),
      body: limitHint(trigger),
      primary: ('Build my plan', onNext),
      child: SingleChildScrollView(
        child: Center(
          child: switch (trigger) {
            final Schedule schedule => WindowDial(
              start: schedule.startMinute,
              end: schedule.endMinute,
              onChanged: (start, end) => onChanged(
                Schedule(
                  weekdays: schedule.weekdays,
                  startMinute: start,
                  endMinute: end,
                ),
              ),
              // Kept clear of the hour labels either side.
              child: _RingCentre(centre, inset: 66),
            ),
            _ => TimerDial(
              fraction: limitFraction(trigger),
              color: BlockingColors.accent,
              onFractionChanged: (fraction) =>
                  onChanged(quotaAt(trigger, fraction)),
              child: _RingCentre(centre),
            ),
          },
        ),
      ),
    );
  }
}

/// Shows the plan being built for a beat, then reveals it: the gauge fills
/// and the facts lift in one after another.
class PlanPage extends StatelessWidget {
  const PlanPage({
    super.key,
    required this.goal,
    required this.names,
    required this.trigger,
    required this.onNext,
  });

  final Goal goal;
  final List<String> names;
  final Trigger trigger;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, 700),
      builder: (context, progress, _) =>
          progress < 1 ? _building() : _plan(context),
    );
  }

  Widget _building() {
    return _Step(
      eyebrow: 'Built from your answers',
      title: const TextSpan(text: 'Building your plan…'),
      primary: ('Start my plan', null),
      child: Column(
        children: [
          _Gauge(
            fraction: 0,
            child: Container(width: 72, height: 14, decoration: _bar),
          ),
          const SizedBox(height: 20),
          for (final width in const [0.8, 0.6, 0.7])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: width,
                child: Container(height: 14, decoration: _bar),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration get _bar => BoxDecoration(
    color: BlockingColors.surfaceRaised,
    borderRadius: BorderRadius.circular(7),
  );

  Widget _plan(BuildContext context) {
    final centre = planCentre(trigger);
    final facts = <(Glyphs, String, String)>[
      (Glyphs.apps, 'Apps', appsPhrase(names)),
      (triggerGlyph(trigger), 'When', triggerSummary(trigger)),
      (Glyphs.home, 'Then', 'They close and you land on a quiet home screen.'),
    ];
    return _Step(
      eyebrow: 'Built from your answers',
      title: TextSpan(
        children: [
          const TextSpan(text: 'Your plan to\n'),
          TextSpan(
            text: '${goalPhrase(goal)}.',
            style: TextStyle(color: BlockingColors.accent),
          ),
        ],
      ),
      primary: ('Start my plan', onNext),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stagger(
              index: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: limitFraction(trigger)),
                duration: motion(context, 900),
                curve: Curves.easeOutCubic,
                child: _RingCentre(centre),
                builder: (_, fraction, child) =>
                    _Gauge(fraction: fraction, child: child!),
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < facts.length; index++)
              _Stagger(
                index: index + 1,
                child: _Fact(
                  glyph: facts[index].$1,
                  eyebrow: facts[index].$2,
                  value: facts[index].$3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A question or a reveal: heading on top, the actions pinned underneath,
/// and [child] filling the space between.
class _Step extends StatelessWidget {
  const _Step({
    this.eyebrow,
    required this.title,
    this.body,
    required this.child,
    this.primary,
  });

  final String? eyebrow;
  final TextSpan title;
  final String? body;
  final Widget child;
  final (String, VoidCallback?)? primary;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final primary = this.primary;
    const titleStyle = TextStyle(
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow case final eyebrow?) ...[
            Text(eyebrow, style: sectionLabel),
            const SizedBox(height: 6),
          ],
          Text.rich(title, style: titleStyle),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: BlockingColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: child),
          if (primary != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('onboarding-primary'),
              onPressed: primary.$2,
              child: Text(primary.$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.glyph,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final Glyphs glyph;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? BlockingColors.accent : BlockingColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Glyph(glyph, size: 21, color: tint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: BlockingColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: motion(context, 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected
                        ? BlockingColors.accent
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? BlockingColors.accent
                          : BlockingColors.outline,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Glyph(
                          Glyphs.check,
                          size: 16,
                          color: BlockingColors.onAccent,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring small enough to share the page with the facts under it.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.fraction, required this.child});

  final double fraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        child: TimerDial(
          fraction: fraction,
          color: BlockingColors.accent,
          child: child,
        ),
      ),
    );
  }
}

class _RingCentre extends StatelessWidget {
  const _RingCentre(this.text, {this.inset = 40});

  final ({String big, String small}) text;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text.big,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text.small,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BlockingColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.glyph,
    required this.eyebrow,
    required this.value,
  });

  final Glyphs glyph;
  final String eyebrow;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BlockingColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Glyph(glyph, size: 18, color: BlockingColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BlockingColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lifts an item into place shortly after the ones above it.
class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.12).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, 500),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
