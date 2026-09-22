import 'package:tamper_guard/tamper_guard.dart';

/// SerenSync as an Android device administrator. While the admin is active,
/// Android refuses to uninstall the app, so the uninstall lock turns it on.
class UninstallGuard {
  /// Opens Android's device-admin prompt. It needs the app's activity, so
  /// only the UI may call it.
  Future<bool> activate() async {
    await TamperGuard.setDeviceAdminDisableWarning(
      'Strict mode is on. SerenSync keeps this until it ends.',
    );
    return TamperGuard.requestDeviceAdmin(
      explanation: 'Keeps SerenSync installed while strict mode is on.',
    );
  }

  /// Ends the admin and the rules that guarded it; the blocking service may
  /// already be gone by now, so they are cleared here.
  Future<void> deactivate() async {
    await TamperGuard.setRules(const []);
    await TamperGuard.setDeviceAdminDisableWarning(null);
    await TamperGuard.removeDeviceAdmin();
  }
}
