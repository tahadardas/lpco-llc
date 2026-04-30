import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';

class BrandScopedCategoryMenu extends StatefulWidget {
  final String? brandSlug;
  final String brandTitle;
  final List<CategoryModel> categories;
  final Set<int> selectedCategoryIds;
  final FutureOr<void> Function(ResolvedBrandScopedCategoryItem item)
  onSelectCategory;
  final FutureOr<void> Function() onClearCategory;
  final BrandScopedCategoryMenuSource menuSource;

  const BrandScopedCategoryMenu({
    super.key,
    required this.brandSlug,
    required this.brandTitle,
    required this.categories,
    required this.selectedCategoryIds,
    required this.onSelectCategory,
    required this.onClearCategory,
    this.menuSource = const LocalBrandScopedCategoryMenuSource(),
  });

  @override
  State<BrandScopedCategoryMenu> createState() =>
      _BrandScopedCategoryMenuState();
}

class _BrandScopedCategoryMenuState extends State<BrandScopedCategoryMenu>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final menu = BrandScopedCategoryResolver(
      source: widget.menuSource,
    ).resolve(brandSlug: widget.brandSlug, categories: widget.categories);
    if (menu == null) {
      return const SizedBox.shrink();
    }

    final selectedItem = menu.selectedItemFor(widget.selectedCategoryIds);
    final isCompactLayout = MediaQuery.sizeOf(context).width < 720;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: isCompactLayout
          ? _CompactBrandScopedCategoryMenuCard(
              menu: menu,
              selectedItem: selectedItem,
              isBusy: _isApplying,
              onOpen: () => _openBottomSheet(menu, selectedItem),
            )
          : _buildInlineCard(menu, selectedItem),
    );
  }

  Widget _buildInlineCard(
    ResolvedBrandScopedCategoryMenu menu,
    ResolvedBrandScopedCategoryItem? selectedItem,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey<String>('brand_scoped_category_menu'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF1)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _BrandScopedCategoryMenuHeader(
                      brandLabelAr: menu.brandLabelAr,
                      selectedItem: selectedItem,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>(
                      'brand_scoped_category_menu_toggle_button',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: AnimatedRotation(
                      duration: const Duration(milliseconds: 220),
                      turns: _isExpanded ? 0.5 : 0,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    label: Text(_isExpanded ? 'إخفاء' : 'عرض'),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _isExpanded
                ? Column(
                    children: <Widget>[
                      const Divider(height: 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: _BrandScopedCategoryMenuContent(
                          menu: menu,
                          selectedItem: selectedItem,
                          isBusy: _isApplying,
                          onSelectCategory: _handleSelect,
                          onClearCategory: _handleClear,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _openBottomSheet(
    ResolvedBrandScopedCategoryMenu menu,
    ResolvedBrandScopedCategoryItem? selectedItem,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _BrandScopedCategoryMenuHeader(
                        brandLabelAr: menu.brandLabelAr,
                        selectedItem: selectedItem,
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _BrandScopedCategoryMenuContent(
                  menu: menu,
                  selectedItem: selectedItem,
                  isBusy: _isApplying,
                  onSelectCategory: (item) async {
                    Navigator.of(sheetContext).pop();
                    await _handleSelect(item);
                  },
                  onClearCategory: () async {
                    Navigator.of(sheetContext).pop();
                    await _handleClear();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

class _CompactBrandScopedCategoryMenuCard extends StatelessWidget {
  final ResolvedBrandScopedCategoryMenu menu;
  final ResolvedBrandScopedCategoryItem? selectedItem;
  final bool isBusy;
  final VoidCallback onOpen;

  const _CompactBrandScopedCategoryMenuCard({
    required this.menu,
    required this.selectedItem,
    required this.isBusy,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey<String>('brand_scoped_category_menu'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _BrandScopedCategoryMenuHeader(
                  brandLabelAr: menu.brandLabelAr,
                  selectedItem: selectedItem,
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey<String>(
                  'brand_scoped_category_menu_open_button',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                ),
                onPressed: isBusy ? null : onOpen,
                icon: const Icon(Icons.menu_open_rounded),
                label: const Text('التصنيفات'),
              ),
            ],
          ),
          if (selectedItem != null) ...<Widget>[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InputChip(
                label: Text(selectedItem!.labelAr),
                avatar: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                onPressed: null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandScopedCategoryMenuHeader extends StatelessWidget {
  final String brandLabelAr;
  final ResolvedBrandScopedCategoryItem? selectedItem;

  const _BrandScopedCategoryMenuHeader({
    required this.brandLabelAr,
    required this.selectedItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'تصنيفات $brandLabelAr',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selectedItem == null
              ? 'اختر قسماً فرعياً للتصفية داخل نفس العلامة.'
              : 'التصنيف المحدد: ${selectedItem!.labelAr}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF5F6979),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BrandScopedCategoryMenuContent extends StatelessWidget {
  final ResolvedBrandScopedCategoryMenu menu;
  final ResolvedBrandScopedCategoryItem? selectedItem;
  final bool isBusy;
  final Future<void> Function(ResolvedBrandScopedCategoryItem item)
  onSelectCategory;
  final Future<void> Function() onClearCategory;

  const _BrandScopedCategoryMenuContent({
    required this.menu,
    required this.selectedItem,
    required this.isBusy,
    required this.onSelectCategory,
    required this.onClearCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showSectionTitles =
        menu.sections.length > 1 ||
        (menu.sections.isNotEmpty &&
            (menu.sections.first.titleAr?.trim().isNotEmpty ?? false));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  selectedItem == null
                      ? 'اعرض كل منتجات ${menu.brandLabelAr} أو اختر تصنيفاً فرعياً جاهزاً.'
                      : 'تتم التصفية حالياً داخل ${menu.brandLabelAr} حسب "${selectedItem!.labelAr}".',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'brand_scoped_category_clear_button',
                  ),
                  onPressed: isBusy ? null : onClearCategory,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('عرض كل منتجات ${menu.brandLabelAr}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final section in menu.sections) ...<Widget>[
            if (showSectionTitles &&
                (section.titleAr?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  section.titleAr!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: section.items
                  .map((item) {
                    final isSelected =
                        selectedItem?.categoryId == item.categoryId;
                    return ChoiceChip(
                      key: ValueKey<String>(
                        'brand_scoped_category_item_${item.stableKey}',
                      ),
                      label: Text(item.labelAr),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: colorScheme.primaryContainer,
                      backgroundColor: colorScheme.surface,
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : const Color(0xFFD9E1EB),
                      ),
                      onSelected: isBusy ? null : (_) => onSelectCategory(item),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
