import 'package:flutter/material.dart';

class CatalogResultsSummary extends StatelessWidget {
  final String summary;
  final int count;
  final bool isLoading;
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const CatalogResultsSummary({
    super.key,
    required this.summary,
    required this.count,
    required this.isLoading,
    required this.hasFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final summaryText = isLoading && count == 0
        ? '$summary \u2022 \u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0645\u064a\u0644...'
        : '$summary \u2022 $count \u0645\u0646\u062a\u062c';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5EAF1)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                summaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5F6979),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (hasFilters)
              TextButton(
                onPressed: onClearFilters,
                child: const Text(
                  '\u0625\u0632\u0627\u0644\u0629 \u0627\u0644\u0641\u0644\u0627\u062a\u0631',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
