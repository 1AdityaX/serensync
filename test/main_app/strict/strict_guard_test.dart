import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/strict/strict_guard.dart';
import 'package:serensync/main_app/strict/strict_mode.dart';

void main() {
  final activatedAt = DateTime(2026, 9, 16, 9);
  final installTimes = <String, DateTime>{
    'com.example.old': activatedAt.subtract(const Duration(days: 30)),
    'com.example.fresh': activatedAt.add(const Duration(minutes: 5)),
  };

  StrictMode strict(Set<StrictLock> locks) {
    return StrictMode(
      locks: locks,
      activatedAt: activatedAt,
      until: activatedAt.add(const Duration(hours: 1)),
    );
  }

  test('no lock guards nothing', () {
    expect(guardedPackages(strict({}), installTimes: installTimes), isEmpty);
  });

  test('each lock guards its packages', () {
    expect(
      guardedPackages(strict({StrictLock.settings}), installTimes: {}),
      settingsPackages,
    );
    expect(
      guardedPackages(strict({StrictLock.uninstall}), installTimes: {}),
      installerPackages,
    );
    expect(
      guardedPackages(strict({StrictLock.newApps}), installTimes: installTimes),
      {'com.example.fresh'},
    );
  });

  test('the recents screen is recognised by its activity class', () {
    expect(isRecentsScreen('com.android.quickstep.RecentsActivity'), isTrue);
    expect(isRecentsScreen('com.miui.home.recents.RecentsActivity'), isTrue);
    expect(isRecentsScreen('com.android.launcher3.Launcher'), isFalse);
    expect(isRecentsScreen('com.example.app.RecentsActivity'), isFalse);
    expect(isRecentsScreen(null), isFalse);
  });

  test('the device admin label matches the manifest string', () {
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final label = RegExp(
      r'<string name="device_admin_label">([^<]*)</string>',
    ).firstMatch(strings)!.group(1);

    expect(label, deviceAdminLabel);
  });

  test('admin guard rules only look for views inside their own packages', () {
    for (final rule in adminGuardRules) {
      expect(rule.packages, isNotEmpty);
      expect(settingsPackages, containsAll(rule.packages));
      if (rule.viewId case final viewId?) {
        expect(rule.packages, contains(viewId.split(':id/').first));
      }
    }
    expect(
      adminGuardRules.map((rule) => rule.text),
      contains(deviceAdminLabel),
    );
  });

  test('locks combine', () {
    expect(
      guardedPackages(
        strict({StrictLock.settings, StrictLock.uninstall, StrictLock.newApps}),
        installTimes: installTimes,
      ),
      {...settingsPackages, ...installerPackages, 'com.example.fresh'},
    );
  });
}
