import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/installed_app.dart';
import 'package:serensync/main_app/blocking/onboarding/permission_status.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_session.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_store.dart';
import 'package:serensync/main_app/stats/usage_report.dart';
import 'package:serensync/main_app/strict/strict_mode.dart';
import 'package:serensync/main_app/strict/strict_mode_store.dart';
import 'package:serensync/main_app/today/today_tab.dart';

const _allowed = PermissionState(
  usageAccess: true,
  overlay: true,
  notifications: true,
  batteryOptimisation: true,
  accessibility: false,
);

void main() {
  late FakeRuleStore ruleStore;
  late FakeStrictModeStore strictModeStore;
  late List<String> calls;

  setUp(() {
    ruleStore = FakeRuleStore();
    strictModeStore = FakeStrictModeStore();
    calls = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    PermissionState permissions = _allowed,
    Future<TodayUsage?> Function()? usage,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayTab(
            appService: FakeAppService(),
            ruleStore: ruleStore,
            pomodoroStore: FakePomodoroStore(),
            strictModeStore: strictModeStore,
            permissions: permissions,
            usage: usage ?? () async => null,
            onAllow: (permission) => calls.add('allow ${permission.name}'),
            onCreateBlock: () => calls.add('create'),
            onOpenFocus: () => calls.add('focus'),
            onOpenBlocks: () => calls.add('blocks'),
            onOpenStrict: () => calls.add('strict'),
            onOpenInsights: () => calls.add('insights'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no blocks it invites the first one', (tester) async {
    await pump(tester);

    expect(find.text('No blocks yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today-create-block')));
    expect(calls, ['create']);
  });

  testWidgets('a running schedule is named as blocked now', (tester) async {
    ruleStore.rules.add(
      const BlockRule(
        id: 1,
        name: 'Social media',
        packages: {'com.example.alpha'},
        trigger: Schedule(
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          startMinute: 0,
          endMinute: 0,
          allDay: true,
        ),
        enabled: true,
      ),
    );
    await pump(tester);

    expect(find.text('Social media'), findsWidgets);
    expect(find.text('Blocked now'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Now'), 200);
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('strict mode leads while it runs', (tester) async {
    final now = DateTime.now();
    strictModeStore.strict = StrictMode(
      locks: const {},
      activatedAt: now,
      until: now.add(const Duration(days: 3)),
    );
    await pump(tester);

    expect(find.text('Strict mode'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today-hero')));
    expect(calls, ['strict']);
  });

  testWidgets('missing permissions become a setup checklist', (tester) async {
    await pump(
      tester,
      permissions: const PermissionState(
        usageAccess: true,
        overlay: false,
        notifications: true,
        batteryOptimisation: false,
        accessibility: false,
      ),
    );

    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('2 left'), findsOne);
    expect(
      find.byKey(const ValueKey('today-allow-accessibility')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('today-allow-overlay')));
    expect(calls, ['allow overlay']);
  });

  testWidgets('screen time is compared with yesterday', (tester) async {
    await pump(
      tester,
      usage: () async => (
        today: const UsageReport(
          buckets: [Duration(hours: 1)],
          apps: [
            AppTotal(
              packageName: 'com.example.alpha',
              time: Duration(hours: 1),
              opens: 12,
            ),
          ],
          total: Duration(hours: 1),
          opens: 12,
        ),
        yesterday: const Duration(hours: 1, minutes: 30),
      ),
    );

    expect(find.text('1h'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('30m less than yesterday')),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp('12 opens')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Mostly Alpha')), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('today-usage')));
    expect(calls, ['insights']);
  });

  testWidgets('a failing usage read only leaves its card out', (tester) async {
    await pump(tester, usage: () => Future.error(StateError('no usage')));

    expect(find.byKey(const ValueKey('today-usage')), findsNothing);
    expect(find.byKey(const ValueKey('today-action-focus')), findsOneWidget);
  });
}

class FakeRuleStore extends RuleStore {
  final List<BlockRule> rules = [];

  @override
  Future<List<BlockRule>> readAll() async => List.of(rules);
}

class FakeStrictModeStore extends StrictModeStore {
  StrictMode? strict;

  @override
  Future<StrictMode?> read() async => strict;
}

class FakePomodoroStore extends PomodoroStore {
  @override
  Future<PomodoroSession?> readSession() async => null;
}

class FakeAppService extends AppService {
  @override
  Future<List<InstalledApp>> getInstalledApps({
    bool forceRefresh = false,
  }) async => const [
    InstalledApp(
      displayName: 'Alpha',
      packageName: 'com.example.alpha',
      activityName: 'com.example.alpha.Main',
    ),
  ];
}
