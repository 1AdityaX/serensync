import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/app_store.dart';
import 'package:serensync/apps/installed_app.dart';
import 'package:serensync/launcher/apps_screen.dart';
import 'package:serensync/launcher/home/home_screen.dart';
import 'package:serensync/launcher/launcher_controller.dart';
import 'package:serensync/main.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/onboarding/permission_status.dart';
import 'package:serensync/main_app/blocking/rule.dart';
import 'package:serensync/main_app/blocking/rule_store.dart';
import 'package:serensync/main_app/onboarding/onboarding_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late FakeAppService appService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    appService = FakeAppService([
      _app('Alpha', 'com.example.alpha', 'com.example.alpha.MainActivity'),
      _app('Beta', 'com.example.beta', 'com.example.beta.MainActivity'),
    ]);
  });

  tearDown(() => appService.dispose());

  testWidgets('app drawer filters, launches, and clears the search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(TestApp(child: AppsScreen(appService: appService)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'bet');
    await tester.pump();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Beta')).style?.fontSize, 20);

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(appService.openedPackages, ['com.example.beta']);
    expect(appService.openedActivities, ['com.example.beta.MainActivity']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('opening SerenSync from its launcher shows the main app', (
    WidgetTester tester,
  ) async {
    appService.apps = [
      _app(
        'SerenSync',
        'com.example.serensync',
        'com.example.serensync.MainActivity',
      ),
    ];
    await tester.pumpWidget(
      MyApp(
        appService: appService,
        launcherController: FakeLauncherController(openedFromHome: true),
        ruleStore: FakeRuleStore(),
        onboardingStore: FakeOnboardingStore(complete: true),
        permissionStatus: FakePermissionStatus(),
        blockingService: FakeBlockingService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SerenSync'));
    await tester.pumpAndSettle();

    expect(find.text('Create a block'), findsOneWidget);
    expect(appService.openedPackages, isEmpty);
  });

  testWidgets('app drawer refreshes when installed apps change', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(TestApp(child: AppsScreen(appService: appService)));
    await tester.pump();

    appService.apps = [
      ...appService.apps,
      _app('Gamma', 'com.example.gamma', 'com.example.gamma.MainActivity'),
    ];
    appService.notifyAppsChanged();
    await tester.pumpAndSettle();

    expect(find.text('Gamma'), findsOneWidget);
    expect(appService.forceRefreshes, 1);

    appService.apps = appService.apps
        .where((app) => app.packageName != 'com.example.beta')
        .toList();
    appService.notifyAppsChanged();
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsNothing);
    expect(appService.forceRefreshes, 2);
  });

  testWidgets('app drawer renders persisted apps while scan is running', (
    WidgetTester tester,
  ) async {
    appService.persistedApps = [
      _app('Cached', 'com.example.cached', 'com.example.cached.MainActivity'),
    ];
    appService.pendingLoad = Completer<List<InstalledApp>>();

    await tester.pumpWidget(TestApp(child: AppsScreen(appService: appService)));
    await tester.pump();

    expect(find.text('Cached'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(appService.appListLoads, 1);
  });

  testWidgets('app drawer paints persisted apps before starting the scan', (
    WidgetTester tester,
  ) async {
    final persistedLoad = Completer<List<InstalledApp>>();
    appService.pendingPersistedLoad = persistedLoad;
    await tester.pumpWidget(TestApp(child: AppsScreen(appService: appService)));

    var cachedAppsRendered = false;
    var scansWhenRendered = -1;
    tester.binding.addPostFrameCallback((_) {
      cachedAppsRendered = find.text('Cached').evaluate().isNotEmpty;
      scansWhenRendered = appService.appListLoads;
    });

    persistedLoad.complete([
      _app('Cached', 'com.example.cached', 'com.example.cached.MainActivity'),
    ]);
    await tester.pump();

    expect(cachedAppsRendered, isTrue);
    expect(scansWhenRendered, 0);
    expect(appService.appListLoads, 1);
  });

  testWidgets('home shortcuts use the default phone and camera apps', (
    WidgetTester tester,
  ) async {
    var dialerLaunches = 0;
    var cameraLaunches = 0;
    await tester.pumpWidget(
      TestApp(
        child: HomeScreen(
          onOpenDialer: () async => dialerLaunches++,
          onOpenCamera: () async => cameraLaunches++,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.call));
    await tester.tap(find.byIcon(Icons.camera_alt));

    expect(dialerLaunches, 1);
    expect(cameraLaunches, 1);
  });

  testWidgets('leaving and reopening app drawer does not reload apps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        appService: appService,
        launcherController: FakeLauncherController(openedFromHome: true),
        ruleStore: FakeRuleStore(),
        onboardingStore: FakeOnboardingStore(complete: true),
        permissionStatus: FakePermissionStatus(),
        blockingService: FakeBlockingService(),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(appService.appListLoads, 1);

    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(appService.appListLoads, 1);
  });

  testWidgets('back from app drawer returns home without reloading apps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        appService: appService,
        launcherController: FakeLauncherController(openedFromHome: true),
        ruleStore: FakeRuleStore(),
        onboardingStore: FakeOnboardingStore(complete: true),
        permissionStatus: FakePermissionStatus(),
        blockingService: FakeBlockingService(),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    expect(appService.appListLoads, 1);
  });

  testWidgets('back on home is absorbed without rebuilding the launcher', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        appService: appService,
        launcherController: FakeLauncherController(openedFromHome: true),
        ruleStore: FakeRuleStore(),
        onboardingStore: FakeOnboardingStore(complete: true),
        permissionStatus: FakePermissionStatus(),
        blockingService: FakeBlockingService(),
      ),
    );
    await tester.pumpAndSettle();
    final homeElement = tester.element(find.byType(HomeScreen));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.element(find.byType(HomeScreen)), same(homeElement));
    expect(appService.appListLoads, 0);
  });

  testWidgets('app icon opens the dashboard with a launcher placeholder', (
    WidgetTester tester,
  ) async {
    final blockingService = FakeBlockingService();
    await tester.pumpWidget(
      MyApp(
        appService: appService,
        launcherController: FakeLauncherController(),
        ruleStore: FakeRuleStore(),
        onboardingStore: FakeOnboardingStore(complete: true),
        permissionStatus: FakePermissionStatus(),
        blockingService: blockingService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create a block'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(blockingService.syncs, 1);

    await tester.tap(find.text('Settings'));
    await tester.pump();

    expect(find.text('Minimal launcher'), findsOneWidget);
    expect(find.text('App blocking'), findsNothing);
  });

  testWidgets(
    'first open shows the intro and finishing it opens the dashboard',
    (WidgetTester tester) async {
      final onboardingStore = FakeOnboardingStore(complete: false);
      await tester.pumpWidget(
        MyApp(
          appService: appService,
          launcherController: FakeLauncherController(),
          ruleStore: FakeRuleStore(),
          onboardingStore: onboardingStore,
          permissionStatus: FakePermissionStatus(),
          blockingService: FakeBlockingService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 hours 37 minutes a day.'), findsOneWidget);
      expect(find.text('Create a block'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      for (var page = 0; page <= RequiredPermission.values.length; page++) {
        await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
        await tester.pumpAndSettle();
      }

      expect(onboardingStore.complete, isTrue);
      expect(find.text('Create a block'), findsOneWidget);
    },
  );

  testWidgets('the launcher never shows the intro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        appService: appService,
        launcherController: FakeLauncherController(openedFromHome: true),
        ruleStore: FakeRuleStore(),
        onboardingStore: FakeOnboardingStore(complete: false),
        permissionStatus: FakePermissionStatus(),
        blockingService: FakeBlockingService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('4 hours 37 minutes a day.'), findsNothing);
  });

  test('queues a refresh while an app scan is running', () async {
    const channel = MethodChannel('apps_handler');
    final firstScan = Completer<Object?>();
    var scans = 0;

    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          scans++;
          if (scans == 1) return firstScan.future;
          return Future.value([
            _pluginApp(
              'Fresh',
              'com.example.fresh',
              'com.example.fresh.MainActivity',
            ).toMap(),
          ]);
        });

    final service = AppService(store: FakeAppStore());
    final initial = service.getInstalledApps();
    final refreshed = service.getInstalledApps(forceRefresh: true);
    firstScan.complete([
      _pluginApp(
        'Stale',
        'com.example.stale',
        'com.example.stale.MainActivity',
      ).toMap(),
    ]);

    expect((await initial).single.displayName, 'Fresh');
    expect((await refreshed).single.displayName, 'Fresh');
    expect(scans, 2);
  });
}

class TestApp extends StatelessWidget {
  final Widget child;

  const TestApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MaterialApp(home: child);
}

class FakeAppService extends AppService {
  final StreamController<AppEvent> _changes = StreamController.broadcast();
  final List<String> openedPackages = [];
  final List<String?> openedActivities = [];
  int appListLoads = 0;
  int forceRefreshes = 0;
  List<InstalledApp> apps;
  List<InstalledApp> persistedApps = const [];
  Completer<List<InstalledApp>>? pendingLoad;
  Completer<List<InstalledApp>>? pendingPersistedLoad;

  FakeAppService(this.apps) : super(store: FakeAppStore());

  @override
  Future<List<InstalledApp>> readPersistedApps() =>
      pendingPersistedLoad?.future ?? Future.value(persistedApps);

  @override
  Future<List<InstalledApp>> getInstalledApps({bool forceRefresh = false}) {
    appListLoads++;
    if (forceRefresh) forceRefreshes++;
    return pendingLoad?.future ?? Future.value(apps);
  }

  @override
  Future<void> openApp(InstalledApp app) async {
    openedPackages.add(app.packageName);
    openedActivities.add(app.activityName);
  }

  @override
  Stream<AppEvent> get appChanges => _changes.stream;

  void notifyAppsChanged() {
    _changes.add(
      const AppEvent(
        packageName: 'com.example.changed',
        event: AppEventType.updated,
      ),
    );
  }

  void dispose() => _changes.close();
}

class FakeRuleStore extends RuleStore {
  @override
  Future<List<BlockRule>> readAll() async => const [];

  @override
  Future<int> insert(BlockRule rule) async => 0;

  @override
  Future<void> update(BlockRule rule) async {}

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> close() async {}
}

class FakeBlockingService extends BlockingService {
  int syncs = 0;

  @override
  Future<void> sync(RuleStore ruleStore) async {
    syncs++;
  }
}

class FakeOnboardingStore extends OnboardingStore {
  FakeOnboardingStore({required this.complete});

  bool complete;

  @override
  Future<bool> get isComplete async => complete;

  @override
  Future<void> markComplete() async => complete = true;
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

  @override
  Future<void> request(RequiredPermission permission) async {}
}

class FakeLauncherController extends LauncherController {
  FakeLauncherController({this.openedFromHome = false, this.enabled = false});

  final bool openedFromHome;
  bool enabled;

  @override
  Future<bool> get isEnabled async => enabled;

  @override
  Future<bool> get openedAsLauncher async => openedFromHome;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }

  @override
  void listenForPresentationChanges(ValueChanged<bool> onChanged) {}

  @override
  void stopListening() {}
}

class FakeAppStore extends AppStore {
  @override
  Future<List<InstalledApp>> readAll() async => const [];

  @override
  Future<void> replaceAll(List<InstalledApp> apps) async {}
}

InstalledApp _app(String name, String packageName, String activityName) {
  return InstalledApp(
    displayName: name,
    packageName: packageName,
    activityName: activityName,
  );
}

AppInfo _pluginApp(String name, String packageName, String activityName) {
  return AppInfo(
    appName: name,
    packageName: packageName,
    activityName: activityName,
    category: '',
    versionName: null,
    versionCode: 1,
    dataDir: '',
    systemApp: false,
    installerPackageName: null,
    enabled: true,
    installTime: 0,
    updateTime: 0,
  );
}
