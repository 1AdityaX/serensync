import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/app_store.dart';
import 'package:serensync/apps/installed_app.dart';
import 'package:serensync/main_app/blocking/onboarding/permission_status.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/onboarding/onboarding_screen.dart';
import 'package:serensync/main_app/onboarding/window_dial.dart';
import 'package:serensync/main_app/pomodoro/timer_dial.dart';

void main() {
  const usageChannel = MethodChannel('usage_stats');
  late FakeAppService appService;
  late FakeRuleStore ruleStore;

  setUp(() {
    appService = FakeAppService([
      _app('Alpha', 'com.example.alpha'),
      _app('Beta', 'com.example.beta'),
      _app('Gamma', 'com.example.gamma'),
    ]);
    ruleStore = FakeRuleStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usageChannel, (call) async {
          final now = DateTime.now();
          return [
            _event(
              1,
              now.subtract(const Duration(hours: 2, minutes: 14, seconds: 30)),
            ),
            _event(2, now),
          ];
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usageChannel, null);
  });

  testWidgets('the promise opens the quiz and skip jumps to the permissions', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore);

    expect(find.text('Your time back, starting today.'), findsOneWidget);
    expect(find.text('Your plan'), findsNothing);
    await _tapPrimary(tester);
    expect(find.text("What's your goal?"), findsOneWidget);
    expect(find.text('Your plan'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your time back, starting today.'), findsOneWidget);

    await _skip(tester);
    expect(find.text('Usage access'), findsOneWidget);
    expect(find.text('Your plan'), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsNothing);
  });

  testWidgets('each answer becomes a chip and the plan is built from them', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore);
    await _tapPrimary(tester);

    await tester.tap(find.byKey(const ValueKey('goal-scrolling')));
    await tester.pumpAndSettle();
    expect(find.text('Which apps pull you in?'), findsOneWidget);
    expect(_chip(0, 'Scroll less'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_primary)).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('app-com.example.alpha')));
    await tester.pump();
    expect(_chip(1, 'Alpha'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-com.example.beta')));
    await tester.pump();
    expect(_chip(1, 'Alpha +1'), findsOneWidget);
    expect(find.text('Continue · 2'), findsOneWidget);
    await _tapPrimary(tester);

    expect(find.text('How much a day is enough?'), findsOneWidget);
    expect(_inRing('45m'), findsOneWidget);
    expect(_chip(2, '45m a day'), findsOneWidget);
    await _tapPrimary(tester);

    expect(find.text('Built from your answers'), findsOneWidget);
    expect(find.textContaining('scroll less.'), findsOneWidget);
    expect(find.text('Alpha and Beta'), findsOneWidget);
    expect(find.text('Blocked after 45m a day'), findsOneWidget);
    await _tapPrimary(tester);
    expect(find.text('Usage access'), findsOneWidget);
  });

  testWidgets('dragging the ring sets the usage limit', (tester) async {
    await _pump(tester, appService, ruleStore);
    await _answerGoalAndApps(tester, 'scrolling');

    final centre = tester.getCenter(find.byType(TimerDial));
    // Three o'clock is a quarter turn: an hour of the four on the ring.
    await tester.dragFrom(
      centre + const Offset(100, -100),
      const Offset(46, 100),
    );
    await tester.pumpAndSettle();

    expect(_inRing('1h'), findsOneWidget);
    expect(_chip(2, '1h a day'), findsOneWidget);
  });

  testWidgets('the window dial moves either end and never lets them meet', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore);
    await _answerGoalAndApps(tester, 'work');

    expect(find.text('When should they stay closed?'), findsOneWidget);
    expect(_inRing('09:00–17:00'), findsOneWidget);
    expect(_inRing('8h · Mon–Fri'), findsOneWidget);

    final centre = tester.getCenter(find.byType(WindowDial));
    final seventeen = _onRing(17 * 60);
    final eighteen = _onRing(18 * 60);
    await tester.dragFrom(centre + seventeen, eighteen - seventeen);
    await tester.pumpAndSettle();
    expect(_inRing('09:00–18:00'), findsOneWidget);
    expect(_inRing('9h · Mon–Fri'), findsOneWidget);
    expect(_chip(2, '09:00–18:00'), findsOneWidget);

    final nine = _onRing(9 * 60);
    final eight = _onRing(8 * 60);
    await tester.dragFrom(centre + nine, eight - nine);
    await tester.pumpAndSettle();
    expect(_inRing('08:00–18:00'), findsOneWidget);

    await tester.dragFrom(centre + eighteen, eight - eighteen);
    await tester.pumpAndSettle();
    expect(_inRing('08:00–08:00'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(WindowDial),
        matching: find.textContaining('08:00–'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new goal starts the limit over, the same goal keeps it', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore);
    await _answerGoalAndApps(tester, 'scrolling');
    final centre = tester.getCenter(find.byType(TimerDial));
    await tester.dragFrom(
      centre + const Offset(100, -100),
      const Offset(46, 100),
    );
    await tester.pumpAndSettle();
    expect(find.text('1h'), findsOneWidget);

    await tester.tap(_chip(0, 'Scroll less'));
    await tester.pumpAndSettle();
    expect(find.text("What's your goal?"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-scrolling')));
    await tester.pumpAndSettle();
    expect(_chip(1, 'Alpha +1'), findsOneWidget);
    await _tapPrimary(tester);
    expect(find.text('1h'), findsOneWidget);

    await tester.tap(_chip(0, 'Scroll less'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-nights')));
    await tester.pumpAndSettle();
    await _tapPrimary(tester);
    expect(_inRing('22:00–07:00'), findsOneWidget);
    expect(_inRing('9h · Mon–Sun'), findsOneWidget);
  });

  testWidgets('finishing saves the plan as the first block', (tester) async {
    var finished = 0;
    await _pump(tester, appService, ruleStore, onFinished: () => finished++);
    await _answerGoalAndApps(tester, 'scrolling');
    await _tapPrimary(tester);
    await _tapPrimary(tester);
    await _skipPermissions(tester);

    expect(find.text("You're all set."), findsOneWidget);
    expect(
      find.text(
        'Alpha and Beta close after 45m a day. Anything you skipped can be '
        'allowed later from Settings.',
      ),
      findsOneWidget,
    );
    expect(ruleStore.inserted, isEmpty);
    await _tapPrimary(tester);

    final rule = ruleStore.inserted.single;
    expect(rule.name, 'Alpha, Beta');
    expect(rule.packages, {'com.example.alpha', 'com.example.beta'});
    expect((rule.trigger as UsageQuota).limit, const Duration(minutes: 45));
    expect(rule.enabled, isTrue);
    expect(finished, 1);
  });

  testWidgets('a plan that fails to save can be retried or left', (
    tester,
  ) async {
    var finished = 0;
    ruleStore.fail = true;
    await _pump(tester, appService, ruleStore, onFinished: () => finished++);
    await _answerGoalAndApps(tester, 'scrolling');
    await _tapPrimary(tester);
    await _tapPrimary(tester);
    await _skipPermissions(tester);
    await _tapPrimary(tester);

    expect(find.text('Your plan did not save.'), findsOneWidget);
    expect(finished, 0);

    ruleStore.fail = false;
    await _tapPrimary(tester);
    expect(ruleStore.inserted, hasLength(1));
    expect(finished, 1);
  });

  testWidgets('skipping after a plan was built leaves it out', (tester) async {
    var finished = 0;
    await _pump(tester, appService, ruleStore, onFinished: () => finished++);
    await _answerGoalAndApps(tester, 'scrolling');
    await _tapPrimary(tester);
    await _tapPrimary(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Start my plan'), findsOneWidget);
    await _skip(tester);
    await _skipPermissions(tester);

    expect(find.text('Ready.'), findsOneWidget);
    await _tapPrimary(tester);
    expect(ruleStore.inserted, isEmpty);
    expect(finished, 1);
  });

  testWidgets('back after skip returns to where skip was pressed', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore);
    await _tapPrimary(tester);
    await tester.tap(find.byKey(const ValueKey('goal-scrolling')));
    await tester.pumpAndSettle();
    await _skip(tester);
    expect(find.text('Usage access'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Which apps pull you in?'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-chip-2')), findsNothing);
  });

  testWidgets('the plan needs at least one app', (tester) async {
    await _pump(tester, appService, ruleStore);
    await _answerGoalAndApps(tester, 'scrolling');

    await tester.tap(_chip(1, 'Alpha +1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-com.example.alpha')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app-com.example.beta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-chip-1')), findsNothing);

    await tester.tap(_chip(2, '45m a day'));
    await tester.pumpAndSettle();
    expect(find.text('How much a day is enough?'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(_primary)).onPressed, isNull);
  });

  testWidgets('pages still turn when the system disables animation', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore, reduceMotion: true);
    await _tapPrimary(tester);
    expect(find.text("What's your goal?"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-work')));
    await tester.pumpAndSettle();
    expect(find.text('Which apps pull you in?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second tap while the plan saves does not save it twice', (
    tester,
  ) async {
    var finished = 0;
    ruleStore.pending = Completer<void>();
    await _pump(tester, appService, ruleStore, onFinished: () => finished++);
    await _answerGoalAndApps(tester, 'scrolling');
    await _tapPrimary(tester);
    await _tapPrimary(tester);
    await _skipPermissions(tester);

    await _tapPrimary(tester);
    expect(tester.widget<FilledButton>(find.byKey(_primary)).onPressed, isNull);
    ruleStore.pending!.complete();
    await tester.pumpAndSettle();
    expect(ruleStore.inserted, hasLength(1));
    expect(finished, 1);
  });

  testWidgets('the apps page retries after a failed read', (tester) async {
    appService.fail = true;
    await _pump(tester, appService, ruleStore);
    await _tapPrimary(tester);
    await tester.tap(find.byKey(const ValueKey('goal-pickups')));
    await tester.pumpAndSettle();

    expect(find.text('Your apps could not be read.'), findsOneWidget);
    appService.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('a permission page asks Android, then rechecks on return', (
    tester,
  ) async {
    final status = FakePermissionStatus(_nothingGranted);
    await _pump(tester, appService, ruleStore, status: status);
    await _skip(tester);

    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await _tapPrimary(tester);
    expect(status.requested, [RequiredPermission.usageAccess]);
    expect(find.text('Open settings'), findsOneWidget);

    status.state = const PermissionState(
      usageAccess: true,
      overlay: false,
      notifications: false,
      batteryOptimisation: false,
      accessibility: false,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('2h 14m'), findsOneWidget);
    expect(
      find.text('on other apps today so far, across 1 open.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);

    await _tapPrimary(tester);
    expect(find.text('Display over other apps'), findsOneWidget);
  });

  testWidgets('permissions granted before setup show as allowed', (
    tester,
  ) async {
    await _pump(
      tester,
      appService,
      ruleStore,
      status: FakePermissionStatus(_allGranted),
    );
    await _skip(tester);

    for (final permission in RequiredPermission.values) {
      expect(find.text(permissionTitle(permission)), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await _tapPrimary(tester);
    }
    expect(find.text('Ready.'), findsOneWidget);
    expect(
      find.text('Create your first block and choose the apps it covers.'),
      findsOneWidget,
    );
  });

  testWidgets('skipping every permission finishes and points to Settings', (
    tester,
  ) async {
    var finished = 0;
    await _pump(tester, appService, ruleStore, onFinished: () => finished++);
    await _skip(tester);
    await _skipPermissions(tester);

    expect(find.text('Ready.'), findsOneWidget);
    expect(
      find.text('Anything you skipped can be allowed later from Settings.'),
      findsOneWidget,
    );
    expect(finished, 0);
    await _tapPrimary(tester);
    expect(finished, 1);
  });

  testWidgets('the accessibility page explains restricted settings', (
    tester,
  ) async {
    await _pump(tester, appService, ruleStore);
    await _skip(tester);
    for (var index = 0; index < RequiredPermission.values.length - 1; index++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-secondary')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.textContaining('allow restricted settings'), findsOneWidget);
  });
}

const _primary = ValueKey('onboarding-primary');

const _nothingGranted = PermissionState(
  usageAccess: false,
  overlay: false,
  notifications: false,
  batteryOptimisation: false,
  accessibility: false,
);

const _allGranted = PermissionState(
  usageAccess: true,
  overlay: true,
  notifications: true,
  batteryOptimisation: true,
  accessibility: true,
);

Map<String, String?> _event(int type, DateTime at) {
  return <String, String?>{
    'eventType': '$type',
    'timeStamp': '${at.millisecondsSinceEpoch}',
    'packageName': 'com.example.feed',
    'className': null,
  };
}

InstalledApp _app(String name, String package) =>
    InstalledApp(displayName: name, packageName: package, activityName: null);

Finder _chip(int index, String label) => find.descendant(
  of: find.byKey(ValueKey('plan-chip-$index')),
  matching: find.text(label),
);

/// Where [minute] sits on the window dial's ring, from its centre. The dial
/// is 300 wide and its ring 14 thick.
Offset _onRing(int minute) {
  final angle = -pi / 2 + 2 * pi * minute / (24 * 60);
  return Offset(cos(angle), sin(angle)) * (150 - 14);
}

Future<void> _pump(
  WidgetTester tester,
  FakeAppService appService,
  FakeRuleStore ruleStore, {
  FakePermissionStatus? status,
  VoidCallback? onFinished,
  bool reduceMotion = false,
}) async {
  // A phone, so the rings sit fully on screen.
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: OnboardingScreen(
          permissionStatus: status ?? FakePermissionStatus(_nothingGranted),
          appService: appService,
          ruleStore: ruleStore,
          onFinished: onFinished ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPrimary(WidgetTester tester) async {
  await tester.tap(find.byKey(_primary));
  await tester.pumpAndSettle();
}

Future<void> _skip(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
  await tester.pumpAndSettle();
}

Future<void> _skipPermissions(WidgetTester tester) async {
  for (var index = 0; index < RequiredPermission.values.length; index++) {
    await tester.tap(find.byKey(const ValueKey('onboarding-secondary')));
    await tester.pumpAndSettle();
  }
}

/// Picks [goal], then Alpha and Beta, and lands on the limit page.
Future<void> _answerGoalAndApps(WidgetTester tester, String goal) async {
  await _tapPrimary(tester);
  await tester.tap(find.byKey(ValueKey('goal-$goal')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-com.example.alpha')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('app-com.example.beta')));
  await tester.pump();
  await _tapPrimary(tester);
}

/// Text in the middle of whichever ring is on screen.
Finder _inRing(String text) => find.descendant(
  of: find.byWidgetPredicate((w) => w is WindowDial || w is TimerDial),
  matching: find.text(text),
);

class FakeAppService extends AppService {
  FakeAppService(this.apps) : super(store: FakeAppStore());

  List<InstalledApp> apps;
  bool fail = false;

  @override
  Future<List<InstalledApp>> getInstalledApps({
    bool forceRefresh = false,
  }) async {
    if (fail) throw StateError('unavailable');
    return apps;
  }
}

class FakeAppStore extends AppStore {
  @override
  Future<List<InstalledApp>> readAll() async => const [];

  @override
  Future<void> replaceAll(List<InstalledApp> apps) async {}
}

class FakeRuleStore extends RuleStore {
  final List<BlockRule> inserted = [];
  bool fail = false;
  Completer<void>? pending;

  @override
  Future<List<BlockRule>> readAll() async => const [];

  @override
  Future<int> insert(BlockRule rule) async {
    await pending?.future;
    if (fail) throw StateError('closed');
    inserted.add(rule);
    return inserted.length;
  }

  @override
  Future<void> close() async {}
}

class FakePermissionStatus extends PermissionStatus {
  FakePermissionStatus(this.state);

  PermissionState state;
  final List<RequiredPermission> requested = [];

  @override
  Future<PermissionState> check() async => state;

  @override
  Future<void> request(RequiredPermission permission) async {
    requested.add(permission);
  }
}
