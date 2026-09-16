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
      conditions: const {UnlockCondition.pin},
      locks: locks,
      activatedAt: activatedAt,
    );
  }

  test('locking only the rules guards nothing', () {
    expect(
      guardedPackages(strict({StrictLock.rules}), installTimes: installTimes),
      isEmpty,
    );
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
