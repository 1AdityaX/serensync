import 'dart:async';

import 'package:flutter/material.dart';

import '../../../apps/app_service.dart';
import '../../../theme.dart';
import '../../common/cards.dart';
import '../../common/glyph_map.dart';
import '../../common/glyphs.dart';
import '../../common/illustrations.dart';
import '../blocking_colors.dart';
import '../blocking_engine.dart';
import '../rule.dart';
import '../rule_editor_screen.dart';
import '../rule_store.dart';

/// Ready-made starting points offered while there are no blocks yet.
typedef BlockIdea = ({
  String key,
  Glyphs glyph,
  String name,
  String label,
  String detail,
  Trigger trigger,
});

const _everyDay = {1, 2, 3, 4, 5, 6, 7};

const blockIdeas = <BlockIdea>[
  (
    key: 'evenings',
    glyph: Glyphs.moon,
    name: 'Calm evenings',
    label: 'Evenings',
    detail: '21:00–07:00',
    trigger: Schedule(
      weekdays: _everyDay,
      startMinute: 21 * 60,
      endMinute: 7 * 60,
    ),
  ),
  (
    key: 'workday',
    glyph: Glyphs.briefcase,
    name: 'Workday focus',
    label: 'Work',
    detail: 'Mon–Fri 9–5',
    trigger: Schedule(
      weekdays: {1, 2, 3, 4, 5},
      startMinute: 9 * 60,
      endMinute: 17 * 60,
    ),
  ),
  (
    key: 'hour',
    glyph: Glyphs.hourglass,
    name: 'An hour a day',
    label: '1 hour',
    detail: 'a day',
    trigger: UsageQuota(Duration(hours: 1)),
  ),
  (
    key: 'checkins',
    glyph: Glyphs.launch,
    name: 'Fewer check-ins',
    label: '5 opens',
    detail: 'a day',
    trigger: LaunchQuota(5),
  ),
];

class RuleList extends StatefulWidget {
  const RuleList({
    super.key,
    required this.ruleStore,
    required this.appService,
    required this.blockingService,
    this.locked = false,
  });

  final RuleStore ruleStore;
  final AppService appService;
  final BlockingService blockingService;

  /// While strict mode locks the rules, blocks can only be added or tightened.
  final bool locked;

  @override
  State<RuleList> createState() => _RuleListState();
}

class _RuleListState extends State<RuleList> {
  List<BlockRule>? _rules;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    if (_loadFailed) setState(() => _loadFailed = false);
    try {
      final rules = await widget.ruleStore.readAll();
      if (!mounted) return;
      setState(() => _rules = rules);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _openEditor({BlockRule? rule, BlockIdea? idea}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RuleEditorScreen(
          ruleStore: widget.ruleStore,
          appService: widget.appService,
          blockingService: widget.blockingService,
          locked: widget.locked,
          rule: rule,
          draftName: idea?.name,
          draftTrigger: idea?.trigger,
        ),
      ),
    );
    if (saved ?? false) await _loadRules();
  }

  Future<void> _toggle(BlockRule rule, bool enabled) async {
    final replacement = BlockRule(
      id: rule.id,
      name: rule.name,
      packages: rule.packages,
      websites: rule.websites,
      keywords: rule.keywords,
      trigger: rule.trigger,
      enabled: enabled,
    );
    await widget.ruleStore.update(replacement);
    await widget.blockingService.sync(widget.ruleStore);
    if (!mounted) return;
    setState(() {
      final rules = _rules;
      if (rules == null) return;
      _rules = [
        for (final candidate in rules)
          if (candidate.id == rule.id) replacement else candidate,
      ];
    });
  }

  Future<void> _duplicate(BlockRule rule) async {
    await widget.ruleStore.insert(
      BlockRule(
        id: 0,
        name: '${rule.name} (copy)',
        packages: rule.packages,
        websites: rule.websites,
        keywords: rule.keywords,
        trigger: rule.trigger,
        enabled: rule.enabled,
      ),
    );
    await widget.blockingService.sync(widget.ruleStore);
    await _loadRules();
  }

  Future<void> _delete(BlockRule rule) async {
    await widget.ruleStore.delete(rule.id);
    await widget.blockingService.sync(widget.ruleStore);
    if (!mounted) return;
    setState(() => _rules?.removeWhere((candidate) => candidate.id == rule.id));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('“${rule.name}” deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(_restore(rule)),
          ),
        ),
      );
  }

  Future<void> _restore(BlockRule rule) async {
    await widget.ruleStore.insert(rule);
    await widget.blockingService.sync(widget.ruleStore);
    await _loadRules();
  }

  Future<void> _act(BlockRule rule, _BlockAction action) {
    return switch (action) {
      _BlockAction.edit => _openEditor(rule: rule),
      _BlockAction.pause => _toggle(rule, false),
      _BlockAction.block => _toggle(rule, true),
      _BlockAction.duplicate => _duplicate(rule),
      _BlockAction.delete => _delete(rule),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed && _rules == null) {
      return Center(
        child: EmptyState(
          scene: Scene.phone,
          title: 'Couldn’t load blocks',
          action: TextButton(
            onPressed: _loadRules,
            child: const Text('Try again'),
          ),
        ),
      );
    }
    final rules = _rules;
    if (rules == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final active = [
      for (final rule in rules)
        if (rule.enabled) rule,
    ];
    final inactive = [
      for (final rule in rules)
        if (!rule.enabled) rule,
    ];

    Widget card(BlockRule rule) => _BlockCard(
      rule: rule,
      now: now,
      locked: widget.locked,
      onOpen: () => _openEditor(rule: rule),
      onToggle: (enabled) => unawaited(_toggle(rule, enabled)),
      onAction: (action) => _act(rule, action),
    );

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
          children: [
            if (widget.locked)
              Padding(
                key: const ValueKey('rules-locked'),
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                child: Row(
                  children: [
                    Glyph(Glyphs.lock, size: 18, color: BlockingColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Strict mode: tighten only',
                        style: TextStyle(color: BlockingColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            if (rules.isEmpty)
              _EmptyBlocks(onIdea: (idea) => _openEditor(idea: idea)),
            if (active.isNotEmpty) ...[
              const _SectionHeader('Active'),
              for (final rule in active) card(rule),
            ],
            if (inactive.isNotEmpty) ...[
              const _SectionHeader('Paused'),
              for (final rule in inactive) card(rule),
            ],
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            key: const ValueKey('create-block'),
            heroTag: null,
            tooltip: 'New block',
            onPressed: () => _openEditor(),
            child: const Glyph(Glyphs.plus, size: 26),
          ),
        ),
      ],
    );
  }
}

class _EmptyBlocks extends StatelessWidget {
  const _EmptyBlocks({required this.onIdea});

  final ValueChanged<BlockIdea> onIdea;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: EmptyState(scene: Scene.phone, title: 'No blocks yet'),
        ),
        const _SectionHeader('Start with'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            for (final idea in blockIdeas)
              SoftCard(
                key: ValueKey('block-idea-${idea.key}'),
                onTap: () => onIdea(idea),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlyphBadge(idea.glyph, size: 40),
                    const Spacer(),
                    Text(
                      idea.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      idea.detail,
                      style: TextStyle(
                        fontSize: 13,
                        color: BlockingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Text(title, style: sectionLabel),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.rule,
    required this.now,
    required this.locked,
    required this.onOpen,
    required this.onToggle,
    required this.onAction,
  });

  final BlockRule rule;
  final DateTime now;
  final bool locked;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final ValueChanged<_BlockAction> onAction;

  @override
  Widget build(BuildContext context) {
    // Strict mode only lets a block be switched on, never off.
    final canToggle = !rule.enabled || !locked;
    final muted = !rule.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
        child: Row(
          children: [
            GlyphBadge(
              triggerGlyph(rule.trigger),
              color: muted ? BlockingColors.textMuted : BlockingColors.text,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: muted
                          ? BlockingColors.textMuted
                          : BlockingColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: StatusPill(
                          label: ruleStatusShort(rule, now),
                          active: blockingNow(rule, now),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _Targets(rule),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              key: ValueKey('rule-switch-${rule.id}'),
              value: rule.enabled,
              onChanged: canToggle ? onToggle : null,
            ),
            _BlockMenu(rule: rule, locked: locked, onSelected: onAction),
          ],
        ),
      ),
    );
  }
}

/// What a block covers, as icon and count pairs.
class _Targets extends StatelessWidget {
  const _Targets(this.rule);

  final BlockRule rule;

  @override
  Widget build(BuildContext context) {
    final counts = [
      if (rule.packages.isNotEmpty) (Glyphs.apps, rule.packages.length),
      if (rule.websites.isNotEmpty) (Glyphs.globe, rule.websites.length),
      if (rule.keywords.isNotEmpty) (Glyphs.search, rule.keywords.length),
    ];
    return Semantics(
      label: _targetSummary(rule),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, (glyph, count)) in counts.indexed) ...[
            if (index > 0) const SizedBox(width: 10),
            Glyph(glyph, size: 15, color: BlockingColors.textMuted),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(fontSize: 13, color: BlockingColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

enum _BlockAction { edit, pause, block, duplicate, delete }

class _BlockMenu extends StatelessWidget {
  const _BlockMenu({
    required this.rule,
    required this.locked,
    required this.onSelected,
  });

  final BlockRule rule;
  final bool locked;
  final ValueChanged<_BlockAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BlockAction>(
      key: ValueKey('rule-menu-${rule.id}'),
      tooltip: 'More for ${rule.name}',
      icon: Glyph(Glyphs.more, size: 20, color: BlockingColors.textMuted),
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        _item(_BlockAction.edit, 'Edit'),
        if (!rule.enabled)
          _item(_BlockAction.block, 'Turn on')
        else if (!locked)
          _item(_BlockAction.pause, 'Pause'),
        _item(_BlockAction.duplicate, 'Duplicate'),
        if (!locked)
          _item(_BlockAction.delete, 'Delete', BlockingColors.danger),
      ],
    );
  }

  PopupMenuItem<_BlockAction> _item(
    _BlockAction action,
    String label, [
    Color? color,
  ]) {
    return PopupMenuItem(
      key: ValueKey('rule-${action.name}'),
      value: action,
      height: 48,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color ?? BlockingColors.text,
        ),
      ),
    );
  }
}

String _targetSummary(BlockRule rule) {
  final parts = <String>[
    if (rule.packages.isNotEmpty) _count(rule.packages.length, 'app', 'apps'),
    if (rule.websites.isNotEmpty) _count(rule.websites.length, 'site', 'sites'),
    if (rule.keywords.isNotEmpty)
      _count(rule.keywords.length, 'keyword', 'keywords'),
  ];
  return parts.join(' · ');
}

String _count(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}
