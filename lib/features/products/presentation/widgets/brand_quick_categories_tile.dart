import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';

class BrandQuickCategoriesTile extends StatefulWidget {
  final String brandSlug;
  final String title;
  final String subtitle;
  final String imageUrl;
  final BrandScopedCategoryMenuConfig? curatedMenu;
  final ResolvedBrandScopedCategoryMenu? resolvedCuratedMenu;
  final VoidCallback onTapBrand;
  final ValueChanged<BrandScopedCategoryItemConfig>? onTapCuratedCategory;
  final ValueChanged<CategoryModel>? onTapCategory;

  const BrandQuickCategoriesTile({
    super.key,
    required this.brandSlug,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTapBrand,
    this.curatedMenu,
    this.resolvedCuratedMenu,
    this.onTapCuratedCategory,
    this.onTapCategory,
  });

  @override
  State<BrandQuickCategoriesTile> createState() =>
      _BrandQuickCategoriesTileState();
}

class _BrandQuickCategoriesTileState extends State<BrandQuickCategoriesTile>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isLoading = false;
  List<CategoryModel> _dynamicCategories = [];

  bool get _hasCuratedMenu =>
      (widget.curatedMenu != null || widget.resolvedCuratedMenu != null) &&
      widget.onTapCuratedCategory != null;

  bool get _canExpand => _hasCuratedMenu || widget.onTapCategory != null;

  Future<void> _handleExpand() async {
    final nextState = !_isExpanded;
    if (nextState && !_hasCuratedMenu && _dynamicCategories.isEmpty) {
      await _loadDynamicCategories();
    }
    setState(() => _isExpanded = nextState);
  }

  Future<void> _loadDynamicCategories() async {
    if (_isLoading) return;
    final cubit = _tryReadProductCubit();
    if (cubit == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final categoryIds = await cubit.getCategoryIdsForBrand(widget.brandSlug);

      if (mounted) {
        final all = cubit.state.categories;
        final matched = all.where((c) => categoryIds.contains(c.id)).toList();
        setState(() {
          _dynamicCategories = matched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ProductCubit? _tryReadProductCubit() {
    try {
      return context.read<ProductCubit>();
    } catch (_) {
      return null;
    }
  }

  ResolvedBrandScopedCategoryMenu? _getFilteredCuratedMenu() {
    const resolver = BrandScopedCategoryResolver();
    final cubit = _tryReadProductCubit();
    final categories = cubit?.state.categories ?? const <CategoryModel>[];
    final categoryIdsForBrand =
        cubit?.getActiveCategoryIdsForBrand(widget.brandSlug) ?? const <int>{};

    // 1. Resolve global categories to our curated config
    final resolved =
        widget.resolvedCuratedMenu ??
        (categories.isNotEmpty
            ? resolver.resolve(
                brandSlug: widget.brandSlug,
                categories: categories,
              )
            : null);

    if (resolved == null) return null;

    // 2. Filter by actual product availability if we have the index
    if (categoryIdsForBrand.isNotEmpty) {
      return resolver.filterByAvailableCategories(
        menu: resolved,
        availableCategoryIds: categoryIdsForBrand,
      );
    }

    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E9F1)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0E0B1524),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      key: ValueKey<String>(
                        'brand_quick_categories_brand_tap_${widget.brandSlug}',
                      ),
                      onTap: widget.onTapBrand,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: AppNetworkImage(
                                  imageUrl: widget.imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: Container(
                                    color: const Color(0xFFF1F4F8),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.sell_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  errorWidget: Container(
                                    color: const Color(0xFFF1F4F8),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.sell_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle,
                                    style: const TextStyle(
                                      color: Color(0xFF737C8A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_left_rounded,
                              color: Color(0xFF9BA4B2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_canExpand)
                    IconButton(
                      key: ValueKey<String>(
                        'brand_quick_categories_expand_${widget.brandSlug}',
                      ),
                      tooltip: _isExpanded
                          ? 'إخفاء التصنيفات'
                          : 'إظهار التصنيفات',
                      onPressed: _handleExpand,
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        turns: _isExpanded ? 0.5 : 0,
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _isExpanded
                  ? (_hasCuratedMenu
                        ? _ExpandedQuickCategoriesPanel(
                            brandTitle: widget.title,
                            menu: _getFilteredCuratedMenu(),
                            fallbackMenuConfig: widget.curatedMenu,
                            onTapBrand: widget.onTapBrand,
                            onTapCuratedCategory: widget.onTapCuratedCategory!,
                          )
                        : _DynamicCategoriesPanel(
                            brandTitle: widget.title,
                            isLoading: _isLoading,
                            categories: _dynamicCategories,
                            onTapBrand: widget.onTapBrand,
                            onTapCategory: widget.onTapCategory!,
                          ))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedQuickCategoriesPanel extends StatelessWidget {
  final String brandTitle;
  final ResolvedBrandScopedCategoryMenu? menu;
  final BrandScopedCategoryMenuConfig? fallbackMenuConfig;
  final VoidCallback onTapBrand;
  final ValueChanged<BrandScopedCategoryItemConfig> onTapCuratedCategory;

  const _ExpandedQuickCategoriesPanel({
    required this.brandTitle,
    required this.menu,
    required this.fallbackMenuConfig,
    required this.onTapBrand,
    required this.onTapCuratedCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (menu == null && fallbackMenuConfig == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final resolvedSections =
        menu?.sections ?? const <ResolvedBrandScopedCategorySection>[];
    final configSections =
        fallbackMenuConfig?.sections ??
        const <BrandScopedCategoryConfigSection>[];
    final hasResolvedSections = resolvedSections.isNotEmpty;
    final showSectionTitles = hasResolvedSections
        ? resolvedSections.length > 1 ||
              (resolvedSections.isNotEmpty &&
                  (resolvedSections.first.titleAr?.trim().isNotEmpty ?? false))
        : configSections.length > 1 ||
              (configSections.isNotEmpty &&
                  (configSections.first.titleAr?.trim().isNotEmpty ?? false));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            'اختر تصنيفاً جاهزاً من $brandTitle أو افتح كل المنتجات.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5F6979),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onTapBrand,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('كل منتجات $brandTitle'),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (hasResolvedSections)
                    for (final section in resolvedSections) ...<Widget>[
                      if (showSectionTitles &&
                          (section.titleAr?.trim().isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
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
                            .map<Widget>(
                              (item) => ActionChip(
                                key: ValueKey<String>(
                                  'brand_quick_category_${item.stableKey}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: const Icon(
                                  Icons.subdirectory_arrow_left_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  item.labelAr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () =>
                                    onTapCuratedCategory(item.config),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ]
                  else
                    for (final section in configSections) ...<Widget>[
                      if (showSectionTitles &&
                          (section.titleAr?.trim().isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
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
                            .map<Widget>(
                              (item) => ActionChip(
                                key: ValueKey<String>(
                                  'brand_quick_category_${item.stableKey}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: const Icon(
                                  Icons.subdirectory_arrow_left_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  item.labelAr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () => onTapCuratedCategory(item),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicCategoriesPanel extends StatelessWidget {
  final String brandTitle;
  final bool isLoading;
  final List<CategoryModel> categories;
  final VoidCallback onTapBrand;
  final ValueChanged<CategoryModel> onTapCategory;

  const _DynamicCategoriesPanel({
    required this.brandTitle,
    required this.isLoading,
    required this.categories,
    required this.onTapBrand,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...<Widget>[
            Text(
              'تصفح تصنيفات $brandTitle المتاحة أو كل المنتجات.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5F6979),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onTapBrand,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('كل منتجات $brandTitle'),
              ),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'لم يتم العثور على تصنيفات مخصصة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (cat) => ActionChip(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: const Icon(
                          Icons.subdirectory_arrow_left_rounded,
                          size: 14,
                        ),
                        label: Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => onTapCategory(cat),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ],
      ),
    );
  }
}
