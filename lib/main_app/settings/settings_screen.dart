import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../blocking/blocking_colors.dart';
import '../blocking/onboarding/permission_status.dart';
import '../common/cards.dart';
import '../common/glyph_map.dart';
import '../common/glyphs.dart';
import 'appearance.dart';

Future<void> _openHomeSettings() {
  return const AndroidIntent(
    action: 'android.settings.HOME_SETTINGS',
    flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
  ).launch();
}

/// Light or dark, permissions skipped during setup, and making SerenSync the
/// home screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.permissionStatus,
    required this.appearance,
    this.onOpenHomeSettings = _openHomeSettings,
  });

  final PermissionStatus permissionStatus;
  final AppearanceController appearance;
  final Future<void> Function() onOpenHomeSettings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionState? _permissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final permissions = await widget.permissionStatus.check();
    if (mounted) setState(() => _permissions = permissions);
  }

  Future<void> _allow(RequiredPermission permission) async {
    await widget.permissionStatus.request(permission);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        children: [
          Text('Appearance', style: sectionLabel),
          const SizedBox(height: 12),
          ValueListenableBuilder<Appearance>(
            valueListenable: widget.appearance,
            builder: (context, current, _) => Row(
              children: [
                for (final (index, (option, glyph, label)) in const [
                  (Appearance.system, Glyphs.contrast, 'Auto'),
                  (Appearance.light, Glyphs.sun, 'Light'),
                  (Appearance.dark, Glyphs.moon, 'Dark'),
                ].indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _AppearanceChoice(
                      key: ValueKey('appearance-${option.name}'),
                      glyph: glyph,
                      label: label,
                      selected: current == option,
                      onTap: () => unawaited(widget.appearance.choose(option)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Permissions', style: sectionLabel),
          const SizedBox(height: 8),
          for (final permission in RequiredPermission.values)
            _PermissionRow(
              permission: permission,
              granted: permissions?.granted(permission),
              onAllow: () => unawaited(_allow(permission)),
            ),
          const SizedBox(height: 28),
          Text('Launcher', style: sectionLabel),
          const SizedBox(height: 8),
          InkWell(
            key: const ValueKey('settings-home-app'),
            onTap: () => unawaited(widget.onOpenHomeSettings()),
            borderRadius: BorderRadius.circular(16),
            child: _Row(
              glyph: Glyphs.home,
              title: 'Minimal home screen',
              detail: 'Set as home app',
              trailing: Glyph(
                Glyphs.chevronRight,
                size: 20,
                color: BlockingColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _Row(
            glyph: Glyphs.lock,
            title: 'Private',
            detail: 'Nothing leaves this phone',
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.granted,
    required this.onAllow,
  });

  final RequiredPermission permission;
  final bool? granted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return _Row(
      glyph: permissionGlyph(permission),
      title: permissionTitle(permission),
      detail: _purpose(permission),
      trailing: switch (granted) {
        null => const SizedBox(width: 48),
        true => GlyphBadge(
          Glyphs.check,
          size: 30,
          color: BlockingColors.onAccent,
          background: BlockingColors.accent,
        ),
        false => TextButton(
          key: ValueKey('settings-allow-${permission.name}'),
          onPressed: onAllow,
          child: const Text('Allow'),
        ),
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.glyph,
    required this.title,
    required this.detail,
    this.trailing,
  });

  final Glyphs glyph;
  final String title;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GlyphBadge(glyph, background: BlockingColors.surface),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: BlockingColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}

String _purpose(RequiredPermission permission) {
  return switch (permission) {
    RequiredPermission.usageAccess => 'See app time',
    RequiredPermission.overlay => 'Show the pause screen',
    RequiredPermission.notifications => 'Run in the background',
    RequiredPermission.batteryOptimisation => 'Stay switched on',
    RequiredPermission.accessibility => 'Websites and strict mode',
  };
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    super.key,
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Glyphs glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? BlockingColors.background : BlockingColors.text;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: SoftCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: selected ? BlockingColors.text : BlockingColors.surface,
        child: Column(
          children: [
            Glyph(glyph, size: 24, color: ink),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
