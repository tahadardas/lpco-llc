import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';

class BrandScopedCategoryMenu extends StatefulWidget {
  final BrandModel? brand;
  final String? brandSlug;
  final String brandTitle;
  final List<CategoryModel> categories;
  final Set<int> selectedCategoryIds;
  final Set<int> productDerivedCategoryIds;
  final FutureOr<void> Function(ResolvedBrandScopedCategoryItem item)
  onSelectCategory;
  final FutureOr<void> Function() onClearCategory;
  final BrandScopedCategoryMenuSource menuSource;
  final bool allowConfiguredFallback;

  const BrandScopedCategoryMenu({
    super.key,
    this.brand,
    required this.brandSlug,
    required this.brandTitle,
    required this.categories,
    required this.selectedCategoryIds,
    required this.onSelectCategory,
    required this.onClearCategory,
    this.productDerivedCategoryIds = const <int>{},
    this.menuSource = const LocalBrandScopedCategoryMenuSource(),
    this.allowConfiguredFallback = false,
  });

  @override
  State<BrandScopedCategoryMenu> createState() =>
      _BrandScopedCategoryMenuState();
}

class _BrandScopedCategoryMenuState extends State<BrandScopedCategoryMenu> {
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final resolver = BrandScopedCategoryResolver(source: widget.menuSource);
    final resolvedMenu = resolver.resolve(
      brand: widget.brand,
      brandSlug: widget.brandSlug,
      brandTitle: widget.brandTitle,
      categories: widget.categories,
      productDerivedCategoryIds: widget.productDerivedCategoryIds,
      allowConfiguredFallback: widget.allowConfiguredFallback,
    );
    final menu = resolvedMenu == null
        ? null
        : resolver.filterByAvailableCategories(
            menu: resolvedMenu,
            availableCategoryIds: widget.productDerivedCategoryIds,
          );
    if (menu == null || menu.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedItem = menu.selectedItemFor(widget.selectedCategoryIds);
    final items = menu.items;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: DecoratedBox(
        key: const ValueKey<String>('brand_scoped_category_menu'),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E9F1)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.category_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _titleFor(menu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ChoiceChip(
                        key: const ValueKey<String>(
                          'brand_scoped_category_all',
                        ),
                        label: const Text('\u0627\u0644\u0643\u0644'),
                        avatar: const Icon(Icons.apps_rounded, size: 17),
                        selected: selectedItem == null,
                        showCheckmark: false,
                        onSelected: _isApplying ? null : (_) => _handleClear(),
                      );
                    }

                    final item = items[index - 1];
                    final isSelected =
                        selectedItem?.categoryId == item.categoryId;
                    return ChoiceChip(
                      key: ValueKey<String>(
                        'brand_scoped_category_item_${item.stableKey}',
                      ),
                      label: Text(_labelFor(item.category)),
                      avatar: const Icon(Icons.grid_view_rounded, size: 16),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: colorScheme.primaryContainer,
                      backgroundColor: colorScheme.surface,
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : const Color(0xFFD9E1EB),
                      ),
                      onSelected: _isApplying
                          ? null
                          : (_) => _handleSelect(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(ResolvedBrandScopedCategoryMenu menu) {
    final label = menu.brandLabelAr.trim();
    if (label.isNotEmpty) {
      return '\u062A\u0635\u0646\u064A\u0641\u0627\u062A $label';
    }
    return '\u0627\u0644\u062A\u0635\u0646\u064A\u0641\u0627\u062A \u0627\u0644\u0645\u0631\u062A\u0628\u0637\u0629 \u0628\u0627\u0644\u0639\u0644\u0627\u0645\u0629';
  }

  String _labelFor(CategoryModel category) {
    // category.count is the global WooCommerce count across ALL brands.
    // Displaying it in a brand-scoped context is misleading (e.g. showing 53
    // for "pencils" when only 1 belongs to this brand). Show name only until
    // a reliable brand-scoped count is available from the backend.
    return category.name;
  }

  Future<void> _handleSelect(ResolvedBrandScopedCategoryItem item) async {
    if (_isApplying) {
      return;
    }

    setState(() => _isApplying = true);
    try {
      await widget.onSelectCategory(item);
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _handleClear() async {
    if (_isApplying) {
      return;
    }

    setState(() => _isApplying = true);
    try {
      await widget.onClearCategory();
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }
}
