import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../apps/app_service.dart';
import '../../apps/installed_app.dart';
import '../../theme.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/onboarding/permission_status.dart';
import '../blocking/rule.dart';
import '../blocking/rule_store.dart';
import '../common/glyph_map.dart';
import '../common/glyphs.dart';
import '../common/illustrations.dart';
import '../stats/usage_report.dart';
import 'onboarding_illustrations.dart';
import 'plan.dart';
import 'plan_quiz.dart';

// The promise, three questions and the plan they build, then a page for
// each permission and the finish.
const _goalPage = 1;
const _appsPage = 2;
const _limitPage = 3;
const _planPage = 4;
const _firstPermission = 5;
final _donePage = _firstPermission + RequiredPermission.values.length;

/// Asks a few questions, builds the first block from the answers, then
/// walks through the permissions and saves the block on the way out.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.permissionStatus,
    required this.appService,
    required this.ruleStore,
    required this.onFinished,
  });

  final PermissionStatus permissionStatus;
  final AppService appService;
  final RuleStore ruleStore;
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _controller = PageController();
  int _page = 0;
  // Where Skip was pressed, so Back from the permissions returns there.
  int _skippedFrom = 0;
  bool _limitShown = false;
  PermissionState? _permissions;
  UsageReport? _today;
  List<InstalledApp>? _apps;
  bool _appsFailed = false;
  Goal? _goal;
  Trigger? _trigger;
  Set<String> _packages = {};
  BlockRule? _plan;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    unawaited(_loadApps());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final permissions = await widget.permissionStatus.check();
    if (!mounted) return;
    setState(() => _permissions = permissions);
    if (permissions.usageAccess && _today == null) {
      try {
        final today = await _readTodayUsage();
        if (mounted) setState(() => _today = today);
      } on PlatformException {
        // Usage access can be reported as granted before Android serves
        // events; the page then shows the plain granted state.
      }
    }
  }

  Future<UsageReport> _readTodayUsage() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final events = await readUsageEvents(start, now);
    return summarizeUsage(events: events, bucketStarts: [start], end: now);
  }

  Future<void> _request(RequiredPermission permission) async {
    await widget.permissionStatus.request(permission);
    await _refresh();
  }

  Future<void> _loadApps() async {
    setState(() => _appsFailed = false);
    try {
      final apps = await widget.appService.getInstalledApps();
      if (mounted) setState(() => _apps = apps);
    } catch (_) {
      if (mounted) setState(() => _appsFailed = true);
    }
  }

  void _goTo(int page) {
    final duration = motion(context, 320);
    if (duration == Duration.zero) {
      _controller.jumpToPage(page);
      return;
    }
    unawaited(
      _controller.animateToPage(
        page,
        duration: duration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _next() => _goTo(_page + 1);

  // Answers stay when a question is revisited; a new goal starts its limit
  // over, since the old one belongs to another kind of block.
  void _pickGoal(Goal goal) {
    setState(() {
      if (goal != _goal) _trigger = goalTrigger(goal);
      _goal = goal;
    });
    _goTo(_appsPage);
  }

  List<String> get _names => [
    for (final app in _apps ?? const <InstalledApp>[])
      if (_packages.contains(app.packageName)) app.displayName,
  ];

  void _startPlan() {
    _plan = BlockRule(
      id: 0,
      name: ruleName(_names),
      packages: _packages,
      trigger: _trigger!,
      enabled: true,
    );
    _goTo(_firstPermission);
  }

  void _skip() {
    _plan = null;
    _skippedFrom = _page;
    _goTo(_firstPermission);
  }

  void _back() => _goTo(
    _page == _firstPermission && _plan == null ? _skippedFrom : _page - 1,
  );

  Future<void> _finish() async {
    final plan = _plan;
    if (plan == null) {
      widget.onFinished();
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.ruleStore.insert(plan);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
      return;
    }
    widget.onFinished();
  }

  List<Answer?> get _answers => [
    if (_goal case final goal?)
      (glyph: goalGlyph(goal), label: goalTitle(goal))
    else
      null,
    if (_packages.isNotEmpty)
      (glyph: Glyphs.apps, label: appsChip(_names))
    else
      null,
    if (_trigger case final trigger? when _limitShown)
      (glyph: triggerGlyph(trigger), label: limitChip(trigger))
    else
      null,
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Progress(
                page: _page,
                onSkip: _page < _firstPermission ? _skip : null,
              ),
              // The strip stays put while the questions turn beneath it.
              // AnimatedSize cannot take a zero duration, so without motion
              // the strip simply appears.
              if (MediaQuery.disableAnimationsOf(context))
                _strip()
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _strip(),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  itemCount: _donePage + 1,
                  itemBuilder: (_, page) => _buildPage(page),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strip() => _page >= _goalPage && _page < _firstPermission
      ? AnswerStrip(
          answers: _answers,
          onTap: (index) => _goTo(_goalPage + index),
        )
      : const SizedBox(width: double.infinity);

  // Skipping scrolls past the questions, so the pages that need a goal
  // stay blank until there is one.
  Widget _buildPage(int page) {
    final goal = _goal;
    final trigger = _trigger;
    return switch (page) {
      0 => _Page(
        illustration: _AnimatedHours(
          from: 4.62,
          to: 1,
          color: BlockingColors.accent,
        ),
        title: 'Your time back, starting today.',
        body: 'A few questions, then your plan.',
        primary: ('Get started', _next),
      ),
      _goalPage => GoalPage(selected: goal, onPick: _pickGoal),
      _appsPage => AppsPage(
        apps: _apps,
        failed: _appsFailed,
        selected: _packages,
        onChanged: (packages) => setState(() => _packages = packages),
        onRetry: () => unawaited(_loadApps()),
        onNext: () {
          setState(() => _limitShown = true);
          _next();
        },
      ),
      _limitPage when trigger != null => LimitPage(
        trigger: trigger,
        onChanged: (trigger) => setState(() => _trigger = trigger),
        onNext: _packages.isEmpty ? null : _next,
      ),
      _planPage when goal != null && trigger != null && _packages.isNotEmpty =>
        PlanPage(
          goal: goal,
          names: _names,
          trigger: trigger,
          onNext: _startPlan,
        ),
      _limitPage || _planPage => const SizedBox.shrink(),
      _ when page == _donePage => _finishedPage(),
      _ => _permissionPage(RequiredPermission.values[page - _firstPermission]),
    };
  }

  Widget _permissionPage(RequiredPermission permission) {
    final copy = _copy(permission);
    final granted = _permissions?.granted(permission) ?? false;
    final today = _today;
    final Widget detail;
    if (!granted) {
      detail = Text(
        copy.how,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: BlockingColors.text,
        ),
      );
    } else if (permission == RequiredPermission.usageAccess && today != null) {
      detail = _TodayReveal(today);
    } else {
      detail = Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: BlockingColors.accent),
          const SizedBox(width: 8),
          Text(
            'Allowed',
            style: TextStyle(fontSize: 14, color: BlockingColors.text),
          ),
        ],
      );
    }
    return _Page(
      illustration: PhoneIllustration(scene: copy.scene),
      title: permissionTitle(permission),
      body: copy.why,
      detail: detail,
      primary: granted
          ? ('Continue', _next)
          : (copy.action, () => unawaited(_request(permission))),
      secondary: granted ? null : ('Skip for now', _next),
    );
  }

  Widget _finishedPage() {
    final allGranted = _permissions?.requiredGranted ?? false;
    const skipped = 'Anything you skipped can be allowed later from Settings.';
    final plan = _plan;
    if (plan == null) {
      return _Page(
        illustration: HourGrid(hours: 1, color: BlockingColors.accent),
        title: 'Ready.',
        body: allGranted
            ? 'Create your first block and choose the apps it covers.'
            : skipped,
        primary: ('Continue', () => unawaited(_finish())),
      );
    }
    final save = _saving ? null : () => unawaited(_finish());
    if (_saveFailed) {
      return _Page(
        illustration: const Illustration(Scene.sunrise, size: 180),
        title: 'Your plan did not save.',
        body: 'Try again, or create it later from Blocks.',
        primary: ('Try again', save),
        secondary: ('Continue without it', widget.onFinished),
      );
    }
    return _Page(
      illustration: const Illustration(Scene.sunrise, size: 180),
      title: "You're all set.",
      body:
          '${planSentence(_names, plan.trigger)} '
          '${allGranted ? 'Change it any time from Blocks.' : skipped}',
      primary: ('Open SerenSync', save),
    );
  }
}

typedef _PermissionCopy = ({
  PhoneScene scene,
  String why,
  String how,
  String action,
});

_PermissionCopy _copy(RequiredPermission permission) {
  return switch (permission) {
    RequiredPermission.usageAccess => (
      scene: PhoneScene.usage,
      why:
          'Lets SerenSync see which app is open and how long it has been '
          'used today. Nothing leaves your phone.',
      how: 'Find SerenSync in the list and switch it on.',
      action: 'Open settings',
    ),
    RequiredPermission.overlay => (
      scene: PhoneScene.overlay,
      why: 'Puts the block screen on top of an app once its limit is reached.',
      how: 'Find SerenSync in the list and switch it on.',
      action: 'Open settings',
    ),
    RequiredPermission.notifications => (
      scene: PhoneScene.notification,
      why:
          'Android needs a visible notification while blocking runs in the '
          'background.',
      how: 'Choose Allow when Android asks.',
      action: 'Allow notifications',
    ),
    RequiredPermission.batteryOptimisation => (
      scene: PhoneScene.battery,
      why: 'Keeps blocking alive when Android trims apps to save battery.',
      how: 'Choose Allow when Android asks.',
      action: 'Allow',
    ),
    RequiredPermission.accessibility => (
      scene: PhoneScene.browser,
      why:
          'Blocks websites and keywords in the browser, and lets strict mode '
          'shut Settings the instant it opens. Not needed for app blocks.',
      how:
          'Under Downloaded apps, choose SerenSync and switch it on. If the '
          'switch is greyed out, open App info, tap the menu and allow '
          'restricted settings.',
      action: 'Open settings',
    ),
  };
}

class _Progress extends StatelessWidget {
  const _Progress({required this.page, required this.onSkip});

  final int page;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
        child: Row(
          children: [
            for (var index = 0; index < _donePage; index++) ...[
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: index <= page
                        ? BlockingColors.accent
                        : BlockingColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (index < _donePage - 1) const SizedBox(width: 4),
            ],
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: onSkip == null
                  ? null
                  : TextButton(
                      key: const ValueKey('onboarding-skip'),
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: BlockingColors.textMuted,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Skip'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.illustration,
    required this.title,
    required this.body,
    required this.primary,
    this.detail,
    this.secondary,
  });

  final Widget illustration;
  final String title;
  final String body;
  final Widget? detail;
  final (String, VoidCallback?) primary;
  final (String, VoidCallback)? secondary;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final secondary = this.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: illustration,
                ),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: BlockingColors.textMuted,
            ),
          ),
          if (detail != null) ...[const SizedBox(height: 20), detail],
          const SizedBox(height: 32),
          FilledButton(
            key: const ValueKey('onboarding-primary'),
            onPressed: primary.$2,
            child: Text(primary.$1),
          ),
          SizedBox(
            height: 48,
            child: secondary == null
                ? null
                : TextButton(
                    key: const ValueKey('onboarding-secondary'),
                    onPressed: secondary.$2,
                    style: TextButton.styleFrom(
                      foregroundColor: BlockingColors.textMuted,
                    ),
                    child: Text(secondary.$1),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedHours extends StatelessWidget {
  const _AnimatedHours({
    required this.from,
    required this.to,
    required this.color,
  });

  final double from;
  final double to;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from, end: to),
      duration: motion(context, 1100),
      curve: Curves.easeOutCubic,
      builder: (_, hours, _) => HourGrid(hours: hours, color: color),
    );
  }
}

class _TodayReveal extends StatelessWidget {
  const _TodayReveal(this.report);

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    final opens = report.opens == 1 ? '1 open' : '${report.opens} opens';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ruleDuration(report.total),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: BlockingColors.rising,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'on other apps today so far, across $opens.',
            style: TextStyle(fontSize: 14, color: BlockingColors.textMuted),
          ),
        ],
      ),
    );
  }
}
