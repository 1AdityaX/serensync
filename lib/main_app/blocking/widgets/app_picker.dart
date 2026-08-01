import 'package:flutter/material.dart';

import '../../../apps/installed_app.dart';
import '../blocking_colors.dart';

class AppPickerScreen extends StatefulWidget {
  final List<InstalledApp> apps;
  final Set<String> selectedPackages;

  const AppPickerScreen({
    super.key,
    required this.apps,
    required this.selectedPackages,
  });

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  late Set<String> _selectedPackages;

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set<String>.of(widget.selectedPackages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlockingColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: BlockingColors.background,
        title: const Text('Choose apps'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: AppPicker(
          apps: widget.apps,
          selectedPackages: _selectedPackages,
          onChanged: (packages) => setState(() => _selectedPackages = packages),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: BlockingColors.background,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
            key: const ValueKey('app-picker-done'),
            onPressed: () => Navigator.of(context).pop(_selectedPackages),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: BlockingColors.accent,
              foregroundColor: BlockingColors.onAccent,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              _selectedPackages.isEmpty
                  ? 'Done'
                  : 'Done · ${_selectedPackages.length}',
            ),
          ),
        ),
      ),
    );
  }
}

class AppPicker extends StatefulWidget {
  final List<InstalledApp> apps;
  final Set<String> selectedPackages;
  final ValueChanged<Set<String>> onChanged;

  const AppPicker({
    super.key,
    required this.apps,
    required this.selectedPackages,
    required this.onChanged,
  });

  @override
  State<AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<AppPicker> {
  String _query = '';

  void _toggle(String package, bool selected) {
    final packages = Set<String>.of(widget.selectedPackages);
    if (selected) {
      packages.add(package);
    } else {
      packages.remove(package);
    }
    widget.onChanged(packages);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.selectedPackages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchField(),
        const SizedBox(height: 10),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              '$count ${count == 1 ? 'app' : 'apps'} will be blocked',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: BlockingColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('app-picker-search'),
              cursorColor: BlockingColors.accent,
              decoration: const InputDecoration(
                hintText: 'Search apps',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: (query) => setState(() => _query = query),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final query = _query.trim().toLowerCase();
    final apps = query.isEmpty
        ? widget.apps
        : [
            for (final app in widget.apps)
              if (app.displayName.toLowerCase().contains(query)) app,
          ];
    if (apps.isEmpty) {
      return const Center(child: Text('No apps match that search.'));
    }
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) => _appTile(apps[index]),
    );
  }

  Widget _appTile(InstalledApp app) {
    final selected = widget.selectedPackages.contains(app.packageName);
    return Material(
      color: selected
          ? BlockingColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      animationDuration: const Duration(milliseconds: 160),
      child: ListTile(
        key: ValueKey('app-${app.packageName}'),
        minTileHeight: 54,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BlockingColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            app.displayName.isEmpty ? '?' : app.displayName[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          app.displayName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected ? BlockingColors.accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? BlockingColors.accent : BlockingColors.outline,
            ),
          ),
          child: selected
              ? const Icon(
                  Icons.check,
                  size: 16,
                  color: BlockingColors.onAccent,
                )
              : null,
        ),
        onTap: () => _toggle(app.packageName, !selected),
      ),
    );
  }
}
