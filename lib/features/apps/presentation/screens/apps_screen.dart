import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apps_handler/apps_handler.dart';
import '../../../../core/providers/app_provider.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/app_options_dialog.dart';

class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppSearchBar(
          controller: _controller,
          onChanged: (value) => setState(() {}),
          focusNode: _focusNode,
        ),
      ),
      body: _buildAppsList(),
    );
  }

  Widget _buildAppsList() {
    final appsAsyncValue = ref.watch(appsProvider);

    return appsAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading apps')),
      data: (apps) {
        final filteredApps = apps
            .where((app) => app.appName
                .toLowerCase()
                .contains(_controller.text.toLowerCase()))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.only(left: 35),
          itemCount: filteredApps.length,
          itemBuilder: (context, index) {
            final app = filteredApps[index];
            return ListTile(
              contentPadding: const EdgeInsets.all(0),
              title: Text(app.appName),
              onTap: () {
                AppsHandler.openApp(app.packageName);
                setState(() {
                  _controller.clear();
                  _focusNode.unfocus();
                });
              },
              onLongPress: () => _showAppOptions(app),
            );
          },
        );
      },
    );
  }

  Future<void> _showAppOptions(AppInfo app) async {
    return showDialog(
      context: context,
      builder: (context) => AppOptionsDialog(app: app),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
