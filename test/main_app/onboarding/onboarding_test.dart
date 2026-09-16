import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/onboarding/permission_status.dart';
import 'package:serensync/main_app/onboarding/onboarding_screen.dart';

void main() {
  const usageChannel = MethodChannel('usage_stats');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usageChannel, (call) async {
          final now = DateTime.now();
          return [
            _event(
              1,
              now.subtract(const Duration(hours: 2, minutes: 14, seconds: 30)),
            ),
            _event(2, now),
          ];
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(usageChannel, null);
  });

  testWidgets(
    'the story runs in order and skip jumps to the first permission',
    (tester) async {
      await _pump(tester, FakePermissionStatus(_nothingGranted));

      expect(find.text('4 hours 37 minutes a day.'), findsOneWidget);
      await _tapPrimary(tester);
      expect(find.text('58 pickups a day.'), findsOneWidget);
      await _tapPrimary(tester);
      expect(find.text('SerenSync closes the door.'), findsOneWidget);
      await _tapPrimary(tester);
      expect(find.text('Usage access'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-skip')), findsNothing);

      for (var back = 0; back < 3; back++) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(find.text('4 hours 37 minutes a day.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Usage access'), findsOneWidget);
    },
  );

  testWidgets('a permission page asks Android, then rechecks on return', (
    tester,
  ) async {
    final status = FakePermissionStatus(_nothingGranted);
    await _pump(tester, status);
    await _skipStory(tester);

    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await _tapPrimary(tester);
    expect(status.requested, [RequiredPermission.usageAccess]);
    expect(find.text('Open settings'), findsOneWidget);

    status.state = const PermissionState(
      usageAccess: true,
      overlay: false,
      notifications: false,
      batteryOptimisation: false,
      accessibility: false,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('2h 14m'), findsOneWidget);
    expect(
      find.text('on other apps today so far, across 1 open.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);

    await _tapPrimary(tester);
    expect(find.text('Display over other apps'), findsOneWidget);
  });

  testWidgets('permissions granted before setup show as allowed', (
    tester,
  ) async {
    await _pump(tester, FakePermissionStatus(_allGranted));
    await _skipStory(tester);

    for (final permission in RequiredPermission.values) {
      expect(find.text(permissionTitle(permission)), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await _tapPrimary(tester);
    }
    expect(find.text('Ready.'), findsOneWidget);
    expect(
      find.text('Create your first block and choose the apps it covers.'),
      findsOneWidget,
    );
  });

  testWidgets('skipping every permission finishes and points to Settings', (
    tester,
  ) async {
    var finished = 0;
    await _pump(
      tester,
      FakePermissionStatus(_nothingGranted),
      onFinished: () => finished++,
    );
    await _skipStory(tester);

    for (var index = 0; index < RequiredPermission.values.length; index++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-secondary')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Ready.'), findsOneWidget);
    expect(
      find.text('Anything you skipped can be allowed later from Settings.'),
      findsOneWidget,
    );
    expect(finished, 0);
    await _tapPrimary(tester);
    expect(finished, 1);
  });

  testWidgets('the accessibility page explains restricted settings', (
    tester,
  ) async {
    await _pump(tester, FakePermissionStatus(_nothingGranted));
    await _skipStory(tester);
    for (var index = 0; index < RequiredPermission.values.length - 1; index++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-secondary')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.textContaining('allow restricted settings'), findsOneWidget);
  });
}

const _nothingGranted = PermissionState(
  usageAccess: false,
  overlay: false,
  notifications: false,
  batteryOptimisation: false,
  accessibility: false,
);

const _allGranted = PermissionState(
  usageAccess: true,
  overlay: true,
  notifications: true,
  batteryOptimisation: true,
  accessibility: true,
);

Map<String, String?> _event(int type, DateTime at) {
  return <String, String?>{
    'eventType': '$type',
    'timeStamp': '${at.millisecondsSinceEpoch}',
    'packageName': 'com.example.feed',
    'className': null,
  };
}

Future<void> _pump(
  WidgetTester tester,
  FakePermissionStatus status, {
  VoidCallback? onFinished,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingScreen(
        permissionStatus: status,
        onFinished: onFinished ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPrimary(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-primary')));
  await tester.pumpAndSettle();
}

Future<void> _skipStory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
  await tester.pumpAndSettle();
}

class FakePermissionStatus extends PermissionStatus {
  FakePermissionStatus(this.state);

  PermissionState state;
  final List<RequiredPermission> requested = [];

  @override
  Future<PermissionState> check() async => state;

  @override
  Future<void> request(RequiredPermission permission) async {
    requested.add(permission);
  }
}
