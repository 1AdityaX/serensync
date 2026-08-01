import 'package:flutter/material.dart';

import '../../apps/installed_app.dart';

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
        Row(
          children: [
            const Text('Apps'),
            const Spacer(),
            Text(count == 0 ? 'None selected' : '$count selected'),
          ],
        ),
        const SizedBox(height: 8),
        _searchField(),
        const SizedBox(height: 8),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('app-picker-search'),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'Search apps',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
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
    return ListTile(
      key: ValueKey('app-${app.packageName}'),
      contentPadding: EdgeInsets.zero,
      title: Text(app.displayName),
      trailing: selected ? const Icon(Icons.check, color: Colors.white) : null,
      onTap: () => _toggle(app.packageName, !selected),
    );
  }
}
