import 'package:flutter/material.dart';

class GlobalCatalogSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String hintText;
  final EdgeInsetsGeometry padding;

  const GlobalCatalogSearchBar({
    super.key,
    required this.onSearch,
    this.hintText =
        '\u0627\u0628\u062d\u062b \u0639\u0646 \u0645\u0646\u062a\u062c \u0623\u0648 SKU \u0623\u0648 \u0628\u0627\u0631\u0643\u0648\u062f...',
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 0),
  });

  @override
  State<GlobalCatalogSearchBar> createState() => _GlobalCatalogSearchBarState();
}

class _GlobalCatalogSearchBarState extends State<GlobalCatalogSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => widget.onSearch(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: '\u0628\u062d\u062b',
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
