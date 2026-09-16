import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blocking/blocking_colors.dart';
import '../blocking/onboarding/permission_status.dart';
import '../blocking/rule.dart';
import '../stats/usage_report.dart';
import 'onboarding_illustrations.dart';

const _storyPages = 3;
final _donePage = _storyPages + RequiredPermission.values.length;
const _pageTurn = Duration(milliseconds: 320);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.permissionStatus,
    required this.onFinished,
  });

  final PermissionStatus permissionStatus;
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _controller = PageController();
  int _page = 0;
  PermissionState? _permissions;
  UsageReport? _today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
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

  void _goTo(int page) {
    unawaited(
      _controller.animateToPage(
        page,
        duration: _pageTurn,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _next() {
    if (_page == _donePage) {
      widget.onFinished();
    } else {
      _goTo(_page + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Progress(
                page: _page,
                onSkip: _page < _storyPages ? () => _goTo(_storyPages) : null,
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

  Widget _buildPage(int page) {
    if (page < _storyPages) return _storyPage(page);
    if (page == _donePage) return _finishedPage();
    return _permissionPage(RequiredPermission.values[page - _storyPages]);
  }

  Widget _storyPage(int page) {
    return switch (page) {
      0 => _Page(
        illustration: const _AnimatedHours(
          from: 0,
          to: 4.62,
          color: BlockingColors.rising,
        ),
        title: '4 hours 37 minutes a day.',
        body:
            'That is the average day on a phone. Over a year it adds up to '
            'seventy days.',
        primary: ('Next', _next),
      ),
      1 => _Page(
        illustration: const PickupTimeline(pickups: 58),
        title: '58 pickups a day.',
        body: 'Most last under two minutes. Almost none were planned.',
        primary: ('Next', _next),
      ),
      _ => _Page(
        illustration: const _AnimatedHours(
          from: 4.62,
          to: 1,
          color: BlockingColors.accent,
        ),
        title: 'SerenSync closes the door.',
        body:
            'Pick the apps and set a limit. When it is reached, the app '
            'closes and you land on a quiet home screen.',
        primary: ('Set it up', _next),
      ),
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
        style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.white),
      );
    } else if (permission == RequiredPermission.usageAccess && today != null) {
      detail = _TodayReveal(today);
    } else {
      detail = const Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: BlockingColors.accent),
          SizedBox(width: 8),
          Text('Allowed', style: TextStyle(fontSize: 14, color: Colors.white)),
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
    return _Page(
      illustration: const HourGrid(hours: 1, color: BlockingColors.accent),
      title: 'Ready.',
      body: allGranted
          ? 'Create your first block and choose the apps it covers.'
          : 'Anything you skipped can be allowed later from Settings.',
      primary: ('Continue', _next),
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
          'Reads the address bar in supported browsers so websites and '
          'keywords can be blocked too. Optional: only those blocks need it.',
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
  final (String, VoidCallback) primary;
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
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
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
            style: FilledButton.styleFrom(
              backgroundColor: BlockingColors.accent,
              foregroundColor: BlockingColors.onAccent,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from, end: to),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1100),
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
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ruleDuration(report.total),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: BlockingColors.rising,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'on other apps today so far, across $opens.',
            style: const TextStyle(
              fontSize: 14,
              color: BlockingColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
