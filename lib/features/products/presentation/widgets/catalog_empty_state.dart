import 'package:flutter/material.dart';

class CatalogEmptyState extends StatelessWidget {
  final bool isIdleSearch;
  final bool hasSearch;
  final bool hasFilters;
  final bool isScopedListing;
  final String? scopedEmptyMessage;
  final String? scopedNoResultsMessage;
  final VoidCallback onFocusSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;
  final VoidCallback onEditFilters;

  const CatalogEmptyState({
    super.key,
    required this.isIdleSearch,
    required this.hasSearch,
    required this.hasFilters,
    required this.isScopedListing,
    required this.onFocusSearch,
    required this.onClearSearch,
    required this.onClearFilters,
    required this.onEditFilters,
    this.scopedEmptyMessage,
    this.scopedNoResultsMessage,
  });

  IconData get _icon {
    if (isIdleSearch) {
      return Icons.manage_search_rounded;
    }
    if (isScopedListing && !hasSearch && !hasFilters) {
      return Icons.inventory_2_outlined;
    }
    return Icons.search_off_rounded;
  }

  String get _headline {
    if (isIdleSearch) {
      return '\u0627\u0643\u062a\u0628 \u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u062a\u062c \u0623\u0648 SKU \u0623\u0648 \u0628\u0627\u0631\u0643\u0648\u062f \u0644\u0628\u062f\u0621 \u0627\u0644\u0628\u062d\u062b';
    }
    if (hasSearch || hasFilters) {
      if (isScopedListing) {
        return scopedNoResultsMessage ??
            '\u0644\u0627 \u062a\u0648\u062c\u062f \u0646\u062a\u0627\u0626\u062c \u0645\u0637\u0627\u0628\u0642\u0629 \u062f\u0627\u062e\u0644 \u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645';
      }
      return '\u0644\u0627 \u062a\u0648\u062c\u062f \u0646\u062a\u0627\u0626\u062c \u0645\u0637\u0627\u0628\u0642\u0629';
    }
    if (isScopedListing) {
      return scopedEmptyMessage ??
          '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u062a\u0627\u062d\u0629 \u0641\u064a \u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645 \u062d\u0627\u0644\u064a\u0627\u064b';
    }
    return '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u062a\u0627\u062d\u0629 \u062d\u0627\u0644\u064a\u0627\u064b';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE5EAF1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(_icon, size: 72, color: const Color(0xFF9AA3B2)),
                        const SizedBox(height: 10),
                        Text(
                          _headline,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (isIdleSearch)
                          FilledButton.icon(
                            onPressed: onFocusSearch,
                            icon: const Icon(Icons.search_rounded),
                            label: const Text(
                              '\u0627\u0628\u062f\u0623 \u0627\u0644\u0628\u062d\u062b',
                            ),
                          ),
                        if (hasSearch)
                          FilledButton.icon(
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text(
                              '\u0645\u0633\u062d \u0627\u0644\u0628\u062d\u062b',
                            ),
                          ),
                        if (!hasSearch && hasFilters)
                          FilledButton.icon(
                            onPressed: onClearFilters,
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label: const Text(
                              '\u0625\u0632\u0627\u0644\u0629 \u0627\u0644\u0641\u0644\u0627\u062a\u0631',
                            ),
                          ),
                        if (hasFilters)
                          TextButton(
                            onPressed: onEditFilters,
                            child: const Text(
                              '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0641\u0644\u0627\u062a\u0631',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
