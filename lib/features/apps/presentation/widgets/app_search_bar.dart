import 'package:flutter/material.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class AppSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  const AppSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final FocusNode _focusNode;
  late final ValueNotifier<bool> _isFocused;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _isFocused = ValueNotifier<bool>(false);
    _focusNode.addListener(() {
      _isFocused.value = _focusNode.hasFocus;
    });
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 25, 25, 25),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          _buildSearchIcon(),
          const SizedBox(width: 8),
          _buildTextField(),
          _buildClearButton(context),
        ],
      ),
    );
  }

  Widget _buildSearchIcon() {
    return ValueListenableBuilder(
      valueListenable: _isFocused,
      builder: (context, bool isFocused, _) {
        return IconButton(
          icon: Icon(
            isFocused ? Icons.arrow_back : Icons.search,
            color: Colors.white70,
          ),
          onPressed: () {
            if (isFocused) {
              _focusNode.unfocus();
              widget.controller.clear();
            } else {
              _focusNode.requestFocus();
            }
          },
        );
      },
    );
  }

  Widget _buildTextField() {
    return Expanded(
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          hintText: 'Search Apps',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white70),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _buildClearButton(BuildContext context) {
    return IconButton(
      icon: widget.controller.text.isEmpty
          ? const Icon(Icons.settings)
          : const Icon(Icons.clear),
      onPressed: () {
        if (widget.controller.text.isNotEmpty) {
          widget.controller.clear();
          widget.onChanged('');
        } else {
          _navigateToSettings(context);
        }
      },
    );
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _isFocused.dispose();
    super.dispose();
  }
}
