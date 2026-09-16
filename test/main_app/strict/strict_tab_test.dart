import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/strict/strict_mode.dart';
import 'package:serensync/main_app/strict/strict_mode_store.dart';
import 'package:serensync/main_app/strict/strict_tab.dart';
import 'package:serensync/main_app/strict/uninstall_guard.dart';

const _allWeek = BlockRule(
  id: 1,
  name: 'Always',
  packages: {'com.example.app'},
  trigger: Schedule(
    weekdays: {1, 2, 3, 4, 5, 6, 7},
    startMinute: 0,
    endMinute: 0,
    allDay: true,
  ),
  enabled: true,
);

void main() {
  late FakeStrictModeStore store;
  late FakeBlockingService blockingService;
  late FakeRuleStore ruleStore;
  late FakeUninstallGuard uninstallGuard;
  late bool charging;
  late int changes;

  setUp(() {
    store = FakeStrictModeStore();
    blockingService = FakeBlockingService();
    ruleStore = FakeRuleStore();
    uninstallGuard = FakeUninstallGuard();
    charging = false;
    changes = 0;
  });

  Future<void> pump(WidgetTester tester) async {
    // A phone-height surface, so the whole setup list is laid out.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: StrictTab(
            ruleStore: ruleStore,
            blockingService: blockingService,
            strictModeStore: store,
            onChanged: () => changes++,
            isCharging: () async => charging,
            uninstallGuard: uninstallGuard,
          ),
        ),
      ),
    );
    await tester.pump();
    // Countdowns keep a one-second ticker; unmount so it is cancelled.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  StrictMode strict({
    Set<UnlockCondition> conditions = const {UnlockCondition.pin},
    Set<StrictLock> locks = const {StrictLock.rules},
    DateTime? until,
    Duration? cooldown,
    DateTime? unlockRequestedAt,
    String? pin = '2468',
  }) {
    return StrictMode(
      conditions: conditions,
      locks: locks,
      activatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      until: until,
      cooldown: cooldown,
      unlockRequestedAt: unlockRequestedAt,
      pin: pin == null ? null : PinHash.create(pin, Random(1)),
    );
  }

  testWidgets('activating with a timer stores the mode and syncs', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Strict mode'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('strict-timer-180m')));
    await tester.pump();
    SwitchListTile settings() =>
        tester.widget(find.byKey(const ValueKey('strict-lock-settings')));
    expect(settings().value, isTrue);
    expect(settings().onChanged, isNull);
    await tester.tap(find.byKey(const ValueKey('strict-activate')));
    await tester.pump();

    final saved = store.strict!;
    expect(saved.conditions, {UnlockCondition.timer});
    expect(saved.locks, {StrictLock.rules, StrictLock.settings});
    expect(
      saved.until!.difference(saved.activatedAt),
      const Duration(hours: 3),
    );
    expect(saved.pin, isNull);
    expect(blockingService.syncs, 1);
    expect(changes, 1);
    expect(find.text('Strict mode is on'), findsOneWidget);
    expect(find.text('Ends in 3h'), findsOneWidget);
    expect(find.text('Block device settings'), findsOneWidget);
  });

  testWidgets('blocking uninstalls needs the device admin and Settings lock', (
    tester,
  ) async {
    await pump(tester);
    SwitchListTile lock(StrictLock lock) =>
        tester.widget(find.byKey(ValueKey('strict-lock-${lock.name}')));

    await tester.tap(find.byKey(const ValueKey('strict-condition-timer')));
    await tester.tap(find.byKey(const ValueKey('strict-condition-charger')));
    await tester.pump();
    expect(lock(StrictLock.settings).value, isFalse);
    expect(lock(StrictLock.settings).onChanged, isNotNull);

    await tester.tap(find.byKey(const ValueKey('strict-lock-uninstall')));
    await tester.pump();
    expect(lock(StrictLock.uninstall).value, isTrue);
    expect(lock(StrictLock.settings).value, isTrue);
    expect(lock(StrictLock.settings).onChanged, isNull);

    await tester.tap(find.byKey(const ValueKey('strict-lock-uninstall')));
    await tester.pump();
    expect(lock(StrictLock.settings).value, isFalse);

    await tester.tap(find.byKey(const ValueKey('strict-lock-uninstall')));
    await tester.pump();
    uninstallGuard.grant = false;
    await tester.tap(find.byKey(const ValueKey('strict-activate')));
    await tester.pump();
    expect(uninstallGuard.activations, 1);
    expect(store.strict, isNull);
    expect(
      find.byKey(const ValueKey('strict-activation-message')),
      findsOneWidget,
    );

    uninstallGuard.grant = true;
    await tester.tap(find.byKey(const ValueKey('strict-activate')));
    await tester.pump();
    expect(uninstallGuard.activations, 2);
    expect(store.strict!.locks, {
      StrictLock.rules,
      StrictLock.settings,
      StrictLock.uninstall,
    });
    expect(find.text('Block uninstalling'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    store.strict = strict(
      conditions: {UnlockCondition.charger},
      locks: {StrictLock.rules, StrictLock.settings, StrictLock.uninstall},
      pin: null,
    );
    charging = true;
    uninstallGuard.active = true;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pump();

    expect(store.strict, isNull);
    expect(uninstallGuard.deactivations, 1);
  });

  testWidgets('a pin must be confirmed before activating', (tester) async {
    await pump(tester);
    FilledButton activate() =>
        tester.widget(find.byKey(const ValueKey('strict-activate')));

    await tester.tap(find.byKey(const ValueKey('strict-condition-pin')));
    await tester.pump();
    expect(activate().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('strict-pin')), '1234');
    await tester.pump();
    expect(activate().onPressed, isNull);
    expect(
      find.text('Use 4 to 8 digits and enter the same PIN twice.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('strict-pin-confirm')),
      '1234',
    );
    await tester.pump();
    expect(activate().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('strict-activate')));
    await tester.pump();

    final saved = store.strict!;
    expect(saved.conditions, {UnlockCondition.timer, UnlockCondition.pin});
    expect(saved.pin!.matches('1234'), isTrue);
    expect(find.textContaining('Unlock with your PIN'), findsOneWidget);
  });

  testWidgets('unlocking checks every condition', (tester) async {
    store.strict = strict(
      conditions: {UnlockCondition.pin, UnlockCondition.charger},
    );
    await pump(tester);
    expect(find.text('Unlock with your PIN while charging'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('strict-pin-entry')),
      '2468',
    );
    await tester.tap(find.byKey(const ValueKey('strict-pin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Plug in a charger first.'), findsOneWidget);
    expect(store.strict, isNotNull);

    charging = true;
    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('strict-pin-entry')),
      '0000',
    );
    await tester.tap(find.byKey(const ValueKey('strict-pin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('That PIN is wrong.'), findsOneWidget);
    expect(store.strict, isNotNull);

    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('strict-pin-entry')),
      '2468',
    );
    await tester.tap(find.byKey(const ValueKey('strict-pin-submit')));
    await tester.pumpAndSettle();

    expect(store.strict, isNull);
    expect(blockingService.syncs, 1);
    expect(changes, 1);
    expect(find.text('Strict mode'), findsOneWidget);
  });

  testWidgets('a cooldown gates the unlock', (tester) async {
    charging = true;
    store.strict = strict(
      conditions: {UnlockCondition.charger},
      cooldown: const Duration(minutes: 10),
      pin: null,
    );
    await pump(tester);
    expect(find.text('Request unlock'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pump();
    expect(store.strict!.unlockRequestedAt, isNotNull);
    expect(find.textContaining('Unlock opens in'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('strict-cancel-unlock')));
    await tester.pump();
    expect(store.strict!.unlockRequestedAt, isNull);
    expect(find.text('Request unlock'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    store.strict = strict(
      conditions: {UnlockCondition.charger},
      cooldown: const Duration(minutes: 10),
      unlockRequestedAt: DateTime.now().subtract(const Duration(minutes: 11)),
      pin: null,
    );
    await pump(tester);
    expect(find.text('Unlock'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pump();

    expect(store.strict, isNull);
  });

  testWidgets('a timer-only mode ends by itself', (tester) async {
    store.strict = strict(
      conditions: {UnlockCondition.timer},
      until: DateTime.now().subtract(const Duration(minutes: 1)),
      pin: null,
    );
    await pump(tester);

    expect(find.text('Strict mode has ended'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-done')));
    await tester.pump();

    expect(store.strict, isNull);
    expect(find.text('Strict mode'), findsOneWidget);
  });

  testWidgets('following schedules unlocks only between schedules', (
    tester,
  ) async {
    ruleStore.rules = const [_allWeek];
    store.strict = strict(
      conditions: {UnlockCondition.followSchedules},
      pin: null,
    );
    await pump(tester);
    expect(find.text('Strict mode is on'), findsOneWidget);
    expect(
      find.text('Guards screens while your schedules run'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pump();
    expect(find.text('Wait until your schedules end.'), findsOneWidget);
    expect(store.strict, isNotNull);
    await tester.pumpWidget(const SizedBox());

    ruleStore.rules = const [];
    await pump(tester);
    expect(find.text('Strict mode is on'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pump();

    expect(store.strict, isNull);
  });

  testWidgets('following schedules needs an enabled time schedule', (
    tester,
  ) async {
    await pump(tester);
    FilterChip chip() => tester.widget(
      find.byKey(const ValueKey('strict-condition-followSchedules')),
    );
    expect(chip().onSelected, isNull);
    expect(
      find.textContaining('needs an enabled time schedule'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());

    ruleStore.rules = const [_allWeek];
    await pump(tester);

    expect(chip().onSelected, isNotNull);
  });

  testWidgets('the emergency unlock is easy once, then needs retyping', (
    tester,
  ) async {
    store.strict = strict();
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('strict-emergency')));
    await tester.pumpAndSettle();
    expect(find.text('Emergency 1 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-emergency-stay')));
    await tester.pumpAndSettle();
    expect(store.strict, isNotNull);

    await tester.tap(find.byKey(const ValueKey('strict-emergency')));
    await tester.pumpAndSettle();
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const ValueKey('strict-emergency-proceed')));
      await tester.pumpAndSettle();
    }
    expect(store.strict, isNull);
    expect(store.emergencyUsedFlag, isTrue);
    await tester.pumpWidget(const SizedBox());

    store.strict = strict();
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('strict-emergency')));
    await tester.pumpAndSettle();
    expect(find.text('Retype to unlock'), findsOneWidget);
    TextButton submit() =>
        tester.widget(find.byKey(const ValueKey('strict-retype-submit')));
    expect(submit().onPressed, isNull);
    final shown = tester
        .widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text && widget.style?.fontFamily == 'monospace',
          ),
        )
        .data!;
    expect(shown, hasLength(120));

    await tester.enterText(find.byKey(const ValueKey('strict-retype')), shown);
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('strict-retype-submit')));
    await tester.pumpAndSettle();

    expect(store.strict, isNull);
  });
}

class FakeStrictModeStore extends StrictModeStore {
  StrictMode? strict;
  bool emergencyUsedFlag = false;

  @override
  Future<StrictMode?> read() async => strict;

  @override
  Future<void> write(StrictMode? strict) async {
    this.strict = strict;
  }

  @override
  Future<bool> get emergencyUsed async => emergencyUsedFlag;

  @override
  Future<void> markEmergencyUsed() async {
    emergencyUsedFlag = true;
  }
}

class FakeUninstallGuard extends UninstallGuard {
  bool active = false;
  bool grant = true;
  int activations = 0;
  int deactivations = 0;

  @override
  Future<bool> activate() async {
    activations++;
    active = grant;
    return grant;
  }

  @override
  Future<void> deactivate() async {
    deactivations++;
    active = false;
  }
}

class FakeRuleStore extends RuleStore {
  List<BlockRule> rules = const [];

  @override
  Future<List<BlockRule>> readAll() async => rules;
}

class FakeBlockingService extends BlockingService {
  int syncs = 0;

  @override
  Future<void> sync(RuleStore ruleStore) async {
    syncs++;
  }
}
