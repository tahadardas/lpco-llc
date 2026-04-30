import 'package:flutter/material.dart';



class CatalogSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final double topPadding;
  final int activeFilters;
  final String hintText;
  final bool showBarcodeAction;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenBarcodeScanner;
  final VoidCallback onOpenFilter;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const CatalogSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.topPadding,
    required this.activeFilters,
    required this.onClearSearch,
    required this.onOpenBarcodeScanner,
    required this.onOpenFilter,
    required this.onChanged,
    required this.onSubmitted,
    this.hintText =
        '\u0627\u0628\u062d\u062b \u0628\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u062a\u062c \u0623\u0648 SKU \u0623\u0648 \u0628\u0627\u0631\u0643\u0648\u062f',
    this.showBarcodeAction = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearchText = controller.text.trim().isNotEmpty;
    final showTrailingActions = hasSearchText || showBarcodeAction;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, topPadding, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIconConstraints: showTrailingActions
                  ? BoxConstraints(
                      minWidth: showBarcodeAction && hasSearchText ? 92 : 48,
                    )
                  : null,
              suffixIcon: showTrailingActions
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (hasSearchText)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClearSearch,
                            tooltip:
                                '\u0645\u0633\u062d \u0627\u0644\u0628\u062d\u062b',
                          ),
                        if (showBarcodeAction)
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: onOpenBarcodeScanner,
                            tooltip:
                                '\u0645\u0633\u062d \u0628\u0627\u0631\u0643\u0648\u062f',
                          ),
                      ],
                    )
                  : null,
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenFilter,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    activeFilters > 0
                        ? '\u0627\u0644\u0641\u0644\u0627\u062a\u0631 ($activeFilters)'
                        : '\u0627\u0644\u0641\u0644\u0627\u062a\u0631',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
