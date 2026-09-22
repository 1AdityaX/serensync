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

void main() {
  late FakeStrictModeStore store;
  late FakeBlockingService blockingService;
  late FakeRuleStore ruleStore;
  late FakeUninstallGuard uninstallGuard;
  late int changes;

  setUp(() {
    store = FakeStrictModeStore();
    blockingService = FakeBlockingService();
    ruleStore = FakeRuleStore();
    uninstallGuard = FakeUninstallGuard();
    changes = 0;
  });

  // A small phone, so anything that does not fit fails the test.
  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          appBar: AppBar(title: const Text('SerenSync')),
          body: StrictTab(
            ruleStore: ruleStore,
            blockingService: blockingService,
            strictModeStore: store,
            onChanged: () => changes++,
            uninstallGuard: uninstallGuard,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.shield), label: 'Strict'),
              NavigationDestination(icon: Icon(Icons.block), label: 'Blocks'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    // Countdowns keep a one-second ticker; unmount so it is cancelled.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('strict-next')));
    await tester.pumpAndSettle();
  }

  // The small screen scrolls; bring the target into view before tapping.
  Future<void> tapVisible(WidgetTester tester, Key key) async {
    await Scrollable.ensureVisible(
      tester.element(find.byKey(key)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tapVisible(tester, ValueKey('strict-key-$digit'));
    }
  }

  Switch lockSwitch(WidgetTester tester, StrictLock lock) =>
      tester.widget(find.byKey(ValueKey('strict-lock-${lock.name}')));

  FilledButton primary(WidgetTester tester, String key) =>
      tester.widget(find.byKey(ValueKey(key)));

  StrictMode strict({
    Set<StrictLock> locks = const {},
    DateTime? until,
    Duration? cooldown,
    DateTime? unlockRequestedAt,
    String pin = '2468',
  }) {
    return StrictMode(
      locks: locks,
      activatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      until: until,
      pin: until == null ? PinHash.create(pin, Random(1)) : null,
      cooldown: cooldown,
      unlockRequestedAt: unlockRequestedAt,
    );
  }

  testWidgets('a timer locks the blocks and ends by itself', (tester) async {
    await pump(tester);
    expect(find.text('How will it end?'), findsOneWidget);

    await next(tester);
    expect(find.text('For how long?'), findsOneWidget);
    await tapVisible(tester, const ValueKey('strict-quick-180m'));
    expect(find.text('3 hours'), findsWidgets);

    await next(tester);
    expect(find.text('What stays locked?'), findsOneWidget);
    expect(lockSwitch(tester, StrictLock.settings).value, isTrue);
    expect(lockSwitch(tester, StrictLock.settings).onChanged, isNull);
    expect(find.textContaining('Kept on by the timer'), findsOneWidget);

    await next(tester);
    expect(find.text('Lock for 3 hours?'), findsOneWidget);
    await tapVisible(tester, const ValueKey('strict-activate'));

    final saved = store.strict!;
    expect(saved.timed, isTrue);
    expect(saved.pin, isNull);
    expect(saved.cooldown, isNull);
    expect(saved.locks, {StrictLock.settings});
    expect(
      saved.until!.difference(saved.activatedAt),
      const Duration(hours: 3),
    );
    expect(blockingService.syncs, 1);
    expect(changes, 1);
    expect(find.text('Strict mode is on'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
    expect(find.byKey(const ValueKey('strict-unlock')), findsNothing);
  });

  testWidgets('the wheels take any length up to 99 days', (tester) async {
    await pump(tester);
    await next(tester);

    // Two notches down on the hours wheel: 1 hour becomes 3 hours.
    await tester.drag(
      find.byKey(const ValueKey('strict-timer-hours')),
      const Offset(0, -88),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('strict-timer-minutes')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 h 5 min'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('strict-timer-days')),
      const Offset(0, -44.0 * 99),
    );
    await tester.pumpAndSettle();
    expect(find.text('99 days 3 h 5 min'), findsOneWidget);
    await next(tester);
    await next(tester);
    await tapVisible(tester, const ValueKey('strict-activate'));

    final saved = store.strict!;
    expect(
      saved.until!.difference(saved.activatedAt),
      const Duration(days: 99, hours: 3, minutes: 5),
    );
  });

  testWidgets('a pin must be confirmed, then a cooldown can be set', (
    tester,
  ) async {
    await pump(tester);
    await tapVisible(tester, const ValueKey('strict-end-pin'));
    expect(find.text('Locks until the PIN is entered.'), findsOneWidget);
    await next(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(primary(tester, 'strict-next').onPressed, isNull);

    await typePin(tester, '123');
    expect(primary(tester, 'strict-next').onPressed, isNull);
    await typePin(tester, '4');
    await next(tester);
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await typePin(tester, '1235');
    await next(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(find.text('Those did not match. Start again.'), findsOneWidget);

    await typePin(tester, '1234');
    await next(tester);
    await typePin(tester, '1234');
    await next(tester);
    expect(find.text('Wait before unlocking?'), findsOneWidget);
    expect(find.text('No wait. The PIN unlocks at once.'), findsOneWidget);
    await tapVisible(tester, const ValueKey('strict-cool-60m'));
    expect(find.text('Unlocking waits 1 hour after you ask.'), findsOneWidget);

    await next(tester);
    expect(find.textContaining('Kept on by the cooldown'), findsOneWidget);
    await next(tester);
    expect(find.text('Lock until the PIN?'), findsOneWidget);
    await tapVisible(tester, const ValueKey('strict-activate'));

    final saved = store.strict!;
    expect(saved.timed, isFalse);
    expect(saved.pin!.matches('1234'), isTrue);
    expect(saved.cooldown, const Duration(hours: 1));
    expect(saved.locks, {StrictLock.settings});
    expect(find.text('Request unlock'), findsOneWidget);
  });

  testWidgets('going back keeps the choices', (tester) async {
    await pump(tester);
    await next(tester);
    await tapVisible(tester, const ValueKey('strict-quick-480m'));
    await next(tester);
    await tapVisible(tester, const ValueKey('strict-lock-recents'));
    await next(tester);
    expect(find.text('Lock for 8 hours?'), findsOneWidget);

    await tapVisible(tester, const ValueKey('strict-back'));
    expect(lockSwitch(tester, StrictLock.recents).value, isTrue);
    await tapVisible(tester, const ValueKey('strict-back'));
    expect(find.text('8 hours'), findsWidgets);
    await tapVisible(tester, const ValueKey('strict-back'));
    expect(find.text('How will it end?'), findsOneWidget);
  });

  testWidgets('blocking uninstalls needs the device admin and Settings lock', (
    tester,
  ) async {
    await pump(tester);
    await tapVisible(tester, const ValueKey('strict-end-pin'));
    await next(tester);
    await typePin(tester, '1234');
    await next(tester);
    await typePin(tester, '1234');
    await next(tester);
    await next(tester);
    expect(lockSwitch(tester, StrictLock.settings).value, isFalse);
    expect(lockSwitch(tester, StrictLock.settings).onChanged, isNotNull);

    await tapVisible(tester, const ValueKey('strict-lock-uninstall'));
    expect(lockSwitch(tester, StrictLock.uninstall).value, isTrue);
    expect(lockSwitch(tester, StrictLock.settings).value, isTrue);
    expect(lockSwitch(tester, StrictLock.settings).onChanged, isNull);

    await tapVisible(tester, const ValueKey('strict-lock-uninstall'));
    expect(lockSwitch(tester, StrictLock.settings).value, isFalse);

    await tapVisible(tester, const ValueKey('strict-lock-uninstall'));
    await next(tester);
    uninstallGuard.grant = false;
    await tapVisible(tester, const ValueKey('strict-activate'));
    expect(uninstallGuard.activations, 1);
    expect(store.strict, isNull);
    expect(
      find.textContaining('needs SerenSync as a device admin'),
      findsOneWidget,
    );

    uninstallGuard.grant = true;
    await tapVisible(tester, const ValueKey('strict-activate'));
    expect(uninstallGuard.activations, 2);
    expect(store.strict!.locks, {StrictLock.settings, StrictLock.uninstall});
    await tester.pumpWidget(const SizedBox());

    store.strict = strict(locks: {StrictLock.settings, StrictLock.uninstall});
    uninstallGuard.active = true;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pumpAndSettle();
    await typePin(tester, '2468');
    await tester.tap(find.byKey(const ValueKey('strict-pin-submit')));
    await tester.pumpAndSettle();

    expect(store.strict, isNull);
    expect(uninstallGuard.deactivations, 1);
  });

  testWidgets('locks can be added while strict mode runs, never removed', (
    tester,
  ) async {
    store.strict = strict(
      until: DateTime.now().add(const Duration(hours: 2)),
      locks: {StrictLock.settings},
    );
    await pump(tester);
    expect(lockSwitch(tester, StrictLock.settings).onChanged, isNull);
    expect(lockSwitch(tester, StrictLock.recents).onChanged, isNotNull);

    await tapVisible(tester, const ValueKey('strict-lock-recents'));
    expect(find.text('Turn on block recent apps?'), findsOneWidget);
    expect(
      find.textContaining('cannot be undone until strict mode ends'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('strict-lock-cancel')));
    await tester.pumpAndSettle();
    expect(store.strict!.locks, {StrictLock.settings});
    expect(lockSwitch(tester, StrictLock.recents).onChanged, isNotNull);

    await tapVisible(tester, const ValueKey('strict-lock-recents'));
    await tester.tap(find.byKey(const ValueKey('strict-lock-confirm')));
    await tester.pumpAndSettle();
    expect(store.strict!.locks, {StrictLock.settings, StrictLock.recents});
    expect(lockSwitch(tester, StrictLock.recents).onChanged, isNull);
    expect(blockingService.syncs, 1);
    expect(changes, 1);

    uninstallGuard.grant = false;
    await tapVisible(tester, const ValueKey('strict-lock-uninstall'));
    await tester.tap(find.byKey(const ValueKey('strict-lock-confirm')));
    await tester.pumpAndSettle();
    expect(store.strict!.locks, {StrictLock.settings, StrictLock.recents});
    expect(
      find.textContaining('needs SerenSync as a device admin'),
      findsOneWidget,
    );

    uninstallGuard.grant = true;
    await tapVisible(tester, const ValueKey('strict-lock-uninstall'));
    await tester.tap(find.byKey(const ValueKey('strict-lock-confirm')));
    await tester.pumpAndSettle();
    expect(store.strict!.locks, {
      StrictLock.settings,
      StrictLock.recents,
      StrictLock.uninstall,
    });
  });

  testWidgets('unlocking needs the right pin', (tester) async {
    store.strict = strict(locks: {StrictLock.recents});
    await pump(tester);
    expect(find.text('Until the PIN'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(lockSwitch(tester, StrictLock.recents).onChanged, isNull);
    expect(find.textContaining('Kept on by'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsOneWidget);
    await typePin(tester, '0000');
    await tester.tap(find.byKey(const ValueKey('strict-pin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('That PIN is wrong.'), findsOneWidget);
    expect(store.strict, isNotNull);

    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pumpAndSettle();
    await typePin(tester, '2468');
    await tester.tap(find.byKey(const ValueKey('strict-pin-submit')));
    await tester.pumpAndSettle();

    expect(store.strict, isNull);
    expect(blockingService.syncs, 1);
    expect(changes, 1);
    expect(find.text('How will it end?'), findsOneWidget);
  });

  testWidgets('a cooldown gates the unlock', (tester) async {
    store.strict = strict(cooldown: const Duration(minutes: 10));
    await pump(tester);
    expect(find.text('Request unlock'), findsOneWidget);
    expect(find.text('PIN after a 10 min wait'), findsOneWidget);

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
      cooldown: const Duration(minutes: 10),
      unlockRequestedAt: DateTime.now().subtract(const Duration(minutes: 11)),
    );
    await pump(tester);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('Unlock is open'), findsOneWidget);
  });

  testWidgets('a timer ends by itself', (tester) async {
    store.strict = strict(
      until: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await pump(tester);

    expect(find.text('Strict mode has ended'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-done')));
    await tester.pump();

    expect(store.strict, isNull);
    expect(find.text('How will it end?'), findsOneWidget);
  });

  testWidgets('the emergency unlock is easy once, then needs retyping', (
    tester,
  ) async {
    store.strict = strict();
    await pump(tester);

    await tapVisible(tester, const ValueKey('strict-emergency'));
    expect(find.text('Emergency 1 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-emergency-stay')));
    await tester.pumpAndSettle();
    expect(store.strict, isNotNull);

    await tapVisible(tester, const ValueKey('strict-emergency'));
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const ValueKey('strict-emergency-proceed')));
      await tester.pumpAndSettle();
    }
    expect(store.strict, isNull);
    expect(store.emergencyUsedFlag, isTrue);
    await tester.pumpWidget(const SizedBox());

    store.strict = strict();
    await pump(tester);
    await tapVisible(tester, const ValueKey('strict-emergency'));
    expect(find.text('Retype to unlock'), findsOneWidget);
    TextButton submit() =>
        tester.widget(find.byKey(const ValueKey('strict-retype-submit')));
    expect(submit().onPressed, isNull);
    final shown = tester
        .widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.style?.fontFamily == 'monospace' &&
                widget.data?.length == emergencyTextLength,
          ),
        )
        .data!;

    await tester.enterText(find.byKey(const ValueKey('strict-retype')), shown);
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('strict-retype-submit')));
    await tester.pumpAndSettle();

    expect(store.strict, isNull);
  });

  testWidgets('every screen fits a small phone with large text', (
    tester,
  ) async {
    await pump(tester, textScale: 1.3);
    await tapVisible(tester, const ValueKey('strict-end-pin'));
    await next(tester);
    await typePin(tester, '1234');
    await next(tester);
    await typePin(tester, '1234');
    await next(tester);
    await tapVisible(tester, const ValueKey('strict-cool-1440m'));
    await next(tester);
    await tapVisible(tester, const ValueKey('strict-lock-uninstall'));
    await tapVisible(tester, const ValueKey('strict-lock-recents'));
    await tapVisible(tester, const ValueKey('strict-lock-newApps'));
    await next(tester);
    await tapVisible(tester, const ValueKey('strict-activate'));
    expect(find.text('Strict mode is on'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('strict-unlock')));
    await tester.pump();
    expect(find.textContaining('Unlock opens in'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('strict-cancel-unlock')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    store.strict = strict(
      until: DateTime.now().add(const Duration(days: 99)),
      locks: StrictLock.values.toSet(),
    );
    await pump(tester, textScale: 1.3);
    expect(find.text('Strict mode is on'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    store.strict = strict(until: DateTime.now());
    await pump(tester, textScale: 1.3);
    expect(find.text('Strict mode has ended'), findsOneWidget);
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
