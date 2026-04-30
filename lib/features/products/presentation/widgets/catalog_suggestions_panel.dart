import 'package:flutter/material.dart';

enum CatalogSuggestionType { recent, product, sku, barcode, category, brand }

class CatalogSuggestionItem {
  final CatalogSuggestionType type;
  final String key;
  final String title;
  final String? subtitle;
  final IconData icon;
  final int? categoryId;
  final String? brandSlug;

  const CatalogSuggestionItem({
    required this.type,
    required this.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.categoryId,
    this.brandSlug,
  });
}

class CatalogSuggestionsPanel extends StatelessWidget {
  final List<CatalogSuggestionItem> suggestions;
  final double maxPanelHeight;
  final ValueChanged<CatalogSuggestionItem> onTap;

  const CatalogSuggestionsPanel({
    super.key,
    required this.suggestions,
    required this.maxPanelHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF1)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120B1524),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
        child: ListView.separated(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                12,
                2,
                10,
                2,
              ),
              leading: Icon(
                suggestion.icon,
                size: 18,
                color: const Color(0xFF687182),
              ),
              title: Text(
                suggestion.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: suggestion.subtitle == null
                  ? null
                  : Text(
                      suggestion.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onTap(suggestion),
            );
          },
        ),
      ),
    );
  }
}
