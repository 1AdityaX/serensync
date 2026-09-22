import 'package:apps_handler/apps_handler.dart';
import 'package:tamper_guard/tamper_guard.dart';

import 'strict_mode.dart';

/// The system Settings app, plus the OEM apps that host some of its pages.
const settingsPackages = <String>{
  'com.android.settings',
  'com.samsung.android.settings',
  'com.samsung.accessibility',
  'com.miui.securitycenter',
  'com.coloros.safecenter',
  'com.oplus.safecenter',
  'com.oplus.securitypermission',
  'com.oplus.wirelesssettings',
};

/// Apps that show the uninstall confirmation.
const installerPackages = <String>{
  'com.android.packageinstaller',
  'com.google.android.packageinstaller',
  'com.samsung.android.packageinstaller',
  'com.miui.packageinstaller',
  'com.miui.global.packageinstaller',
  'com.oplus.packageinstaller',
};

/// The admin's label as Settings shows it on the deactivation screen. Keep
/// in sync with device_admin_label in android/app/src/main/res/values/strings.xml.
const deviceAdminLabel = 'SerenSync strict mode';

/// How long the service shields the screen after leaving it.
const adminGuardShield = Duration(milliseconds: 900);

/// The device-admin screen, sent home the instant it appears while uninstalls
/// are locked. Every manufacturer's version of it ends in `DeviceAdminAdd`
/// (stock, and Samsung's `SecDeviceAdminAdd`), and it disables ordinary
/// overlay windows, so the block screen cannot cover it where the service's
/// own shield can. The rest of Settings is left alone; the tap on Deactivate
/// itself is caught by the admin's deactivation action, which asks this app
/// first.
const adminGuardRules = <GuardRule>[
  GuardRule(
    packages: settingsPackages,
    classNameSuffixes: {'DeviceAdminAdd'},
    action: GuardAction.home,
    shield: adminGuardShield,
  ),
];

/// Packages an active strict mode blocks outright.
Set<String> guardedPackages(
  StrictMode strict, {
  required Map<String, DateTime> installTimes,
}) {
  return {
    if (strict.locks.contains(StrictLock.settings)) ...settingsPackages,
    if (strict.locks.contains(StrictLock.uninstall)) ...installerPackages,
    if (strict.locks.contains(StrictLock.newApps))
      for (final MapEntry(key: package, value: installedAt)
          in installTimes.entries)
        if (installedAt.isAfter(strict.activatedAt)) package,
  };
}

/// Launcher activities that draw the recents screen; a launcher that draws
/// recents inside its home activity cannot be told apart from home.
const recentsActivities = <String>{
  'com.android.quickstep.RecentsActivity',
  'com.miui.home.recents.RecentsActivity',
};

bool isRecentsScreen(String? className) {
  return recentsActivities.contains(className);
}

Future<Map<String, DateTime>> readInstallTimes() async {
  final apps = await AppsHandler.getInstalledApps(
    onlyAppsWithLaunchIntent: true,
    includeSystemApps: false,
  );
  return {
    for (final app in apps)
      app.packageName: DateTime.fromMillisecondsSinceEpoch(app.installTime),
  };
}
