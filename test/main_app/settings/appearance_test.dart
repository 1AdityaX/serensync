import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/installed_app.dart';
import 'package:serensync/main.dart';
import 'package:serensync/main_app/blocking/blocking_colors.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/onboarding/permission_status.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/onboarding/onboarding_store.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_session.dart';
import 'package:serensync/main_app/pomodoro/pomodoro_store.dart';
import 'package:serensync/main_app/settings/appearance.dart';
import 'package:serensync/main_app/settings/settings_screen.dart';
import 'package:serensync/main_app/strict/strict_mode.dart';
import 'package:serensync/main_app/strict/strict_mode_store.dart';
import 'package:serensync/launcher/launcher_controller.dart';
import 'package:serensync/theme.dart';

void main() {
  // The palette is shared by the whole app, so every test starts light.
  setUp(() => applyPalette(lightPalette));
  tearDown(() => applyPalette(lightPalette));

  test('auto follows the phone, light and dark do not', () {
    expect(paletteFor(Appearance.system, Brightness.light), lightPalette);
    expect(paletteFor(Appearance.system, Brightness.dark), darkPalette);
    expect(paletteFor(Appearance.light, Brightness.dark), lightPalette);
    expect(paletteFor(Appearance.dark, Brightness.light), darkPalette);
  });

  test('choosing an appearance saves it', () async {
    final store = FakeAppearanceStore();
    final controller = AppearanceController(store: store);

    await controller.choose(Appearance.dark);

    expect(controller.value, Appearance.dark);
    expect(store.saved, Appearance.dark);
  });

  test('switching palettes changes every colour', () {
    expect(applyPalette(darkPalette), isTrue);
    expect(BlockingColors.background, darkPalette.background);
    expect(BlockingColors.text, darkPalette.text);
    expect(BlockingColors.dark, isTrue);
    expect(applyPalette(darkPalette), isFalse);
    expect(appTheme.brightness, Brightness.dark);
  });

  testWidgets('settings switch the app to dark in place', (tester) async {
    final appearance = AppearanceController(store: FakeAppearanceStore());
    await tester.pumpWidget(_app(appearance));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(_background(tester), lightPalette.background);

    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();

    expect(appearance.value, Appearance.dark);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(_background(tester), darkPalette.background);
  });

  testWidgets('auto turns dark when the phone does', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(_app(AppearanceController()));
    await tester.pumpAndSettle();
    expect(BlockingColors.dark, isFalse);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    expect(BlockingColors.dark, isTrue);
    expect(_background(tester), darkPalette.background);
  });

  testWidgets('a chosen light stays light on a dark phone', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(
      _app(AppearanceController(initial: Appearance.light)),
    );
    await tester.pumpAndSettle();

    expect(BlockingColors.dark, isFalse);
    expect(_background(tester), lightPalette.background);
  });
}

Color? _background(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor ??
    Theme.of(
      tester.element(find.byType(Scaffold).last),
    ).scaffoldBackgroundColor;

MyApp _app(AppearanceController appearance) => MyApp(
  appearance: appearance,
  appService: FakeAppService(),
  launcherController: FakeLauncherController(),
  ruleStore: FakeRuleStore(),
  onboardingStore: FakeOnboardingStore(),
  permissionStatus: FakePermissionStatus(),
  blockingService: FakeBlockingService(),
  pomodoroStore: FakePomodoroStore(),
  strictModeStore: FakeStrictModeStore(),
);

class FakeAppearanceStore extends AppearanceStore {
  Appearance? saved;

  @override
  Future<Appearance> read() async => saved ?? Appearance.system;

  @override
  Future<void> write(Appearance appearance) async => saved = appearance;
}

class FakeAppService extends AppService {
  @override
  Future<List<InstalledApp>> getInstalledApps({
    bool forceRefresh = false,
  }) async => const [];
}

class FakeLauncherController extends LauncherController {
  @override
  Future<bool> get openedAsLauncher async => false;

  @override
  void listenForPresentationChanges(ValueChanged<bool> onChanged) {}

  @override
  void stopListening() {}
}

class FakeRuleStore extends RuleStore {
  @override
  Future<List<BlockRule>> readAll() async => const [];
}

class FakeOnboardingStore extends OnboardingStore {
  @override
  Future<bool> get isComplete async => true;
}

class FakePermissionStatus extends PermissionStatus {
  @override
  Future<PermissionState> check() async => const PermissionState(
    usageAccess: true,
    overlay: true,
    notifications: true,
    batteryOptimisation: true,
    accessibility: true,
  );
}

class FakeBlockingService extends BlockingService {
  @override
  Future<void> sync(RuleStore ruleStore) async {}
}

class FakePomodoroStore extends PomodoroStore {
  @override
  Future<PomodoroSession?> readSession() async => null;
}

class FakeStrictModeStore extends StrictModeStore {
  @override
  Future<StrictMode?> read() async => null;
}
