import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

import '../blocking_engine.dart';

enum RequiredPermission {
  usageAccess,
  overlay,
  notifications,
  batteryOptimisation,
}

class PermissionState {
  const PermissionState({
    required this.usageAccess,
    required this.overlay,
    required this.notifications,
    required this.batteryOptimisation,
  });

  final bool usageAccess;
  final bool overlay;
  final bool notifications;
  final bool batteryOptimisation;

  bool get allGranted =>
      usageAccess && overlay && notifications && batteryOptimisation;

  bool granted(RequiredPermission permission) {
    return switch (permission) {
      RequiredPermission.usageAccess => usageAccess,
      RequiredPermission.overlay => overlay,
      RequiredPermission.notifications => notifications,
      RequiredPermission.batteryOptimisation => batteryOptimisation,
    };
  }
}

class PermissionStatus {
  Future<PermissionState> check() async {
    final usageAccess = await UsageStats.checkUsagePermission() ?? false;
    final overlay = await FlutterForegroundTask.canDrawOverlays;
    final notifications =
        await FlutterForegroundTask.checkNotificationPermission() ==
        NotificationPermission.granted;
    final batteryOptimisation =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    return PermissionState(
      usageAccess: usageAccess,
      overlay: overlay,
      notifications: notifications,
      batteryOptimisation: batteryOptimisation,
    );
  }

  Future<void> request(RequiredPermission permission) async {
    switch (permission) {
      case RequiredPermission.usageAccess:
        await UsageStats.grantUsagePermission();
      case RequiredPermission.overlay:
        await const AndroidIntent(
          action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
          data: 'package:$applicationId',
        ).launch();
      case RequiredPermission.notifications:
        await _requestNotifications();
      case RequiredPermission.batteryOptimisation:
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  Future<void> _requestNotifications() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.permanently_denied) {
      await const AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: <String, String>{
          'android.provider.extra.APP_PACKAGE': applicationId,
        },
      ).launch();
      return;
    }
    await FlutterForegroundTask.requestNotificationPermission();
  }
}
