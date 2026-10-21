import '../blocking/onboarding/permission_status.dart';
import '../blocking/rule.dart';
import '../onboarding/plan.dart';
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

/// The glyph for each goal of the first block.
Glyphs goalGlyph(Goal goal) {
  return switch (goal) {
    Goal.scrolling => Glyphs.swipe,
    Goal.work => Glyphs.briefcase,
    Goal.nights => Glyphs.moon,
    Goal.pickups => Glyphs.launch,
  };
}
