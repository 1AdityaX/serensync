import 'package:tamper_guard/tamper_guard.dart';

import 'strict_guard.dart';

/// SerenSync as an Android device administrator. While the admin is active,
/// Android refuses to uninstall the app, so the uninstall lock turns it on.
class UninstallGuard {
  /// Opens Android's device-admin prompt. It needs the app's activity, so
  /// only the UI may call it. Tapping Deactivate for the admin later asks
  /// this app first; the service then goes Home and shields the screen, and
  /// the confirmation the warning adds is never answered.
  Future<bool> activate() async {
    await TamperGuard.setDeviceAdminDisableWarning(
      'Strict mode is on. SerenSync keeps this until it ends.',
    );
    await TamperGuard.setDeviceAdminDisableAction(
      GuardAction.home,
      shield: adminGuardShield,
    );
    return TamperGuard.requestDeviceAdmin(
      explanation: 'Keeps SerenSync installed while strict mode is on.',
    );
  }

  /// Ends the admin and everything that guarded it; the blocking service may
  /// already be gone by now, so they are cleared here.
  Future<void> deactivate() async {
    await TamperGuard.setRules(const []);
    await TamperGuard.setDeviceAdminDisableAction(GuardAction.none);
    await TamperGuard.setDeviceAdminDisableWarning(null);
    await TamperGuard.removeDeviceAdmin();
  }
}
