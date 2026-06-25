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
  final bool hasAuthoritativeCategories;

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
    this.hasAuthoritativeCategories = false,
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
    final hasApiCategories =
        widget.hasAuthoritativeCategories ||
        (widget.brand != null &&
            (widget.brand!.linkedCategories.isNotEmpty ||
                widget.brand!.linkedCategoryIds.isNotEmpty ||
                widget.brand!.linkedCategorySlugs.isNotEmpty));
    final menu = resolvedMenu == null
        ? null
        : (hasApiCategories
              ? resolvedMenu
              : resolver.filterByAvailableCategories(
                  menu: resolvedMenu,
                  availableCategoryIds: widget.productDerivedCategoryIds,
                ));
    if (menu == null || menu.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedItem = menu.selectedItemFor(widget.selectedCategoryIds);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      key: const ValueKey<String>('brand_scoped_category_menu'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey<String>('brand_scoped_category_button'),
          style: OutlinedButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            side: const BorderSide(color: Color(0xFFD9E1EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            foregroundColor: colorScheme.onSurface,
            backgroundColor: colorScheme.surface,
          ),
          onPressed: _isApplying
              ? null
              : () => _openCategorySheet(context, menu, selectedItem),
          icon: Icon(Icons.tune_rounded, color: colorScheme.primary),
          label: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  selectedItem == null ? _titleFor(menu) : selectedItem.labelAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCategorySheet(
    BuildContext context,
    ResolvedBrandScopedCategoryMenu menu,
    ResolvedBrandScopedCategoryItem? selectedItem,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: Directionality.of(context),
          child: SafeArea(
            child: ConstrainedBox(
              key: const ValueKey<String>('brand_scoped_category_sheet'),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _titleFor(menu),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          key: const ValueKey<String>(
                            'brand_scoped_category_all',
                          ),
                          label: const Text('\u0627\u0644\u0643\u0644'),
                          avatar: const Icon(Icons.apps_rounded, size: 17),
                          selected: selectedItem == null,
                          showCheckmark: false,
                          selectedColor: colorScheme.primaryContainer,
                          onSelected: _isApplying
                              ? null
                              : (_) {
                                  Navigator.of(sheetContext).pop();
                                  _handleClear();
                                },
                        ),
                        ...menu.items.map((item) {
                          final isSelected =
                              selectedItem?.categoryId == item.categoryId;
                          return ChoiceChip(
                            key: ValueKey<String>(
                              'brand_scoped_category_item_${item.stableKey}',
                            ),
                            label: Text(_labelFor(item.category)),
                            avatar: const Icon(
                              Icons.grid_view_rounded,
                              size: 16,
                            ),
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
                                : (_) {
                                    Navigator.of(sheetContext).pop();
                                    _handleSelect(item);
                                  },
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
