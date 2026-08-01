import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/installed_app.dart';
import 'package:serensync/blocking/blocking_engine.dart';
import 'package:serensync/blocking/rule.dart';
import 'package:serensync/blocking/rule_editor_screen.dart';
import 'package:serensync/blocking/rule_store.dart';
import 'package:serensync/blocking/rules_screen.dart';

void main() {
  const taskChannel = MethodChannel('flutter_foreground_task/methods');
  late FakeRuleStore ruleStore;
  late FakeAppService appService;
  late int rulesChangedSignals;

  setUp(() {
    rulesChangedSignals = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(taskChannel, (call) async {
          if (call.method == 'sendData' &&
              call.arguments == rulesChangedSignal) {
            rulesChangedSignals++;
          }
          return null;
        });
    ruleStore = FakeRuleStore();
    appService = FakeAppService([
      _app('Alpha', 'com.example.alpha'),
      _app('Beta', 'com.example.beta'),
    ]);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(taskChannel, null);
  });

  testWidgets('schedule editor saves the entered rule', (tester) async {
    await _pumpEditor(tester, ruleStore, appService);
    await _nameAndSelectAlpha(tester);
    await tester.tap(find.byKey(const ValueKey('weekday-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('weekday-7')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-hour')),
      '10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-minute')),
      '00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-hour')),
      '18',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-minute')),
      '00',
    );
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final rule = ruleStore.rules.single;
    expect(rule.name, 'Morning focus');
    expect(rule.packages, {'com.example.alpha'});
    final schedule = rule.trigger as Schedule;
    expect(schedule.weekdays, {
      DateTime.monday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.sunday,
    });
    expect(schedule.startMinute, 10 * 60);
    expect(schedule.endMinute, 18 * 60);
    expect(rulesChangedSignals, 1);
  });

  testWidgets('limit picker shows the three limit types', (tester) async {
    await _pumpEditor(tester, ruleStore, appService);

    await tester.tap(find.byKey(const ValueKey('trigger-type')));
    await tester.pumpAndSettle();

    expect(find.text('Hours'), findsWidgets);
    expect(find.text('Daily time'), findsOneWidget);
    expect(find.text('Daily opens'), findsOneWidget);
  });

  testWidgets('usage quota editor preserves selection while filtering', (
    tester,
  ) async {
    await _pumpEditor(tester, ruleStore, appService);
    await tester.enterText(
      find.byKey(const ValueKey('rule-name')),
      'Social time',
    );
    await _chooseTrigger(tester, 'Daily time');
    await tester.enterText(find.byKey(const ValueKey('usage-minutes')), '45');
    await _tapApp(tester, 'com.example.alpha');
    await tester.enterText(
      find.byKey(const ValueKey('app-picker-search')),
      'bet',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('app-com.example.alpha')), findsNothing);
    await _tapApp(tester, 'com.example.beta');
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final rule = ruleStore.rules.single;
    expect(rule.name, 'Social time');
    expect(rule.packages, {'com.example.alpha', 'com.example.beta'});
    expect((rule.trigger as UsageQuota).limit, const Duration(minutes: 45));
    expect(rulesChangedSignals, 1);
  });

  testWidgets('launch quota editor saves the entered rule', (tester) async {
    await _pumpEditor(tester, ruleStore, appService);
    await _nameAndSelectAlpha(tester, name: 'Stop reopening');
    await _chooseTrigger(tester, 'Daily opens');
    await tester.enterText(find.byKey(const ValueKey('launch-count')), '7');
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final rule = ruleStore.rules.single;
    expect(rule.name, 'Stop reopening');
    expect(rule.packages, {'com.example.alpha'});
    expect((rule.trigger as LaunchQuota).limit, 7);
    expect(rulesChangedSignals, 1);
  });

  testWidgets('save needs at least one app', (tester) async {
    await _pumpEditor(tester, ruleStore, appService);
    TextButton save() => tester.widget(find.byKey(const ValueKey('rule-save')));

    expect(save().onPressed, isNull);
    await _tapApp(tester, 'com.example.alpha');
    expect(save().onPressed, isNotNull);
    await _tapApp(tester, 'com.example.alpha');
    expect(save().onPressed, isNull);
  });

  testWidgets('blank name saves the selected app name', (tester) async {
    await _pumpEditor(tester, ruleStore, appService);
    await _tapApp(tester, 'com.example.alpha');
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.name, 'Alpha');
  });

  testWidgets('blank name saves two selected app names', (tester) async {
    await _pumpEditor(tester, ruleStore, appService);
    await _tapApp(tester, 'com.example.alpha');
    await _tapApp(tester, 'com.example.beta');
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.name, 'Alpha, Beta');
  });

  testWidgets('blank name abbreviates three or more selected apps', (
    tester,
  ) async {
    appService.apps.add(_app('Gamma', 'com.example.gamma'));
    await _pumpEditor(tester, ruleStore, appService);
    await _tapApp(tester, 'com.example.alpha');
    await _tapApp(tester, 'com.example.beta');
    await _tapApp(tester, 'com.example.gamma');
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.name, 'Alpha, Beta + 1 more');
  });

  testWidgets('rule toggle persists the enabled state', (tester) async {
    ruleStore.rules.add(_rule(id: 12, name: 'Focus', enabled: true));
    await _pumpRules(tester, ruleStore, appService);

    await tester.tap(find.byKey(const ValueKey('rule-enabled-12')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.enabled, isFalse);
    expect(rulesChangedSignals, 1);
  });

  testWidgets('deleting a rule removes it', (tester) async {
    ruleStore.rules.add(_rule(id: 13, name: 'Temporary', enabled: true));
    await _pumpRules(tester, ruleStore, appService);

    await tester.tap(find.byKey(const ValueKey('delete-rule-13')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules, isEmpty);
    expect(find.text('Temporary'), findsNothing);
    expect(find.text('No limits yet'), findsOneWidget);
    expect(rulesChangedSignals, 1);
  });

  testWidgets('overnight schedule round-trips unchanged', (tester) async {
    const rule = BlockRule(
      id: 14,
      name: 'Sleep',
      packages: {'com.example.alpha'},
      trigger: Schedule(
        weekdays: {DateTime.saturday, DateTime.sunday},
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      ),
      enabled: false,
    );
    ruleStore.rules.add(rule);
    await _pumpEditor(tester, ruleStore, appService, rule: rule);

    expect(find.text('Overnight · ends the next day'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-hour')),
      '22',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-minute')),
      '00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-hour')),
      '06',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-minute')),
      '00',
    );
    expect(find.text('Overnight · ends the next day'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final saved = ruleStore.rules.single;
    final schedule = saved.trigger as Schedule;
    expect(schedule.startMinute, 22 * 60);
    expect(schedule.endMinute, 6 * 60);
    expect(schedule.weekdays, {DateTime.saturday, DateTime.sunday});
    expect(saved.enabled, isFalse);
    expect(rulesChangedSignals, 1);
  });

  testWidgets('invalid schedule input keeps the last valid time', (
    tester,
  ) async {
    await _pumpEditor(tester, ruleStore, appService);
    await _nameAndSelectAlpha(tester);

    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-hour')),
      'junk',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-minute')),
      '60',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-hour')),
      '24',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-minute')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final schedule = ruleStore.rules.single.trigger as Schedule;
    expect(schedule.startMinute, 9 * 60);
    expect(schedule.endMinute, 17 * 60);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester,
  RuleStore ruleStore,
  AppService appService, {
  BlockRule? rule,
}) async {
  await tester.pumpWidget(
    _TestApp(
      child: RuleEditorScreen(
        ruleStore: ruleStore,
        appService: appService,
        rule: rule,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRules(
  WidgetTester tester,
  RuleStore ruleStore,
  AppService appService,
) async {
  await tester.pumpWidget(
    _TestApp(
      child: RulesScreen(ruleStore: ruleStore, appService: appService),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _nameAndSelectAlpha(
  WidgetTester tester, {
  String name = 'Morning focus',
}) async {
  await tester.enterText(find.byKey(const ValueKey('rule-name')), name);
  await _tapApp(tester, 'com.example.alpha');
}

Future<void> _tapApp(WidgetTester tester, String package) async {
  final app = find.byKey(ValueKey('app-$package'));
  await tester.ensureVisible(app);
  await tester.pumpAndSettle();
  await tester.tap(app);
  await tester.pump();
}

Future<void> _chooseTrigger(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('trigger-type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: ThemeData.dark(), home: child);
  }
}

class FakeRuleStore extends RuleStore {
  final List<BlockRule> rules = [];
  int _nextId = 1;

  @override
  Future<List<BlockRule>> readAll() async => List<BlockRule>.of(rules);

  @override
  Future<int> insert(BlockRule rule) async {
    final id = _nextId++;
    rules.add(
      BlockRule(
        id: id,
        name: rule.name,
        packages: rule.packages,
        trigger: rule.trigger,
        enabled: rule.enabled,
      ),
    );
    return id;
  }

  @override
  Future<void> update(BlockRule rule) async {
    final index = rules.indexWhere((candidate) => candidate.id == rule.id);
    rules[index] = rule;
  }

  @override
  Future<void> delete(int id) async {
    rules.removeWhere((rule) => rule.id == id);
  }
}

class FakeAppService extends AppService {
  final List<InstalledApp> apps;

  FakeAppService(this.apps);

  @override
  Future<List<InstalledApp>> readPersistedApps() async => apps;

  @override
  Future<List<InstalledApp>> getInstalledApps({
    bool forceRefresh = false,
  }) async {
    return apps;
  }
}

BlockRule _rule({
  required int id,
  required String name,
  required bool enabled,
}) {
  return BlockRule(
    id: id,
    name: name,
    packages: const {'com.example.alpha'},
    trigger: const UsageQuota(Duration(minutes: 30)),
    enabled: enabled,
  );
}

InstalledApp _app(String name, String package) {
  return InstalledApp(
    displayName: name,
    packageName: package,
    activityName: '$package.MainActivity',
  );
}
