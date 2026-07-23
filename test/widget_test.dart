import 'dart:async';

import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/apps/app_service.dart';
import 'package:serensync/apps/apps_screen.dart';
import 'package:serensync/main.dart';

void main() {
  late FakeAppService appService;

  setUp(() {
    appService = FakeAppService([
      _app('Alpha', 'com.example.alpha'),
      _app('Beta', 'com.example.beta'),
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

    appService.apps = [...appService.apps, _app('Gamma', 'com.example.gamma')];
    appService.notifyAppsChanged();
    await tester.pump();

    expect(find.text('Gamma'), findsOneWidget);
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
  List<AppInfo> apps;

  FakeAppService(this.apps);

  @override
  Future<List<AppInfo>> getInstalledApps() async => apps;

  @override
  Future<void> openApp(String packageName) async {
    openedPackages.add(packageName);
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

AppInfo _app(String name, String packageName) {
  return AppInfo(
    appName: name,
    packageName: packageName,
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
