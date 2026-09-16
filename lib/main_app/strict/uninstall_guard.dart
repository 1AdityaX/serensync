import 'package:device_policy_manager/device_policy_manager.dart';

/// SerenSync as an Android device administrator. While the admin is active,
/// Android refuses to uninstall the app, so the uninstall lock turns it on.
class UninstallGuard {
  /// Opens Android's device-admin prompt. It needs the app's activity, so
  /// only the UI may call it.
  Future<bool> activate() {
    return DevicePolicyManager.requestPermession(
      'Keeps SerenSync installed while strict mode is on.',
    );
  }

  /// The plugin never answers the remove call, so it is fired and the admin
  /// state polled instead.
  Future<void> deactivate() async {
    if (!await DevicePolicyManager.isPermissionGranted()) return;
    DevicePolicyManager.removeActiveAdmin().ignore();
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await DevicePolicyManager.isPermissionGranted()) return;
    }
  }
}
