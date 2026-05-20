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
    final brandName = normalizeText(brand.name);
    if (brandSlug.isEmpty && brandName.isEmpty) {
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
    if (explicit.isNotEmpty) {
      return _sortLinkedCategories(
        explicit,
        brandSlug: brandSlug,
        rootCategoryIds: _rootCategoryIds(categories, brandSlug),
      );
    }

    final linkedById = <int, CategoryModel>{};
    void include(CategoryModel category) {
      if (category.id > 0) {
        linkedById[category.id] = category;
      }
    }

    final rootCategoryIds = _rootCategoryIds(categories, brandSlug);
    for (final category in categories) {
      final categorySlug = normalizeSlug(category.slug);
      if (categorySlug.isNotEmpty && categorySlug == brandSlug) {
        include(category);
        continue;
      }
      if (rootCategoryIds.contains(category.parentId)) {
        include(category);
        continue;
      }
      if (_slugHasBrandToken(
        categorySlug: categorySlug,
        brandSlug: brandSlug,
      )) {
        include(category);
        continue;
      }
      if (_nameMatchesBrand(
        categoryName: category.name,
        brandName: brand.name,
        brandSlug: brand.slug,
      )) {
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
      linkedById.values,
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

  bool _nameMatchesBrand({
    required String categoryName,
    required String brandName,
    required String brandSlug,
  }) {
    final normalizedCategoryName = normalizeText(categoryName);
    if (normalizedCategoryName.isEmpty) {
      return false;
    }

    final normalizedBrandName = normalizeText(brandName);
    if (_containsTokenSequence(normalizedCategoryName, normalizedBrandName)) {
      return true;
    }

    final normalizedBrandSlug = normalizeText(brandSlug);
    return _containsTokenSequence(normalizedCategoryName, normalizedBrandSlug);
  }

  bool _containsTokenSequence(String haystack, String needle) {
    if (needle.length < 2) {
      return false;
    }
    final haystackTokens = haystack
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final needleTokens = needle
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    if (haystackTokens.isEmpty ||
        needleTokens.isEmpty ||
        needleTokens.length > haystackTokens.length) {
      return false;
    }

    for (
      var start = 0;
      start <= haystackTokens.length - needleTokens.length;
      start += 1
    ) {
      var matches = true;
      for (var offset = 0; offset < needleTokens.length; offset += 1) {
        if (haystackTokens[start + offset] != needleTokens[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
    return false;
  }

  List<CategoryModel> _sortLinkedCategories(
    Iterable<CategoryModel> categories, {
    required String brandSlug,
    required Set<int> rootCategoryIds,
  }) {
    final sorted = categories.toList(growable: false);
    sorted.sort((a, b) {
      final aIsRoot =
          rootCategoryIds.contains(a.id) || normalizeSlug(a.slug) == brandSlug;
      final bIsRoot =
          rootCategoryIds.contains(b.id) || normalizeSlug(b.slug) == brandSlug;
      if (aIsRoot != bIsRoot) {
        return aIsRoot ? -1 : 1;
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

  static String _safeDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }
}
