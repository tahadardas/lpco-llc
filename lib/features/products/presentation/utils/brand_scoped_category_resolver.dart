import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';

class ResolvedBrandScopedCategoryItem {
  final BrandScopedCategoryItemConfig config;
  final CategoryModel category;

  const ResolvedBrandScopedCategoryItem({
    required this.config,
    required this.category,
  });

  int get categoryId => category.id;
  String get categorySlug => config.categorySlug;
  String get labelAr => config.labelAr;
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

  const BrandScopedCategoryResolver({
    BrandScopedCategoryMenuSource source =
        const LocalBrandScopedCategoryMenuSource(),
  }) : _source = source;

  ResolvedBrandScopedCategoryMenu? resolve({
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
    if (configMenu == null) return null;

    return _buildResolvedMenu(configMenu, filteredItems);
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
    var normalized = _safeDecode(value).trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized
        .replaceAll(RegExp(r'[_\s]+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF-]+'), '')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized;
  }

  static String normalizeCategorySlug(String value) {
    var normalized = _safeDecode(value).trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    return normalized;
  }

  static String? _normalizeSectionTitle(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String _safeDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }
}
