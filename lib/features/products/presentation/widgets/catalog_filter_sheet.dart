import 'package:flutter/material.dart';

import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';
import 'package:lpco_llc/features/products/presentation/cubit/search_filter_cubit.dart';

class CatalogFilterDraft {
  final num minPrice;
  final bool clearMinPrice;
  final num maxPrice;
  final bool clearMaxPrice;
  final List<int> categoryIds;
  final AttributeTermFilter? attributeFilter;
  final String stockStatus;
  final ProductSortOption sortOption;

  const CatalogFilterDraft({
    required this.minPrice,
    required this.clearMinPrice,
    required this.maxPrice,
    required this.clearMaxPrice,
    required this.categoryIds,
    required this.attributeFilter,
    required this.stockStatus,
    required this.sortOption,
  });
}

Future<CatalogFilterDraft?> showCatalogFilterBottomSheet({
  required BuildContext context,
  required SearchFilterState state,
  bool hideCategorySection = false,
  int? lockedCategoryId,
  String? lockedCategoryName,
}) async {
  final prices =
      state.products
          .map((product) => product.basePrice.toDouble())
          .where((price) => price > 0)
          .toList()
        ..sort();

  final minBound = prices.isEmpty ? 0.0 : prices.first.floorToDouble();
  final maxBound = prices.isEmpty
      ? 5000.0
      : (prices.last == prices.first ? prices.last + 100 : prices.last)
            .ceilToDouble();

  return showModalBottomSheet<CatalogFilterDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CatalogFilterSheet(
      state: state,
      minBound: minBound,
      maxBound: maxBound,
      hideCategorySection: hideCategorySection,
      lockedCategoryId: lockedCategoryId,
      lockedCategoryName: lockedCategoryName,
    ),
  );
}

class _CatalogFilterSheet extends StatefulWidget {
  final SearchFilterState state;
  final double minBound;
  final double maxBound;
  final bool hideCategorySection;
  final int? lockedCategoryId;
  final String? lockedCategoryName;

  const _CatalogFilterSheet({
    required this.state,
    required this.minBound,
    required this.maxBound,
    required this.hideCategorySection,
    this.lockedCategoryId,
    this.lockedCategoryName,
  });

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late double _localMin;
  late double _localMax;
  int? _localCategory;
  AttributeTermFilter? _localAttr;
  late String _localStockStatus;
  late ProductSortOption _localSort;

  @override
  void initState() {
    super.initState();

    _localMin = (widget.state.query.minPrice ?? widget.minBound)
        .toDouble()
        .clamp(widget.minBound, widget.maxBound);
    _localMax = (widget.state.query.maxPrice ?? widget.maxBound)
        .toDouble()
        .clamp(widget.minBound, widget.maxBound);

    if (_localMin > _localMax) {
      final temp = _localMin;
      _localMin = _localMax;
      _localMax = temp;
    }

    _localCategory = widget.hideCategorySection
        ? null
        : widget.lockedCategoryId ??
              (widget.state.query.categoryIds.isNotEmpty
                  ? widget.state.query.categoryIds.first
                  : null);
    _localAttr = widget.state.query.attributeFilter;
    _localStockStatus = widget.state.query.stockStatus.trim().toLowerCase();
    if (_localStockStatus.isEmpty) {
      _localStockStatus = 'any';
    }
    _localSort = widget.state.query.sortOption;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: FrostedGlassPanel(
          radius: 28,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          '\u0646\u0637\u0627\u0642 \u0627\u0644\u0633\u0639\u0631',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\u0645\u0646 ${_localMin.toStringAsFixed(0)} \u0625\u0644\u0649 ${_localMax.toStringAsFixed(0)}',
                        ),
                        RangeSlider(
                          values: RangeValues(_localMin, _localMax),
                          min: widget.minBound,
                          max: widget.maxBound,
                          onChanged: (range) {
                            setState(() {
                              _localMin = range.start;
                              _localMax = range.end;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (widget.hideCategorySection)
                          ...[]
                        else if (widget.lockedCategoryId == null) ...[
                          _sectionTitle(
                            '\u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.state.categories.map((category) {
                              final selected = _localCategory == category.id;
                              return ChoiceChip(
                                label: Text(category.name),
                                selected: selected,
                                showCheckmark: false,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.70,
                                ),
                                selectedColor: Colors.white.withValues(
                                  alpha: 0.95,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? GlassStyle.fireRed
                                      : const Color(0xFFE1E6EE),
                                ),
                                onSelected: (value) {
                                  setState(() {
                                    _localCategory = value ? category.id : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          _sectionTitle(
                            '\u0627\u0644\u0642\u0633\u0645 \u0627\u0644\u062d\u0627\u0644\u064a',
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: InputChip(
                              label: Text(
                                (widget.lockedCategoryName ?? '').trim().isEmpty
                                    ? '\u0627\u0644\u0642\u0633\u0645 \u0627\u0644\u062d\u0627\u0644\u064a'
                                    : widget.lockedCategoryName!,
                              ),
                              onPressed: null,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _sectionTitle(
                          '\u0627\u0644\u0644\u0648\u0646 / \u0627\u0644\u0645\u0642\u0627\u0633',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...widget.state.colorOptions.map((option) {
                              final selected =
                                  _localAttr?.attribute == option.attribute &&
                                  _localAttr?.attributeTerm == option.term;
                              return _filterChip(
                                label: option.label,
                                selected: selected,
                                color: _parseColor(option.colorHex),
                                onTap: () {
                                  setState(() {
                                    _localAttr = selected
                                        ? null
                                        : AttributeTermFilter(
                                            attribute: option.attribute,
                                            attributeTerm: option.term,
                                          );
                                  });
                                },
                              );
                            }),
                            ...widget.state.sizeOptions.map((option) {
                              final selected =
                                  _localAttr?.attribute == option.attribute &&
                                  _localAttr?.attributeTerm == option.term;
                              return ChoiceChip(
                                label: Text(option.label),
                                selected: selected,
                                showCheckmark: false,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.70,
                                ),
                                selectedColor: Colors.white.withValues(
                                  alpha: 0.95,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? GlassStyle.fireRed
                                      : const Color(0xFFE1E6EE),
                                ),
                                onSelected: (value) {
                                  setState(() {
                                    _localAttr = value
                                        ? AttributeTermFilter(
                                            attribute: option.attribute,
                                            attributeTerm: option.term,
                                          )
                                        : null;
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _sectionTitle('\u0627\u0644\u062a\u0648\u0641\u0631'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              const <(String, String)>[
                                    ('any', '\u0627\u0644\u0643\u0644'),
                                    (
                                      'instock',
                                      '\u0645\u062a\u0648\u0641\u0631',
                                    ),
                                    (
                                      'outofstock',
                                      '\u063a\u064a\u0631 \u0645\u062a\u0648\u0641\u0631',
                                    ),
                                  ]
                                  .map((option) {
                                    final value = option.$1;
                                    final label = option.$2;
                                    final selected = _localStockStatus == value;
                                    return ChoiceChip(
                                      label: Text(label),
                                      selected: selected,
                                      showCheckmark: false,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.70,
                                      ),
                                      selectedColor: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? GlassStyle.fireRed
                                            : const Color(0xFFE1E6EE),
                                      ),
                                      onSelected: (_) {
                                        setState(
                                          () => _localStockStatus = value,
                                        );
                                      },
                                    );
                                  })
                                  .toList(growable: false),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          child: const Text(
                            '\u0625\u0639\u0627\u062f\u0629 \u0636\u0628\u0637',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _applyAndClose,
                          child: const Text(
                            '\u062a\u0637\u0628\u064a\u0642 \u0627\u0644\u0641\u0644\u0627\u062a\u0631',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _localMin = widget.minBound;
      _localMax = widget.maxBound;
      _localCategory = widget.hideCategorySection
          ? null
          : widget.lockedCategoryId;
      _localAttr = null;
      _localStockStatus = 'any';
      _localSort = ProductSortOption.defaultOrder;
    });
  }

  void _applyAndClose() {
    Navigator.of(context).pop(
      CatalogFilterDraft(
        minPrice: _localMin,
        clearMinPrice: (_localMin - widget.minBound).abs() < 0.01,
        maxPrice: _localMax,
        clearMaxPrice: (_localMax - widget.maxBound).abs() < 0.01,
        categoryIds: _localCategory == null
            ? const <int>[]
            : <int>[_localCategory!],
        attributeFilter: _localAttr,
        stockStatus: _localStockStatus,
        sortOption: _localSort,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            GlassStyle.acrylicDecoration(
              radius: 20,
              color: selected
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.72),
            ).copyWith(
              border: Border.all(
                color: selected ? GlassStyle.fireRed : const Color(0xFFE1E6EE),
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.black12),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String? rawHex) {
    final value = (rawHex ?? '').trim();
    if (value.isEmpty) {
      return null;
    }

    final hex = value.replaceAll('#', '');
    if (hex.length != 6 && hex.length != 8) {
      return null;
    }

    final withAlpha = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(withAlpha, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }
}
