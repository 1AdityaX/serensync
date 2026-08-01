import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:serensync/blocking/blocking_engine.dart';
import 'package:serensync/blocking/rule.dart';
import 'package:serensync/blocking/rule_store.dart';
import 'package:serensync/onboarding/permission_flow.dart';
import 'package:serensync/onboarding/permission_status.dart';

void main() {
  testWidgets('permission screen shows granted and missing permissions', (
    tester,
  ) async {
    final permissionStatus = FakePermissionStatus(
      const PermissionState(
        usageAccess: true,
        overlay: false,
        notifications: true,
        batteryOptimisation: false,
      ),
    );
    await _pump(tester, permissionStatus: permissionStatus);

    expect(find.text('Usage access'), findsOneWidget);
    expect(find.text('Display over other apps'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Battery optimisation'), findsOneWidget);
    expect(find.text('Granted'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('grant-overlay')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('grant-batteryOptimisation')),
      findsOneWidget,
    );
  });

  testWidgets('returning to the app rechecks permission state', (tester) async {
    final permissionStatus = FakePermissionStatus(
      const PermissionState(
        usageAccess: false,
        overlay: true,
        notifications: true,
        batteryOptimisation: true,
      ),
    );
    await _pump(tester, permissionStatus: permissionStatus);
    expect(find.byKey(const ValueKey('grant-usageAccess')), findsOneWidget);

    permissionStatus.state = const PermissionState(
      usageAccess: true,
      overlay: true,
      notifications: true,
      batteryOptimisation: true,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(const ValueKey('grant-usageAccess')), findsNothing);
    expect(find.text('Granted'), findsNWidgets(4));
  });

  testWidgets('blocking stays off while a permission is missing', (
    tester,
  ) async {
    final service = FakeBlockingService();
    await _pump(
      tester,
      permissionStatus: FakePermissionStatus(
        const PermissionState(
          usageAccess: true,
          overlay: false,
          notifications: true,
          batteryOptimisation: true,
        ),
      ),
      rules: <BlockRule>[_rule()],
      service: service,
    );

    expect(find.text('Blocking is off'), findsOneWidget);
    expect(_toggle(tester).onPressed, isNull);
    expect(service.running, isFalse);
  });

  testWidgets('blocking stays off when there are no enabled rules', (
    tester,
  ) async {
    final service = FakeBlockingService();
    await _pump(
      tester,
      permissionStatus: FakePermissionStatus(_grantedPermissions),
      rules: <BlockRule>[_rule(enabled: false)],
      service: service,
    );

    expect(find.text('Blocking is off'), findsOneWidget);
    expect(_toggle(tester).onPressed, isNull);
    expect(service.running, isFalse);
  });

  testWidgets('turning blocking off stops it and updates the screen', (
    tester,
  ) async {
    final service = FakeBlockingService(running: true);
    await _pump(
      tester,
      permissionStatus: FakePermissionStatus(_grantedPermissions),
      rules: <BlockRule>[_rule()],
      service: service,
    );

    expect(find.text('Blocking is on'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('blocking-toggle')));
    await tester.pump();

    expect(service.running, isFalse);
    expect(find.text('Blocking is off'), findsOneWidget);
  });

  testWidgets(
    'revoked permission does not leave a running service claiming to enforce',
    (tester) async {
      final permissionStatus = FakePermissionStatus(_grantedPermissions);
      await _pump(
        tester,
        permissionStatus: permissionStatus,
        rules: <BlockRule>[_rule()],
        service: FakeBlockingService(running: true),
      );
      expect(find.text('Blocking is on'), findsOneWidget);

      permissionStatus.state = const PermissionState(
        usageAccess: false,
        overlay: true,
        notifications: true,
        batteryOptimisation: true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('Blocking is on but cannot enforce'), findsOneWidget);
      expect(
        find.text('Grant usage access before SerenSync can enforce.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a service start failure is shown to the user', (tester) async {
    final service = FakeBlockingService(
      startResult: ServiceRequestFailure(error: StateError('not allowed')),
    );
    await _pump(
      tester,
      permissionStatus: FakePermissionStatus(_grantedPermissions),
      rules: <BlockRule>[_rule()],
      service: service,
    );

    await tester.tap(find.byKey(const ValueKey('blocking-toggle')));
    await tester.pump();

    expect(
      find.text('Unable to start blocking: Bad state: not allowed'),
      findsOneWidget,
    );
    expect(find.text('Blocking is off'), findsOneWidget);
  });
}

const _grantedPermissions = PermissionState(
  usageAccess: true,
  overlay: true,
  notifications: true,
  batteryOptimisation: true,
);

Future<void> _pump(
  WidgetTester tester, {
  required FakePermissionStatus permissionStatus,
  List<BlockRule> rules = const <BlockRule>[],
  FakeBlockingService? service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PermissionFlow(
        permissionStatus: permissionStatus,
        ruleStore: FakeRuleStore(rules),
        blockingService: service ?? FakeBlockingService(),
      ),
    ),
  );
  await tester.pump();
}

TextButton _toggle(WidgetTester tester) {
  return tester.widget<TextButton>(
    find.byKey(const ValueKey('blocking-toggle')),
  );
}

BlockRule _rule({bool enabled = true}) {
  return BlockRule(
    id: 1,
    name: 'Focus',
    packages: const <String>{'com.example.app'},
    trigger: const LaunchQuota(1),
    enabled: enabled,
  );
}

class FakePermissionStatus extends PermissionStatus {
  FakePermissionStatus(this.state);

  PermissionState state;

  @override
  Future<PermissionState> check() async => state;

  @override
  Future<void> request(RequiredPermission permission) async {}
}

class FakeRuleStore extends RuleStore {
  FakeRuleStore(this.rules);

  final List<BlockRule> rules;

  @override
  Future<List<BlockRule>> readAll() async => rules;
}

class FakeBlockingService extends BlockingService {
  FakeBlockingService({
    this.running = false,
    this.startResult = const ServiceRequestSuccess(),
  });

  bool running;
  ServiceRequestResult startResult;

  @override
  Future<bool> get isRunning async => running;

  @override
  Future<ServiceRequestResult> start() async {
    if (startResult is ServiceRequestSuccess) running = true;
    return startResult;
  }

  @override
  Future<bool> stop() async {
    running = false;
    return true;
  }
}
