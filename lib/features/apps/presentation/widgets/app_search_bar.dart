import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../providers/app_provider.dart';

class AppSearchBar extends ConsumerStatefulWidget {
  const AppSearchBar({super.key});

  @override
  ConsumerState<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends ConsumerState<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ValueNotifier<bool> _isFocused = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() => _isFocused.value = _focusNode.hasFocus);
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(AppRouter.settings());
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Sync controller when the search query is cleared externally (e.g. on app tap).
    ref.listen<String>(searchQueryProvider, (_, next) {
      if (next.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
        _focusNode.unfocus();
      }
    });

    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          _buildSearchIcon(),
          const SizedBox(width: 8),
          _buildTextField(),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildSearchIcon() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, _) => IconButton(
        icon: Icon(
          isFocused ? Icons.arrow_back : Icons.search,
          color: Colors.white70,
        ),
        onPressed: () {
          if (isFocused) {
            _focusNode.unfocus();
            _controller.clear();
            ref.read(searchQueryProvider.notifier).clear();
          } else {
            _focusNode.requestFocus();
          }
        },
      ),
    );
  }

  Widget _buildTextField() {
    return Expanded(
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          hintText: 'Search Apps',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white70),
        ),
        onChanged: (value) => ref.read(searchQueryProvider.notifier).update(value),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => IconButton(
        icon: _controller.text.isEmpty
            ? const Icon(Icons.settings)
            : const Icon(Icons.clear),
        onPressed: () {
          if (_controller.text.isNotEmpty) {
            _controller.clear();
            ref.read(searchQueryProvider.notifier).clear();
          } else {
            _navigateToSettings(context);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _isFocused.dispose();
    super.dispose();
  }
}
