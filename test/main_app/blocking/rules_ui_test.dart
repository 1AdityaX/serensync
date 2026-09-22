import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/installed_app.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/onboarding/permission_status.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_editor_screen.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/blocking/rules_screen.dart';
import 'package:serensync/main_app/blocking/widgets/rule_list.dart';

void main() {
  late FakeRuleStore ruleStore;
  late FakeAppService appService;
  late FakePermissionStatus permissionStatus;
  late FakeBlockingService blockingService;

  setUp(() {
    blockingService = FakeBlockingService();
    ruleStore = FakeRuleStore();
    permissionStatus = FakePermissionStatus();
    appService = FakeAppService([
      _app('Alpha', 'com.example.alpha'),
      _app('Beta', 'com.example.beta'),
    ]);
  });

  testWidgets('schedule editor saves the entered rule', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _nameAndSelectAlpha(tester);
    await _openCondition(tester);
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
    await _closeCondition(tester);
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
    expect(blockingService.syncs, 1);
  });

  testWidgets('schedule editor adds and saves multiple time windows', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _nameAndSelectAlpha(tester, name: 'Split focus');
    await _openCondition(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-add-time')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-hour-1')),
      '19',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-start-minute-1')),
      '00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-hour-1')),
      '21',
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule-end-minute-1')),
      '00',
    );
    await _closeCondition(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final schedule = ruleStore.rules.single.trigger as Schedule;
    expect(schedule.times, hasLength(2));
    expect(schedule.additionalTimes.single.startMinute, 19 * 60);
    expect(schedule.additionalTimes.single.endMinute, 21 * 60);
  });

  testWidgets('schedule editor saves an all-day schedule', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _nameAndSelectAlpha(tester, name: 'Deep work day');
    await _openCondition(tester);

    await tester.tap(find.byKey(const ValueKey('schedule-all-day')));
    await tester.pump();
    expect(find.byKey(const ValueKey('schedule-start-hour')), findsNothing);
    await _closeCondition(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final schedule = ruleStore.rules.single.trigger as Schedule;
    expect(schedule.allDay, isTrue);
    expect(schedule.times, hasLength(1));
  });

  testWidgets('limit picker shows the three limit types', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );

    await tester.tap(find.byKey(const ValueKey('trigger-type')));
    await tester.pumpAndSettle();

    expect(find.text('Time'), findsWidgets);
    expect(find.text('Usage limit'), findsOneWidget);
    expect(find.text('Launch count'), findsOneWidget);
  });

  testWidgets('usage quota editor preserves selection while filtering', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await tester.enterText(
      find.byKey(const ValueKey('rule-name')),
      'Social time',
    );
    await _chooseTrigger(tester, 'Usage limit');
    await _openCondition(tester);
    await tester.enterText(find.byKey(const ValueKey('usage-minutes')), '45');
    await _closeCondition(tester);
    await _openApps(tester);
    await _tapApp(tester, 'com.example.alpha');
    await tester.enterText(
      find.byKey(const ValueKey('app-picker-search')),
      'bet',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('app-com.example.alpha')), findsNothing);
    await _tapApp(tester, 'com.example.beta');
    await _closeApps(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final rule = ruleStore.rules.single;
    expect(rule.name, 'Social time');
    expect(rule.packages, {'com.example.alpha', 'com.example.beta'});
    expect((rule.trigger as UsageQuota).limit, const Duration(minutes: 45));
    expect(blockingService.syncs, 1);
  });

  testWidgets('launch quota editor saves the entered rule', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _nameAndSelectAlpha(tester, name: 'Stop reopening');
    await _chooseTrigger(tester, 'Launch count');
    await _openCondition(tester);
    await tester.enterText(find.byKey(const ValueKey('launch-count')), '7');
    await _closeCondition(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final rule = ruleStore.rules.single;
    expect(rule.name, 'Stop reopening');
    expect(rule.packages, {'com.example.alpha'});
    expect((rule.trigger as LaunchQuota).limit, 7);
    expect(blockingService.syncs, 1);
  });

  testWidgets('save needs at least one app', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    FilledButton save() =>
        tester.widget(find.byKey(const ValueKey('rule-save')));

    expect(save().onPressed, isNull);
    await _selectApps(tester, ['com.example.alpha']);
    expect(save().onPressed, isNotNull);
    await _selectApps(tester, ['com.example.alpha']);
    expect(save().onPressed, isNull);
  });

  testWidgets('blank name saves the selected app name', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _selectApps(tester, ['com.example.alpha']);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.name, 'Alpha');
  });

  testWidgets('blank name saves two selected app names', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _selectApps(tester, ['com.example.alpha', 'com.example.beta']);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.name, 'Alpha, Beta');
  });

  testWidgets('blank name abbreviates three or more selected apps', (
    tester,
  ) async {
    appService.apps.add(_app('Gamma', 'com.example.gamma'));
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _selectApps(tester, [
      'com.example.alpha',
      'com.example.beta',
      'com.example.gamma',
    ]);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.name, 'Alpha, Beta + 1 more');
  });

  testWidgets('website and keyword pickers normalise, reject, and save', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _openTargets(tester, 'websites-summary');
    await _addTarget(tester, 'https://www.Instagram.com/reels');
    await _addTarget(tester, 'not a website');
    expect(find.text('Enter a website such as instagram.com.'), findsOneWidget);
    await _addTarget(tester, 'Reddit.com');
    expect(find.text('Enter a website such as instagram.com.'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('remove-web-target-reddit.com')),
    );
    await tester.pump();
    await _closeTargets(tester);
    await _openTargets(tester, 'keywords-summary');
    await _addTarget(tester, '  Casino ');
    await _closeTargets(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final rule = ruleStore.rules.single;
    expect(rule.name, 'instagram.com, casino');
    expect(rule.packages, isEmpty);
    expect(rule.websites, {'instagram.com'});
    expect(rule.keywords, {'casino'});
    expect(blockingService.syncs, 1);
  });

  testWidgets('a website alone enables saving', (tester) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    FilledButton save() =>
        tester.widget(find.byKey(const ValueKey('rule-save')));

    expect(save().onPressed, isNull);
    await _openTargets(tester, 'websites-summary');
    await _addTarget(tester, 'instagram.com');
    await _closeTargets(tester);
    expect(save().onPressed, isNotNull);
  });

  testWidgets('web targets ask for accessibility until it is granted', (
    tester,
  ) async {
    permissionStatus.accessibility = false;
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    expect(find.byKey(const ValueKey('allow-accessibility')), findsNothing);

    await _openTargets(tester, 'websites-summary');
    await _addTarget(tester, 'instagram.com');
    await _closeTargets(tester);
    final allow = find.byKey(const ValueKey('allow-accessibility'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(allow);
    await tester.pumpAndSettle();
    await tester.tap(allow);
    await tester.pumpAndSettle();

    expect(permissionStatus.accessibilityRequests, 1);
    expect(find.byKey(const ValueKey('allow-accessibility')), findsNothing);
  });

  testWidgets('limits explain that web targets are blocked all day', (
    tester,
  ) async {
    const note =
        'Websites and keywords are blocked all day, because browsing time '
        'does not count towards the limit.';
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _chooseTrigger(tester, 'Usage limit');
    await _openTargets(tester, 'keywords-summary');
    await _addTarget(tester, 'shorts');
    await _closeTargets(tester);

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(note),
      180,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(note), findsOneWidget);
  });

  testWidgets('the rule list summarises and keeps web targets', (tester) async {
    ruleStore.rules.add(
      _rule(
        id: 15,
        name: 'Web',
        enabled: true,
        websites: {'instagram.com'},
        keywords: {'casino', 'bet'},
      ),
    );
    await _pumpRules(tester, ruleStore, appService, blockingService);
    expect(find.textContaining('1 app · 1 site · 2 keywords'), findsOneWidget);

    await _chooseRuleAction(tester, 15, 'pause');

    expect(ruleStore.rules.single.enabled, isFalse);
    expect(ruleStore.rules.single.websites, {'instagram.com'});
    expect(ruleStore.rules.single.keywords, {'casino', 'bet'});
  });

  testWidgets('pausing a rule persists and moves it to paused', (tester) async {
    ruleStore.rules.add(_rule(id: 12, name: 'Focus', enabled: true));
    await _pumpRules(tester, ruleStore, appService, blockingService);

    await _chooseRuleAction(tester, 12, 'pause');

    expect(ruleStore.rules.single.enabled, isFalse);
    expect(find.text('Paused blocks'), findsOneWidget);
    expect(blockingService.syncs, 1);
  });

  testWidgets('a paused rule offers block instead of pause', (tester) async {
    ruleStore.rules.add(_rule(id: 16, name: 'Evening', enabled: false));
    await _pumpRules(tester, ruleStore, appService, blockingService);

    await tester.tap(find.byKey(const ValueKey('rule-menu-16')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rule-pause')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rule-block')));
    await tester.pumpAndSettle();

    expect(ruleStore.rules.single.enabled, isTrue);
    expect(find.text('Active blocks'), findsOneWidget);
    expect(blockingService.syncs, 1);
  });

  testWidgets('duplicating a rule saves a copy', (tester) async {
    ruleStore.rules.add(
      _rule(id: 17, name: 'Web', enabled: true, websites: {'reddit.com'}),
    );
    await _pumpRules(tester, ruleStore, appService, blockingService);

    await _chooseRuleAction(tester, 17, 'duplicate');

    expect(ruleStore.rules, hasLength(2));
    final copy = ruleStore.rules.last;
    expect(copy.name, 'Web (copy)');
    expect(copy.packages, {'com.example.alpha'});
    expect(copy.websites, {'reddit.com'});
    expect(copy.enabled, isTrue);
    expect(find.text('Web (copy)'), findsOneWidget);
    expect(blockingService.syncs, 1);
  });

  testWidgets('edit opens the rule editor', (tester) async {
    ruleStore.rules.add(_rule(id: 18, name: 'Focus', enabled: true));
    await _pumpRules(tester, ruleStore, appService, blockingService);

    await _chooseRuleAction(tester, 18, 'edit');

    expect(find.byKey(const ValueKey('rule-save')), findsOneWidget);
  });

  testWidgets('deleting a rule removes it', (tester) async {
    ruleStore.rules.add(_rule(id: 13, name: 'Temporary', enabled: true));
    await _pumpRules(tester, ruleStore, appService, blockingService);

    await _chooseRuleAction(tester, 13, 'delete');

    expect(ruleStore.rules, isEmpty);
    expect(find.text('Temporary'), findsNothing);
    expect(find.text('No blocks yet.'), findsOneWidget);
    expect(blockingService.syncs, 1);
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
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
      rule: rule,
    );

    await _openCondition(tester);
    expect(
      find.text('This schedule includes a window that ends the following day.'),
      findsNothing,
    );
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
    expect(
      find.text('This schedule includes a window that ends the following day.'),
      findsOneWidget,
    );
    await _closeCondition(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final saved = ruleStore.rules.single;
    final schedule = saved.trigger as Schedule;
    expect(schedule.startMinute, 22 * 60);
    expect(schedule.endMinute, 6 * 60);
    expect(schedule.weekdays, {DateTime.saturday, DateTime.sunday});
    expect(saved.enabled, isFalse);
    expect(blockingService.syncs, 1);
  });

  testWidgets('invalid schedule input keeps the last valid time', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      ruleStore,
      appService,
      permissionStatus,
      blockingService,
    );
    await _nameAndSelectAlpha(tester);
    await _openCondition(tester);

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
    await _closeCondition(tester);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    final schedule = ruleStore.rules.single.trigger as Schedule;
    expect(schedule.startMinute, 9 * 60);
    expect(schedule.endMinute, 17 * 60);
  });
  testWidgets('locked rules cannot be paused or deleted', (tester) async {
    ruleStore.rules.add(_rule(id: 20, name: 'Locked', enabled: true));
    ruleStore.rules.add(_rule(id: 21, name: 'Paused', enabled: false));
    await tester.pumpWidget(
      _TestApp(
        child: Scaffold(
          body: RuleList(
            ruleStore: ruleStore,
            appService: appService,
            blockingService: blockingService,
            locked: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rules-locked')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rule-menu-20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rule-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-duplicate')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-pause')), findsNothing);
    expect(find.byKey(const ValueKey('rule-delete')), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rule-menu-21')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rule-block')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-delete')), findsNothing);
  });

  testWidgets('a locked block saves only when it is tightened', (tester) async {
    final rule = _rule(id: 22, name: 'Limit', enabled: true);
    ruleStore.rules.add(rule);
    // A phone-height surface, so the whole editor is laid out.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _TestApp(
        child: RuleEditorScreen(
          ruleStore: ruleStore,
          appService: appService,
          blockingService: blockingService,
          permissionStatus: permissionStatus,
          locked: true,
          rule: rule,
        ),
      ),
    );
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget(find.byKey(const ValueKey('rule-save')));
    expect(find.byKey(const ValueKey('rule-locked')), findsOneWidget);
    expect(save().onPressed, isNotNull);

    await _openCondition(tester);
    await tester.enterText(find.byKey(const ValueKey('usage-minutes')), '45');
    await _closeCondition(tester);
    expect(save().onPressed, isNull);
    expect(find.textContaining('would loosen'), findsOneWidget);

    await _openCondition(tester);
    await tester.enterText(find.byKey(const ValueKey('usage-minutes')), '15');
    await _closeCondition(tester);
    expect(save().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();

    expect(
      (ruleStore.rules.single.trigger as UsageQuota).limit,
      const Duration(minutes: 15),
    );
    expect(blockingService.syncs, 1);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester,
  RuleStore ruleStore,
  AppService appService,
  PermissionStatus permissionStatus,
  BlockingService blockingService, {
  BlockRule? rule,
}) async {
  await tester.pumpWidget(
    _TestApp(
      child: RuleEditorScreen(
        ruleStore: ruleStore,
        appService: appService,
        blockingService: blockingService,
        permissionStatus: permissionStatus,
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
  BlockingService blockingService,
) async {
  await tester.pumpWidget(
    _TestApp(
      child: RulesScreen(
        ruleStore: ruleStore,
        appService: appService,
        blockingService: blockingService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseRuleAction(
  WidgetTester tester,
  int ruleId,
  String action,
) async {
  await tester.tap(find.byKey(ValueKey('rule-menu-$ruleId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('rule-$action')));
  await tester.pumpAndSettle();
}

Future<void> _openTargets(WidgetTester tester, String key) async {
  final summary = find.byKey(ValueKey(key));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    summary,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(summary);
  await tester.pumpAndSettle();
}

Future<void> _addTarget(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('web-target-input')), text);
  await tester.tap(find.byKey(const ValueKey('web-target-add')));
  await tester.pump();
}

Future<void> _closeTargets(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('web-target-done')));
  await tester.pumpAndSettle();
}

Future<void> _nameAndSelectAlpha(
  WidgetTester tester, {
  String name = 'Morning focus',
}) async {
  await tester.enterText(find.byKey(const ValueKey('rule-name')), name);
  await _selectApps(tester, ['com.example.alpha']);
}

Future<void> _selectApps(WidgetTester tester, List<String> packages) async {
  await _openApps(tester);
  for (final package in packages) {
    await _tapApp(tester, package);
  }
  await _closeApps(tester);
}

Future<void> _openApps(WidgetTester tester) async {
  final summary = find.byKey(const ValueKey('apps-summary'));
  // Entering text starts a caret-reveal animation on the editor's list, which
  // would undo the scroll below until it has settled.
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    summary,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(summary);
  await tester.pumpAndSettle();
}

Future<void> _closeApps(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-picker-done')));
  await tester.pumpAndSettle();
}

Future<void> _openCondition(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('condition-summary')));
  await tester.pumpAndSettle();
}

Future<void> _closeCondition(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('condition-done')));
  await tester.pumpAndSettle();
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
        websites: rule.websites,
        keywords: rule.keywords,
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

class FakePermissionStatus extends PermissionStatus {
  FakePermissionStatus({this.accessibility = true});

  bool accessibility;
  int accessibilityRequests = 0;

  @override
  Future<PermissionState> check() async => PermissionState(
    usageAccess: true,
    overlay: true,
    notifications: true,
    batteryOptimisation: true,
    accessibility: accessibility,
  );

  @override
  Future<void> request(RequiredPermission permission) async {
    if (permission == RequiredPermission.accessibility) {
      accessibilityRequests++;
      accessibility = true;
    }
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
  Set<String> websites = const {},
  Set<String> keywords = const {},
}) {
  return BlockRule(
    id: id,
    name: name,
    packages: const {'com.example.alpha'},
    websites: websites,
    keywords: keywords,
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

class FakeBlockingService extends BlockingService {
  int syncs = 0;

  @override
  Future<void> sync(RuleStore ruleStore) async {
    syncs++;
  }
}
