import 'package:apps_handler/apps_handler.dart';
import 'package:tamper_guard/tamper_guard.dart';

import 'strict_mode.dart';

/// The system Settings app, plus the OEM apps that host some of its pages.
const settingsPackages = <String>{
  'com.android.settings',
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

/// The one Settings screen that can deactivate a device admin, on Android 10
/// and later and on Android 9. It lives in the system Settings app on every
/// build seen so far.
const _settingsPackage = 'com.android.settings';
const _deviceAdminScreens = <String>{
  'com.android.settings.applications.specialaccess.deviceadmin.DeviceAdminAdd',
  'com.android.settings.DeviceAdminAdd',
};
const _shield = Duration(milliseconds: 700);

/// Sends the device-admin screen home and shields it from taps the instant
/// it appears, inside the accessibility service, while uninstalls are locked.
/// Home rather than Back: the screen is cleared from the task when Settings
/// is next opened, where Back would only return to the admin list. The
/// screen disables ordinary overlay windows, so the block screen cannot
/// cover it; the service's own shield can.
const adminGuardRules = <GuardRule>[
  // The row naming this app's admin comes first: it keeps acting through a
  // confirmation dialog and holds on builds that rename the screen.
  GuardRule(
    packages: {_settingsPackage},
    viewId: '$_settingsPackage:id/admin_name',
    text: deviceAdminLabel,
    action: GuardAction.home,
    shield: _shield,
  ),
  GuardRule(
    packages: {_settingsPackage},
    classNames: _deviceAdminScreens,
    action: GuardAction.home,
    shield: _shield,
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
