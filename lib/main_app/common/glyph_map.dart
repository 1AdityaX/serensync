import '../blocking/onboarding/permission_status.dart';
import '../blocking/rule.dart';
import 'glyphs.dart';

/// The glyph that stands for each permission.
Glyphs permissionGlyph(RequiredPermission permission) {
  return switch (permission) {
    RequiredPermission.usageAccess => Glyphs.insights,
    RequiredPermission.overlay => Glyphs.layers,
    RequiredPermission.notifications => Glyphs.bell,
    RequiredPermission.batteryOptimisation => Glyphs.battery,
    RequiredPermission.accessibility => Glyphs.globe,
  };
}

/// The glyph for each kind of block.
Glyphs triggerGlyph(Trigger trigger) {
  return switch (trigger) {
    Schedule() => Glyphs.clock,
    UsageQuota() => Glyphs.hourglass,
    LaunchQuota() => Glyphs.launch,
  };
}
