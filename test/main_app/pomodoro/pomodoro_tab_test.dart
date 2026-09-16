import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_session.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_store.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_tab.dart';
import 'package:serensync/main_app/pomodoro/timer_dial.dart';

const _social = BlockRule(
  id: 1,
  name: 'Social',
  packages: <String>{'com.example.social'},
  trigger: LaunchQuota(3),
  enabled: true,
);
const _games = BlockRule(
  id: 2,
  name: 'Games',
  packages: <String>{'com.example.games'},
  trigger: LaunchQuota(3),
  enabled: false,
);

void main() {
  late FakePomodoroStore store;
  late FakeBlockingService blockingService;

  setUp(() {
    store = FakePomodoroStore();
    blockingService = FakeBlockingService();
  });

  testWidgets('starting focus saves the chosen blocks and syncs the service', (
    tester,
  ) async {
    await _pump(tester, store, blockingService);

    await tester.tap(find.byKey(const ValueKey('pomodoro-block-2')));
    await tester.pump();
    final dial = find.byType(TimerDial);
    final centre = tester.getCenter(dial);
    final radius = tester.getSize(dial).width / 2 - 14;
    await tester.dragFrom(centre + Offset(0, -radius), Offset(0, 2 * radius));
    await tester.pump();
    expect(find.text('30:00'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('pomodoro-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pomodoro-primary')));
    await tester.pump();

    final session = store.session;
    expect(session, isNotNull);
    expect(session!.ruleIds, {2});
    expect(session.round, 1);
    expect(store.settings.focus, const Duration(minutes: 30));
    expect(blockingService.syncs, 1);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('Blocking Games'), findsOneWidget);
  });

  testWidgets('focus names its blocks and the break releases them', (
    tester,
  ) async {
    store.session = _session(
      startedAgo: const Duration(minutes: 10),
      ruleIds: {1, 2},
    );
    await _pump(tester, store, blockingService);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Blocking Social, Games'), findsOneWidget);
    expect(find.text('Round 1 of 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    store.session = _session(
      startedAgo: const Duration(minutes: 26),
      ruleIds: {1, 2},
    );
    await _pump(tester, store, blockingService);
    expect(find.text('Break'), findsOneWidget);
    expect(find.text('Blocks released'), findsOneWidget);
  });

  testWidgets('after the break the next round waits for a tap', (tester) async {
    store.session = _session(startedAgo: const Duration(minutes: 40));
    await _pump(tester, store, blockingService);

    expect(find.text('Break over'), findsOneWidget);
    await tester.tap(find.text('Start round 2'));
    await tester.pump();

    expect(store.session!.round, 2);
    expect(blockingService.syncs, 1);
    expect(find.text('Round 2 of 2'), findsOneWidget);
  });

  testWidgets('ending a session asks first', (tester) async {
    store.session = _session(startedAgo: const Duration(minutes: 1));
    await _pump(tester, store, blockingService);

    await tester.tap(find.byKey(const ValueKey('pomodoro-end')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keep going'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.session, isNotNull);
    expect(find.text('Focus'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pomodoro-end')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pomodoro-end-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.session, isNull);
    expect(blockingService.syncs, 1);
    expect(find.text('Start focus'), findsOneWidget);
  });

  testWidgets('a finished session is dismissed with Done', (tester) async {
    store.session = _session(startedAgo: const Duration(hours: 1), round: 2);
    await _pump(tester, store, blockingService);

    expect(find.text('Session complete'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(store.session, isNull);
    expect(find.text('Start focus'), findsOneWidget);
  });
}

PomodoroSession _session({
  required Duration startedAgo,
  Set<int> ruleIds = const {1},
  int round = 1,
}) {
  return PomodoroSession(
    settings: const PomodoroSettings(rounds: 2),
    ruleIds: ruleIds,
    round: round,
    focusStartedAt: DateTime.now().subtract(startedAgo),
  );
}

Future<void> _pump(
  WidgetTester tester,
  FakePomodoroStore store,
  FakeBlockingService blockingService,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: PomodoroTab(
          ruleStore: FakeRuleStore(),
          blockingService: blockingService,
          pomodoroStore: store,
        ),
      ),
    ),
  );
  await tester.pump();
  // The running view keeps a one-second ticker; unmount so it is cancelled.
  addTearDown(() => tester.pumpWidget(const SizedBox()));
}

class FakePomodoroStore extends PomodoroStore {
  PomodoroSession? session;
  PomodoroSettings settings = const PomodoroSettings();

  @override
  Future<PomodoroSession?> readSession() async => session;

  @override
  Future<void> writeSession(PomodoroSession? session) async {
    this.session = session;
  }

  @override
  Future<PomodoroSettings> readSettings() async => settings;

  @override
  Future<void> writeSettings(PomodoroSettings settings) async {
    this.settings = settings;
  }
}

class FakeRuleStore extends RuleStore {
  @override
  Future<List<BlockRule>> readAll() async => const [_social, _games];
}

class FakeBlockingService extends BlockingService {
  int syncs = 0;

  @override
  Future<void> sync(RuleStore ruleStore) async {
    syncs++;
  }
}
