import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/block_overlay.dart';
import 'package:serensync/main_app/blocking/blocking_engine.dart';
import 'package:serensync/main_app/blocking/browser_watcher.dart';
import 'package:serensync/main_app/blocking/foreground_app.dart';
import 'package:serensync/main_app/blocking/rule.dart';

void main() {
  const blockedPackage = 'com.example.blocked';
  const otherPackage = 'com.example.other';
  const ownPackage = 'com.example.serensync';
  const browser = 'com.android.chrome';
  final now = DateTime(2026, 7, 27, 12);
  const blockingRule = BlockRule(
    id: 1,
    name: 'One launch',
    packages: <String>{blockedPackage, otherPackage},
    trigger: LaunchQuota(1),
    enabled: true,
  );
  const webRule = BlockRule(
    id: 3,
    name: 'No Reels',
    packages: <String>{},
    websites: <String>{'instagram.com'},
    keywords: <String>{'casino'},
    trigger: UsageQuota(Duration(hours: 9)),
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
    expect(overlay.host, isNull);
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

  test(
    'changing the blocked package, page, or rule updates the overlay',
    () async {
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
      await overlay.show(
        packageName: browser,
        rule: webRule,
        address: parseAddress('instagram.com/reels'),
      );
      await overlay.show(
        packageName: browser,
        rule: webRule,
        address: parseAddress('instagram.com/explore'),
      );

      expect(data, <Map<String, String>>[
        <String, String>{
          'packageName': blockedPackage,
          'ruleName': 'One launch',
          'host': '',
        },
        <String, String>{
          'packageName': otherPackage,
          'ruleName': 'One launch',
          'host': '',
        },
        <String, String>{
          'packageName': otherPackage,
          'ruleName': 'Different rule',
          'host': '',
        },
        <String, String>{
          'packageName': browser,
          'ruleName': 'No Reels',
          'host': 'instagram.com',
        },
      ]);
    },
  );

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

  test('an open app is blocked once its schedule starts', () async {
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

    await engine.tick(now.subtract(const Duration(minutes: 1)));
    expect(overlay.visible, isFalse);

    await engine.tick(now);

    expect(overlay.visible, isTrue);
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

  group('web pages', () {
    test('a blocked page in the foreground browser shows its host', () async {
      final foreground = FakeForegroundApp(packageName: browser);
      final overlay = FakeBlockOverlay();
      final engine = BlockingEngine(
        foregroundApp: foreground,
        overlay: overlay,
        rules: const <BlockRule>[webRule],
      );
      await engine.tick(now);
      expect(overlay.visible, isFalse);

      await engine.addressChanged(_page(browser, 'instagram.com/reels'), now);

      expect(overlay.visible, isTrue);
      expect(overlay.packageName, browser);
      expect(overlay.host, 'instagram.com');
      expect(overlay.ruleName, 'No Reels');
    });

    test('leaving the page or opening a new tab hides the overlay', () async {
      final foreground = FakeForegroundApp(packageName: browser);
      final overlay = FakeBlockOverlay();
      final engine = BlockingEngine(
        foregroundApp: foreground,
        overlay: overlay,
        rules: const <BlockRule>[webRule],
      );
      await engine.tick(now);

      await engine.addressChanged(_page(browser, 'bestcasino.net'), now);
      expect(overlay.visible, isTrue);
      await engine.addressChanged(_page(browser, 'example.com'), now);
      expect(overlay.visible, isFalse);

      await engine.addressChanged(_page(browser, 'instagram.com'), now);
      expect(overlay.visible, isTrue);
      await engine.addressChanged((browser: browser, address: null), now);
      expect(overlay.visible, isFalse);
    });

    test('a browser coming forward is checked against its last page', () async {
      final foreground = FakeForegroundApp(packageName: otherPackage);
      final overlay = FakeBlockOverlay();
      final engine = BlockingEngine(
        foregroundApp: foreground,
        overlay: overlay,
        rules: const <BlockRule>[webRule],
      );
      await engine.tick(now);

      await engine.addressChanged(_page(browser, 'instagram.com'), now);
      expect(overlay.visible, isFalse);

      foreground.packageName = browser;
      await engine.tick(now.add(const Duration(seconds: 1)));

      expect(overlay.visible, isTrue);
      expect(overlay.host, 'instagram.com');
    });

    test('an app rule takes precedence over the page', () async {
      const browserRule = BlockRule(
        id: 4,
        name: 'No browsing',
        packages: <String>{browser},
        trigger: LaunchQuota(1),
        enabled: true,
      );
      final foreground = FakeForegroundApp(
        packageName: browser,
        usage: const AppUsage(foregroundTime: Duration.zero, launches: 1),
      );
      final overlay = FakeBlockOverlay();
      final engine = BlockingEngine(
        foregroundApp: foreground,
        overlay: overlay,
        rules: const <BlockRule>[webRule, browserRule],
      );

      await engine.addressChanged(_page(browser, 'instagram.com'), now);
      await engine.tick(now);

      expect(overlay.visible, isTrue);
      expect(overlay.ruleName, 'No browsing');
      expect(overlay.host, isNull);
    });

    test('address changes are ignored while the screen is off', () async {
      final foreground = FakeForegroundApp(
        packageName: browser,
        screenInteractive: false,
        failOnUsageRead: true,
      );
      final overlay = FakeBlockOverlay();
      final engine = BlockingEngine(
        foregroundApp: foreground,
        overlay: overlay,
        rules: const <BlockRule>[webRule],
      );
      await engine.tick(now);

      await engine.addressChanged(_page(browser, 'instagram.com'), now);

      expect(overlay.visible, isFalse);
    });

    test('ticks and address changes run one at a time', () async {
      final gate = Completer<void>();
      final foreground = FakeForegroundApp(packageName: browser)
        ..stateGate = gate.future;
      final overlay = FakeBlockOverlay();
      final engine = BlockingEngine(
        foregroundApp: foreground,
        overlay: overlay,
        rules: const <BlockRule>[webRule],
      );

      final tick = engine.tick(now);
      var addressHandled = false;
      final change = engine
          .addressChanged(_page(browser, 'instagram.com'), now)
          .then((_) => addressHandled = true);
      await pumpEventQueue();
      expect(addressHandled, isFalse);

      gate.complete();
      await tick;
      await change;

      expect(overlay.visible, isTrue);
      expect(overlay.host, 'instagram.com');
    });
  });
}

BrowserAddress _page(String browser, String address) {
  return (browser: browser, address: parseAddress(address)!);
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
  Future<void>? stateGate;
  int usageReads = 0;

  @override
  Future<ForegroundState> foregroundState(DateTime now) async {
    await stateGate;
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
  String? host;
  String? ruleName;
  int showCalls = 0;
  int hideCalls = 0;

  @override
  Future<void> show({
    required String packageName,
    required BlockRule rule,
    WebAddress? address,
  }) async {
    showCalls++;
    visible = true;
    this.packageName = packageName;
    host = address?.host;
    ruleName = rule.name;
  }

  @override
  Future<void> hide() async {
    hideCalls++;
    visible = false;
    packageName = null;
    host = null;
    ruleName = null;
  }
}
