import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/apps_screen.dart';
import 'package:serensync/home/home_screen.dart';
import 'package:serensync/main.dart';

void main() {
  late FakeAppService appService;

  setUp(() {
    appService = FakeAppService([
      _app('Alpha', 'com.example.alpha', 'com.example.alpha.MainActivity'),
      _app('Beta', 'com.example.beta', 'com.example.beta.MainActivity'),
    ]);
  });

  tearDown(() => appService.dispose());

  testWidgets('app launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(appService: appService));
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('app drawer filters, launches, and clears the search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(TestApp(child: AppsScreen(appService: appService)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'bet');
    await tester.pump();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);

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
    await tester.pumpWidget(MyApp(appService: appService));
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
    await tester.pumpWidget(MyApp(appService: appService));
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsNothing);
    expect(appService.appListLoads, 1);
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
            _app(
              'Fresh',
              'com.example.fresh',
              'com.example.fresh.MainActivity',
            ).toMap(),
          ]);
        });

    final service = AppService();
    final initial = service.getInstalledApps();
    final refreshed = service.getInstalledApps(forceRefresh: true);
    firstScan.complete([
      _app(
        'Stale',
        'com.example.stale',
        'com.example.stale.MainActivity',
      ).toMap(),
    ]);

    expect((await initial).single.appName, 'Fresh');
    expect((await refreshed).single.appName, 'Fresh');
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
  List<AppInfo> apps;

  FakeAppService(this.apps);

  @override
  Future<List<AppInfo>> getInstalledApps({bool forceRefresh = false}) async {
    appListLoads++;
    if (forceRefresh) forceRefreshes++;
    return apps;
  }

  @override
  Future<void> openApp(AppInfo app) async {
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

AppInfo _app(String name, String packageName, String activityName) {
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
