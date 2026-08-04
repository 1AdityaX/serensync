import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../apps/app_service.dart';
import '../../blocking/blocking_colors.dart';
import '../../blocking/rule.dart';
import '../usage_report.dart';

const _collapsedCount = 6;

class AppUsageList extends StatefulWidget {
  const AppUsageList({
    super.key,
    required this.apps,
    required this.names,
    required this.appService,
  });

  final List<AppTotal> apps;
  final Map<String, String> names;
  final AppService appService;

  @override
  State<AppUsageList> createState() => _AppUsageListState();
}

class _AppUsageListState extends State<AppUsageList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final peak = widget.apps.first.time;
    final visible = _expanded
        ? widget.apps
        : widget.apps.take(_collapsedCount).toList();
    return Column(
      children: [
        for (final app in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _AppRow(
              app: app,
              name: widget.names[app.packageName] ?? _fallbackName(app),
              share: peak > Duration.zero
                  ? app.time.inSeconds / peak.inSeconds
                  : 0,
              appService: widget.appService,
            ),
          ),
        if (widget.apps.length > _collapsedCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: BlockingColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                _expanded ? 'Show less' : 'Show all ${widget.apps.length} apps',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _fallbackName(AppTotal app) {
  final segments = app.packageName.split('.');
  final last = segments.isEmpty ? app.packageName : segments.last;
  return last.isEmpty
      ? app.packageName
      : last[0].toUpperCase() + last.substring(1);
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.name,
    required this.share,
    required this.appService,
  });

  final AppTotal app;
  final String name;
  final double share;
  final AppService appService;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AppIcon(
          packageName: app.packageName,
          name: name,
          appService: appService,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                color: BlockingColors.accent,
                backgroundColor: BlockingColors.surfaceRaised,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              ruleDuration(app.time),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${app.opens} ${app.opens == 1 ? 'open' : 'opens'}',
              style: const TextStyle(
                fontSize: 10.5,
                color: BlockingColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppIcon extends StatefulWidget {
  const _AppIcon({
    required this.packageName,
    required this.name,
    required this.appService,
  });

  final String packageName;
  final String name;
  final AppService appService;

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  Uint8List? _icon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final icon = await widget.appService.readIcon(widget.packageName);
      if (mounted) setState(() => _icon = icon);
    } catch (_) {
      // An app uninstalled mid-session keeps its letter tile.
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BlockingColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: icon == null
          ? Text(
              widget.name.isEmpty ? '?' : widget.name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            )
          : Padding(
              padding: const EdgeInsets.all(5),
              child: Image.memory(icon, filterQuality: FilterQuality.medium),
            ),
    );
  }
}
