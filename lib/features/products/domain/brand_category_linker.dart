import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';

class BrandCategoryLinker {
  const BrandCategoryLinker();

  List<CategoryModel> findLinkedCategoriesForBrand({
    required BrandModel brand,
    required List<CategoryModel> categories,
    Set<int>? productDerivedCategoryIds,
  }) {
    if (categories.isEmpty) {
      return const <CategoryModel>[];
    }

    final brandSlug = normalizeSlug(brand.slug);
    if (brandSlug.isEmpty) {
      return const <CategoryModel>[];
    }

    final categoriesById = <int, CategoryModel>{};
    final categoriesBySlug = <String, CategoryModel>{};
    for (final category in categories) {
      if (category.id > 0) {
        categoriesById[category.id] = category;
      }
      final slug = normalizeSlug(category.slug);
      if (slug.isNotEmpty) {
        categoriesBySlug.putIfAbsent(slug, () => category);
      }
    }

    final explicit = _explicitLinkedCategories(
      brand: brand,
      categoriesById: categoriesById,
      categoriesBySlug: categoriesBySlug,
    );
    final linkedById = <int, CategoryModel>{};
    void include(CategoryModel category) {
      if (category.id > 0) {
        linkedById[category.id] = category;
      }
    }

    final rootCategoryIds = _rootCategoryIds(categories, brandSlug);
    for (final category in explicit) {
      include(category);
    }

    for (final category in categories) {
      final categorySlug = normalizeSlug(category.slug);
      if (_slugHasBrandToken(
        categorySlug: categorySlug,
        brandSlug: brandSlug,
      )) {
        include(category);
        continue;
      }

      if (rootCategoryIds.contains(category.parentId)) {
        include(category);
      }
    }

    final derivedIds = productDerivedCategoryIds ?? const <int>{};
    for (final categoryId in derivedIds) {
      final category = categoriesById[categoryId];
      if (category != null) {
        include(category);
      }
    }

    return _sortLinkedCategories(
      _visibleBrandCategories(
        linkedById.values,
        allCategories: categories,
        rootCategoryIds: rootCategoryIds,
      ),
      brandSlug: brandSlug,
      rootCategoryIds: rootCategoryIds,
    );
  }

  static String normalizeSlug(String value) {
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

  static String normalizeText(String value) {
    var normalized = _safeDecode(value).trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll('\u0623', '\u0627')
        .replaceAll('\u0625', '\u0627')
        .replaceAll('\u0622', '\u0627')
        .replaceAll('\u0649', '\u064A')
        .replaceAll('\u0629', '\u0647')
        .replaceAll(RegExp(r'[_\-/]+'), ' ')
        .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  Iterable<CategoryModel> _explicitLinkedCategories({
    required BrandModel brand,
    required Map<int, CategoryModel> categoriesById,
    required Map<String, CategoryModel> categoriesBySlug,
  }) sync* {
    final seen = <int>{};

    for (final id in brand.linkedCategoryIds) {
      final category = categoriesById[id];
      if (category != null && seen.add(category.id)) {
        yield category;
      }
    }

    for (final rawSlug in brand.linkedCategorySlugs) {
      final category = categoriesBySlug[normalizeSlug(rawSlug)];
      if (category != null && seen.add(category.id)) {
        yield category;
      }
    }
  }

  Set<int> _rootCategoryIds(List<CategoryModel> categories, String brandSlug) {
    if (brandSlug.isEmpty) {
      return const <int>{};
    }
    return categories
        .where((category) => normalizeSlug(category.slug) == brandSlug)
        .map((category) => category.id)
        .where((id) => id > 0)
        .toSet();
  }

  bool _slugHasBrandToken({
    required String categorySlug,
    required String brandSlug,
  }) {
    if (categorySlug.isEmpty || brandSlug.isEmpty) {
      return false;
    }
    return categorySlug == brandSlug ||
        categorySlug.startsWith('$brandSlug-') ||
        categorySlug.endsWith('-$brandSlug') ||
        categorySlug.contains('-$brandSlug-');
  }

  Iterable<CategoryModel> _visibleBrandCategories(
    Iterable<CategoryModel> categories, {
    required List<CategoryModel> allCategories,
    required Set<int> rootCategoryIds,
  }) sync* {
    final parentsWithVisibleChildren = allCategories
        .where((category) => category.count > 0 && category.parentId > 0)
        .map((category) => category.parentId)
        .toSet();

    for (final category in categories) {
      if (category.count > 0) {
        yield category;
        continue;
      }

      if (rootCategoryIds.contains(category.id) &&
          parentsWithVisibleChildren.contains(category.id)) {
        yield category;
      }
    }
  }

  List<CategoryModel> _sortLinkedCategories(
    Iterable<CategoryModel> categories, {
    required String brandSlug,
    required Set<int> rootCategoryIds,
  }) {
    final sorted = categories.toList(growable: false);
    sorted.sort((a, b) {
      final tierCompare =
          _sortTier(
            a,
            brandSlug: brandSlug,
            rootCategoryIds: rootCategoryIds,
          ).compareTo(
            _sortTier(
              b,
              brandSlug: brandSlug,
              rootCategoryIds: rootCategoryIds,
            ),
          );
      if (tierCompare != 0) {
        return tierCompare;
      }

      final menuOrderCompare = a.menuOrder.compareTo(b.menuOrder);
      if (menuOrderCompare != 0) {
        return menuOrderCompare;
      }

      final nameCompare = normalizeText(
        a.name,
      ).compareTo(normalizeText(b.name));
      if (nameCompare != 0) {
        return nameCompare;
      }

      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  int _sortTier(
    CategoryModel category, {
    required String brandSlug,
    required Set<int> rootCategoryIds,
  }) {
    if (rootCategoryIds.contains(category.id) ||
        normalizeSlug(category.slug) == brandSlug) {
      return 0;
    }
    if (rootCategoryIds.contains(category.parentId)) {
      return 1;
    }
    return 2;
  }

  static String _safeDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }
}
