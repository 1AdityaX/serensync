import 'package:apps_handler/apps_handler.dart';
import 'package:flutter/material.dart';

import '../../apps/app_service.dart';

class AppPicker extends StatefulWidget {
  final AppService appService;
  final Set<String> selectedPackages;
  final ValueChanged<Set<String>> onChanged;

  const AppPicker({
    super.key,
    required this.appService,
    required this.selectedPackages,
    required this.onChanged,
  });

  @override
  State<AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<AppPicker> {
  late Future<List<AppInfo>> _appsLoad;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _appsLoad = widget.appService.getInstalledApps();
  }

  void _retry() {
    setState(() => _appsLoad = widget.appService.getInstalledApps());
  }

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
        Text('$count ${count == 1 ? 'app' : 'apps'} selected'),
        const SizedBox(height: 8),
        _searchField(),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<AppInfo>>(
            future: _appsLoad,
            builder: (context, snapshot) => _buildList(snapshot),
          ),
        ),
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

  Widget _buildList(AsyncSnapshot<List<AppInfo>> snapshot) {
    if (snapshot.hasError) {
      return Center(
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: _retry,
          child: const Text('Retry'),
        ),
      );
    }
    final installedApps = snapshot.data;
    if (installedApps == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final query = _query.trim().toLowerCase();
    final apps = query.isEmpty
        ? installedApps
        : [
            for (final app in installedApps)
              if (app.appName.toLowerCase().contains(query)) app,
          ];
    if (apps.isEmpty) {
      return const Center(child: Text('No apps found'));
    }
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) => _appTile(apps[index]),
    );
  }

  Widget _appTile(AppInfo app) {
    final selected = widget.selectedPackages.contains(app.packageName);
    return ListTile(
      key: ValueKey('app-${app.packageName}'),
      contentPadding: EdgeInsets.zero,
      title: Text(app.appName),
      trailing: selected ? const Icon(Icons.check, color: Colors.white) : null,
      onTap: () => _toggle(app.packageName, !selected),
    );
  }
}
