import 'package:flutter/material.dart';

class AppSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSettings;

  const AppSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
    required this.onOpenSettings,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  void _onFocusChanged() => setState(() {});

  void _clearSearch() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _focusNode.hasFocus ? Icons.arrow_back : Icons.search,
              color: Colors.white70,
            ),
            onPressed: () {
              if (_focusNode.hasFocus) {
                _focusNode.unfocus();
                _clearSearch();
              } else {
                _focusNode.requestFocus();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: 'Search Apps',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              icon: Icon(
                _controller.text.isEmpty ? Icons.settings : Icons.clear,
              ),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _clearSearch();
                } else {
                  _focusNode.unfocus();
                  widget.onOpenSettings();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }
}
