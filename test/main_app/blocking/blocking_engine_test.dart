import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/block_overlay.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/foreground_app.dart';
import 'package:serensync/main_app/blocking/rule.dart';

void main() {
  const blockedPackage = 'com.example.blocked';
  const otherPackage = 'com.example.other';
  const ownPackage = 'com.example.serensync';
  final now = DateTime(2026, 7, 27, 12);
  const blockingRule = BlockRule(
    id: 1,
    name: 'One launch',
    packages: <String>{blockedPackage, otherPackage},
    trigger: LaunchQuota(1),
    enabled: true,
  );

  test('a blocked package shows which rule fired', () async {
    final foreground = FakeForegroundApp(
      packageName: blockedPackage,
      usage: const AppUsage(foregroundTime: Duration.zero, launches: 1),
    );
    final overlay = FakeBlockOverlay();
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: overlay,
      rules: const <BlockRule>[blockingRule],
    );

    await engine.tick(now);

    expect(overlay.visible, isTrue);
    expect(overlay.packageName, blockedPackage);
    expect(overlay.ruleName, 'One launch');
  });

  test('showing an overlay does not launch the app', () async {
    var active = false;
    var launches = 0;
    final overlay = BlockOverlay(
      isActive: () async => active,
      showOverlay: (String _) async {
        active = true;
      },
      shareData: (Map<String, String> _) async {},
      launchApp: () {
        launches++;
      },
    );

    await overlay.show(packageName: blockedPackage, rule: blockingRule);

    expect(launches, 0);
  });

  test('showing the same package and rule only shows once', () async {
    var active = false;
    var shows = 0;
    var shares = 0;
    final overlay = BlockOverlay(
      isActive: () async => active,
      showOverlay: (String _) async {
        shows++;
        active = true;
      },
      shareData: (Map<String, String> _) async {
        shares++;
      },
    );

    await overlay.show(packageName: blockedPackage, rule: blockingRule);
    await overlay.show(packageName: blockedPackage, rule: blockingRule);

    expect(shows, 1);
    expect(shares, 1);
  });

  test('changing the blocked package or rule updates the overlay', () async {
    var active = false;
    final data = <Map<String, String>>[];
    const otherRule = BlockRule(
      id: 2,
      name: 'Different rule',
      packages: <String>{otherPackage},
      trigger: LaunchQuota(1),
      enabled: true,
    );
    final overlay = BlockOverlay(
      isActive: () async => active,
      showOverlay: (String _) async {
        active = true;
      },
      shareData: (Map<String, String> value) async {
        data.add(value);
      },
    );

    await overlay.show(packageName: blockedPackage, rule: blockingRule);
    await overlay.show(packageName: otherPackage, rule: blockingRule);
    await overlay.show(packageName: otherPackage, rule: otherRule);

    expect(data, <Map<String, String>>[
      <String, String>{'packageName': blockedPackage, 'ruleName': 'One launch'},
      <String, String>{'packageName': otherPackage, 'ruleName': 'One launch'},
      <String, String>{
        'packageName': otherPackage,
        'ruleName': 'Different rule',
      },
    ]);
  });

  test('hiding an overlay closes it', () async {
    var closes = 0;
    final overlay = BlockOverlay(
      isActive: () async => true,
      closeOverlay: () async {
        closes++;
      },
    );

    await overlay.hide();

    expect(closes, 1);
  });

  test('an allowed package hides the overlay', () async {
    final foreground = FakeForegroundApp(
      packageName: blockedPackage,
      usage: const AppUsage(foregroundTime: Duration.zero, launches: 0),
    );
    final overlay = FakeBlockOverlay()
      ..visible = true
      ..ruleName = 'Old rule';
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: overlay,
      rules: const <BlockRule>[blockingRule],
    );

    await engine.tick(now);

    expect(overlay.visible, isFalse);
    expect(overlay.ruleName, isNull);
  });

  test('own package skips usage and rules', () async {
    final foreground = FakeForegroundApp(
      packageName: ownPackage,
      failOnUsageRead: true,
    );
    final overlay = FakeBlockOverlay()..visible = true;
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: overlay,
      rules: const <BlockRule>[blockingRule],
      ownPackage: ownPackage,
    );

    await engine.tick(now);

    expect(overlay.visible, isFalse);
    expect(foreground.usageReads, 0);
  });

  test('staying in one allowed app does not re-query usage', () async {
    final foreground = FakeForegroundApp(
      packageName: blockedPackage,
      usage: const AppUsage(foregroundTime: Duration.zero, launches: 0),
    );
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: FakeBlockOverlay(),
      rules: const <BlockRule>[blockingRule],
    );

    await engine.tick(now);
    await engine.tick(now.add(const Duration(seconds: 1)));

    expect(foreground.usageReads, 1);
  });

  test('a null foreground package only hides the overlay', () async {
    final foreground = FakeForegroundApp(
      packageName: null,
      failOnUsageRead: true,
    );
    final overlay = FakeBlockOverlay()..visible = true;
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: overlay,
      rules: const <BlockRule>[blockingRule],
    );

    await engine.tick(now);

    expect(overlay.visible, isFalse);
    expect(foreground.usageReads, 0);
  });

  test('screen-off transition hides once and later ticks do no work', () async {
    final foreground = FakeForegroundApp(
      packageName: blockedPackage,
      screenInteractive: false,
      failOnUsageRead: true,
    );
    final overlay = FakeBlockOverlay()..visible = true;
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: overlay,
      rules: const <BlockRule>[blockingRule],
    );

    expect(await engine.tick(now), isFalse);
    expect(overlay.visible, isFalse);
    expect(overlay.hideCalls, 1);

    expect(await engine.tick(now.add(const Duration(minutes: 1))), isNull);
    expect(foreground.usageReads, 0);
    expect(overlay.hideCalls, 1);
    expect(overlay.showCalls, 0);
  });

  test('a blocked package is re-evaluated when its schedule ends', () async {
    const scheduleRule = BlockRule(
      id: 2,
      name: 'Lunch break',
      packages: <String>{blockedPackage},
      trigger: Schedule(
        weekdays: <int>{DateTime.monday},
        startMinute: 12 * 60,
        endMinute: 13 * 60,
      ),
      enabled: true,
    );
    final foreground = FakeForegroundApp(packageName: blockedPackage);
    final overlay = FakeBlockOverlay();
    final engine = BlockingEngine(
      foregroundApp: foreground,
      overlay: overlay,
      rules: const <BlockRule>[scheduleRule],
    );

    await engine.tick(now.add(const Duration(minutes: 30)));
    expect(overlay.visible, isTrue);

    await engine.tick(now.add(const Duration(hours: 1)));

    expect(overlay.visible, isFalse);
  });

  test('replacing rules re-evaluates an allowed package', () async {
    const scheduleRule = BlockRule(
      id: 2,
      name: 'Lunch break',
      packages: <String>{blockedPackage},
      trigger: Schedule(
        weekdays: <int>{DateTime.monday},
        startMinute: 12 * 60,
        endMinute: 13 * 60,
      ),
      enabled: true,
    );
    final foreground = FakeForegroundApp(packageName: blockedPackage);
    final overlay = FakeBlockOverlay();
    final engine = BlockingEngine(foregroundApp: foreground, overlay: overlay);

    await engine.tick(now.add(const Duration(minutes: 30)));
    expect(overlay.visible, isFalse);

    engine.replaceRules(const <BlockRule>[scheduleRule]);
    await engine.tick(now.add(const Duration(minutes: 31)));

    expect(overlay.visible, isTrue);
  });
}

class FakeForegroundApp extends ForegroundApp {
  FakeForegroundApp({
    required this.packageName,
    this.screenInteractive = true,
    this.usage = const AppUsage(foregroundTime: Duration.zero, launches: 0),
    this.failOnUsageRead = false,
  });

  String? packageName;
  bool screenInteractive;
  AppUsage usage;
  final bool failOnUsageRead;
  int usageReads = 0;

  @override
  Future<ForegroundState> foregroundState(DateTime now) async {
    return (packageName: packageName, screenInteractive: screenInteractive);
  }

  @override
  Future<AppUsage> todayUsage(String packageName, DateTime now) async {
    usageReads++;
    if (failOnUsageRead) {
      throw StateError('Usage should not be read');
    }
    return usage;
  }
}

class FakeBlockOverlay extends BlockOverlay {
  bool visible = false;
  String? packageName;
  String? ruleName;
  int showCalls = 0;
  int hideCalls = 0;

  @override
  Future<void> show({
    required String packageName,
    required BlockRule rule,
  }) async {
    showCalls++;
    visible = true;
    this.packageName = packageName;
    ruleName = rule.name;
  }

  @override
  Future<void> hide() async {
    hideCalls++;
    visible = false;
    packageName = null;
    ruleName = null;
  }
}
