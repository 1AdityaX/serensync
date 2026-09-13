import 'package:flutter/material.dart';

import '../blocking_colors.dart';

/// Edits the websites or keywords of a rule. Each entry goes through
/// [normalize] before it is kept; a null result is shown as invalid.
class WebTargetPicker extends StatefulWidget {
  final String title;
  final String hint;
  final String invalidMessage;
  final Set<String> values;
  final String? Function(String input) normalize;

  const WebTargetPicker({
    super.key,
    required this.title,
    required this.hint,
    required this.invalidMessage,
    required this.values,
    required this.normalize,
  });

  @override
  State<WebTargetPicker> createState() => _WebTargetPickerState();
}

class _WebTargetPickerState extends State<WebTargetPicker> {
  final TextEditingController _controller = TextEditingController();
  late final Set<String> _values = Set<String>.of(widget.values);
  bool _invalid = false;

  void _add() {
    final value = widget.normalize(_controller.text);
    setState(() {
      _invalid = value == null;
      if (value != null) {
        _values.add(value);
        _controller.clear();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlockingColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: BlockingColors.background,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputField(),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  widget.invalidMessage,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _values.isEmpty
                  ? const Center(
                      child: Text(
                        'Nothing added yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final value in _values) _valueTile(value),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: BlockingColors.background,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
            key: const ValueKey('web-target-done'),
            onPressed: () => Navigator.of(context).pop(_values),
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
            child: Text(_values.isEmpty ? 'Done' : 'Done · ${_values.length}'),
          ),
        ),
      ),
    );
  }

  Widget _inputField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: BlockingColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlockingColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('web-target-input'),
              controller: _controller,
              cursorColor: BlockingColors.accent,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.white38),
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          IconButton(
            key: const ValueKey('web-target-add'),
            tooltip: 'Add',
            color: BlockingColors.accent,
            onPressed: _add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _valueTile(String value) {
    return ListTile(
      key: ValueKey('web-target-$value'),
      minTileHeight: 54,
      contentPadding: const EdgeInsets.only(left: 10),
      title: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: IconButton(
        key: ValueKey('remove-web-target-$value'),
        tooltip: 'Remove $value',
        icon: const Icon(Icons.close, color: Colors.white54),
        onPressed: () => setState(() => _values.remove(value)),
      ),
    );
  }
}
