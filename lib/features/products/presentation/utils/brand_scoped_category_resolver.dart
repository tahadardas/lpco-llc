import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/domain/brand_category_linker.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';

class ResolvedBrandScopedCategoryItem {
  final BrandScopedCategoryItemConfig config;
  final CategoryModel category;

  const ResolvedBrandScopedCategoryItem({
    required this.config,
    required this.category,
  });

  int get categoryId => category.id;
  String get categorySlug =>
      category.slug.trim().isNotEmpty ? category.slug : config.categorySlug;
  String get labelAr =>
      category.name.trim().isNotEmpty ? category.name : config.labelAr;
  String? get sectionTitleAr => config.sectionTitleAr;
  int get orderIndex => config.orderIndex;
  String get stableKey => config.stableKey;
}

class ResolvedBrandScopedCategorySection {
  final String? titleAr;
  final List<ResolvedBrandScopedCategoryItem> items;

  const ResolvedBrandScopedCategorySection({
    required this.titleAr,
    required this.items,
  });
}

class ResolvedBrandScopedCategoryMenu {
  final String brandId;
  final String brandLabelAr;
  final List<String> brandAliases;
  final List<ResolvedBrandScopedCategorySection> sections;

  const ResolvedBrandScopedCategoryMenu({
    required this.brandId,
    required this.brandLabelAr,
    required this.brandAliases,
    required this.sections,
  });

  List<ResolvedBrandScopedCategoryItem> get items =>
      sections.expand((section) => section.items).toList(growable: false);

  ResolvedBrandScopedCategoryItem? selectedItemFor(
    Iterable<int> selectedCategoryIds,
  ) {
    final normalizedIds = selectedCategoryIds.where((id) => id > 0).toSet();
    if (normalizedIds.isEmpty) {
      return null;
    }

    for (final item in items) {
      if (normalizedIds.contains(item.categoryId)) {
        return item;
      }
    }
    return null;
  }
}

class BrandScopedCategoryResolver {
  final BrandScopedCategoryMenuSource _source;
  final BrandCategoryLinker _linker;

  const BrandScopedCategoryResolver({
    BrandScopedCategoryMenuSource source =
        const LocalBrandScopedCategoryMenuSource(),
    BrandCategoryLinker linker = const BrandCategoryLinker(),
  }) : _source = source,
       _linker = linker;

  ResolvedBrandScopedCategoryMenu? resolve({
    BrandModel? brand,
    required String? brandSlug,
    String? brandTitle,
    required List<CategoryModel> categories,
    Set<int>? productDerivedCategoryIds,
    bool allowConfiguredFallback = false,
  }) {
    final resolvedBrand = _resolveBrand(
      brand: brand,
      brandSlug: brandSlug,
      brandTitle: brandTitle,
    );
    if (resolvedBrand == null || categories.isEmpty) {
      return null;
    }

    final linkedCategories = _linker.findLinkedCategoriesForBrand(
      brand: resolvedBrand,
      categories: categories,
      productDerivedCategoryIds: productDerivedCategoryIds,
    );
    if (linkedCategories.isNotEmpty) {
      return _buildGeneratedMenu(
        brand: resolvedBrand,
        categories: linkedCategories,
      );
    }

    if (!allowConfiguredFallback) {
      return null;
    }

    return _resolveConfiguredMenu(
      brandSlug: resolvedBrand.slug,
      categories: categories,
    );
  }

  /// Filters a resolved menu to only include categories that have products for the brand.
  ResolvedBrandScopedCategoryMenu? filterByAvailableCategories({
    required ResolvedBrandScopedCategoryMenu menu,
    required Set<int> availableCategoryIds,
  }) {
    if (availableCategoryIds.isEmpty) {
      return null;
    }

    final filteredItems = menu.items
        .where((item) => availableCategoryIds.contains(item.categoryId))
        .toList();

    if (filteredItems.isEmpty) {
      return null;
    }

    // We need the original config menu to preserve metadata
    final configMenu = resolveConfig(brandSlug: menu.brandId);
    if (configMenu == null) {
      return ResolvedBrandScopedCategoryMenu(
        brandId: menu.brandId,
        brandLabelAr: menu.brandLabelAr,
        brandAliases: menu.brandAliases,
        sections: <ResolvedBrandScopedCategorySection>[
          ResolvedBrandScopedCategorySection(
            titleAr: null,
            items: filteredItems,
          ),
        ],
      );
    }

    return _buildResolvedMenu(configMenu, filteredItems);
  }

  ResolvedBrandScopedCategoryMenu? _resolveConfiguredMenu({
    required String? brandSlug,
    required List<CategoryModel> categories,
  }) {
    final configMenu = resolveConfig(brandSlug: brandSlug);
    if (configMenu == null || categories.isEmpty) {
      return null;
    }

    final categoriesBySlug = <String, CategoryModel>{};
    for (final category in categories) {
      final normalizedSlug = normalizeCategorySlug(category.slug);
      if (normalizedSlug.isEmpty) {
        continue;
      }
      categoriesBySlug.putIfAbsent(normalizedSlug, () => category);
    }

    final resolvedItems = <ResolvedBrandScopedCategoryItem>[];
    for (final config in configMenu.items) {
      final category =
          categoriesBySlug[normalizeCategorySlug(config.categorySlug)];
      if (category == null) {
        continue;
      }
      resolvedItems.add(
        ResolvedBrandScopedCategoryItem(config: config, category: category),
      );
    }

    if (resolvedItems.isEmpty) {
      return null;
    }

    return _buildResolvedMenu(configMenu, resolvedItems);
  }

  ResolvedBrandScopedCategoryMenu _buildGeneratedMenu({
    required BrandModel brand,
    required List<CategoryModel> categories,
  }) {
    final normalizedBrand = normalizeBrandKey(brand.slug);
    final brandLabel = brand.name.trim().isNotEmpty
        ? brand.name.trim()
        : normalizedBrand;
    final items = <ResolvedBrandScopedCategoryItem>[];

    for (final entry in categories.asMap().entries) {
      final category = entry.value;
      final orderIndex = entry.key + 1;
      final config = BrandScopedCategoryItemConfig(
        brandId: normalizedBrand,
        brandAliases: <String>[
          normalizedBrand,
          if (brand.name.trim().isNotEmpty) brand.name.trim(),
        ],
        brandLabelAr: brandLabel,
        labelAr: category.name,
        categorySlug: category.slug,
        orderIndex: orderIndex,
      );
      items.add(
        ResolvedBrandScopedCategoryItem(config: config, category: category),
      );
    }

    return ResolvedBrandScopedCategoryMenu(
      brandId: normalizedBrand,
      brandLabelAr: brandLabel,
      brandAliases: <String>[
        normalizedBrand,
        if (brand.name.trim().isNotEmpty) brand.name.trim(),
      ],
      sections: <ResolvedBrandScopedCategorySection>[
        ResolvedBrandScopedCategorySection(titleAr: null, items: items),
      ],
    );
  }

  BrandModel? _resolveBrand({
    required BrandModel? brand,
    required String? brandSlug,
    required String? brandTitle,
  }) {
    if (brand != null) {
      return brand;
    }

    final normalizedBrand = normalizeBrandKey(brandSlug ?? '');
    if (normalizedBrand.isEmpty) {
      return null;
    }

    final title = brandTitle?.trim();
    return BrandModel(
      id: 0,
      name: title == null || title.isEmpty ? normalizedBrand : title,
      slug: normalizedBrand,
      count: 0,
      imageUrl: '',
    );
  }

  ResolvedBrandScopedCategoryMenu _buildResolvedMenu(
    BrandScopedCategoryMenuConfig configMenu,
    List<ResolvedBrandScopedCategoryItem> resolvedItems,
  ) {
    final sectionsMap = <String, List<ResolvedBrandScopedCategoryItem>>{};
    final sectionTitles = <String, String?>{};
    for (final item in resolvedItems) {
      final title = _normalizeSectionTitle(item.sectionTitleAr);
      final key = title ?? '__ungrouped__';
      sectionsMap.putIfAbsent(key, () => <ResolvedBrandScopedCategoryItem>[]);
      sectionTitles[key] = title;
      sectionsMap[key]!.add(item);
    }

    final sections = sectionsMap.entries
        .map(
          (entry) => ResolvedBrandScopedCategorySection(
            titleAr: sectionTitles[entry.key],
            items: entry.value,
          ),
        )
        .toList(growable: false);

    return ResolvedBrandScopedCategoryMenu(
      brandId: configMenu.brandId,
      brandLabelAr: configMenu.brandLabelAr,
      brandAliases: configMenu.brandAliases,
      sections: sections,
    );
  }

  BrandScopedCategoryMenuConfig? resolveConfig({required String? brandSlug}) {
    final normalizedBrand = normalizeBrandKey(brandSlug ?? '');
    if (normalizedBrand.isEmpty) {
      return null;
    }

    final matchingConfigs =
        _source.items
            .where(
              (item) =>
                  matchesBrand(currentBrandSlug: normalizedBrand, config: item),
            )
            .toList(growable: false)
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (matchingConfigs.isEmpty) {
      return null;
    }

    final sectionsMap = <String, List<BrandScopedCategoryItemConfig>>{};
    final sectionTitles = <String, String?>{};
    for (final item in matchingConfigs) {
      final title = _normalizeSectionTitle(item.sectionTitleAr);
      final key = title ?? '__ungrouped__';
      sectionsMap.putIfAbsent(key, () => <BrandScopedCategoryItemConfig>[]);
      sectionTitles[key] = title;
      sectionsMap[key]!.add(item);
    }

    final sections = sectionsMap.entries
        .map(
          (entry) => BrandScopedCategoryConfigSection(
            titleAr: sectionTitles[entry.key],
            items: entry.value,
          ),
        )
        .toList(growable: false);

    final firstConfig = matchingConfigs.first;
    return BrandScopedCategoryMenuConfig(
      brandId: firstConfig.brandId,
      brandLabelAr: firstConfig.brandLabelAr,
      brandAliases: firstConfig.brandAliases,
      sections: sections,
    );
  }

  static bool matchesBrand({
    required String currentBrandSlug,
    required BrandScopedCategoryItemConfig config,
  }) {
    if (currentBrandSlug.isEmpty) {
      return false;
    }

    final candidates = <String>{
      normalizeBrandKey(config.brandId),
      ...config.brandAliases.map(normalizeBrandKey),
    }..removeWhere((value) => value.isEmpty);

    if (candidates.contains(currentBrandSlug)) {
      return true;
    }

    final rawCandidates = <String>{config.brandId, ...config.brandAliases};
    return rawCandidates.contains(currentBrandSlug);
  }

  static String normalizeBrandKey(String value) {
    return BrandCategoryLinker.normalizeSlug(value);
  }

  static String normalizeCategorySlug(String value) {
    return BrandCategoryLinker.normalizeSlug(value);
  }

  static String? _normalizeSectionTitle(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
