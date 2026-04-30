import 'package:lpco_llc/core/local/local_search_index.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';

class CatalogLocalStore {
  static final CatalogLocalStore _instance = CatalogLocalStore._internal();
  factory CatalogLocalStore() => _instance;
  CatalogLocalStore._internal();

  final StorageService _storage = StorageService();
  final LocalSearchIndex _searchIndex = LocalSearchIndex();
  bool _isMigrating = false;

  // Keys
  String _productKey(String scope, int id) => 'p::$scope::$id';
  String _categoryKey(String scope, int id) => 'c::$scope::$id';
  String _brandKey(String scope, String slug) => 'b::$scope::$slug';

  // Index Keys (Sets of IDs)
  String _productIdsKey(String scope) => 'idx_p_all::$scope';
  String _featuredIdsKey(String scope) => 'idx_p_feat::$scope';
  String _categoryProductsKey(String scope, int catId) =>
      'idx_p_cat::$scope::$catId';
  String _brandProductsKey(String scope, String slug) =>
      'idx_p_brand::$scope::$slug';

  String _categoryIdsKey(String scope) => 'idx_c_all::$scope';
  String _brandSlugsKey(String scope) => 'idx_b_all::$scope';

  // Legacy Keys for Migration
  String _legacyProductIdsKey(String scope) => 'p_ids::$scope';

  Future<void> cacheProducts({
    required String scope,
    required List<Map<String, dynamic>> products,
  }) async {
    if (products.isEmpty) return;

    final allIds = _getSet<int>(_productIdsKey(scope));
    final featIds = _getSet<int>(_featuredIdsKey(scope));

    final batch = <String, dynamic>{};
    final List<Map<String, dynamic>> productsToIndex = [];

    for (final raw in products) {
      final id = _idFrom(raw);
      if (id == null) continue;

      allIds.add(id);
      if (_isFeatured(raw)) {
        featIds.add(id);
      } else {
        featIds.remove(id);
      }

      // Update Category Indexes
      final cats = _extractCategoryIds(raw);
      for (final catId in cats) {
        final catSet = _getSet<int>(_categoryProductsKey(scope, catId));
        if (catSet.add(id)) {
          batch[_categoryProductsKey(scope, catId)] = catSet.toList();
        }
      }

      // Update Brand Index
      final brandSlug = _extractBrandSlug(raw);
      if (brandSlug != null) {
        final brandSet = _getSet<int>(_brandProductsKey(scope, brandSlug));
        if (brandSet.add(id)) {
          batch[_brandProductsKey(scope, brandSlug)] = brandSet.toList();
        }
      }

      batch[_productKey(scope, id)] = raw;
      productsToIndex.add(raw);
    }

    batch[_productIdsKey(scope)] = allIds.toList();
    batch[_featuredIdsKey(scope)] = featIds.toList();

    await _storage.catalogBox.putAll(batch);

    await _storage.saveSyncMeta('catalog::$scope', {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'products_count': allIds.length,
    });

    // Incremental Indexing
    await _searchIndex.updateIncremental(
      scope: scope,
      products: productsToIndex,
    );
  }

  Future<void> cacheCategories({
    required String scope,
    required List<Map<String, dynamic>> categories,
  }) async {
    final ids = <int>[];
    final batch = <String, dynamic>{};

    for (final cat in categories) {
      final id = _idFrom(cat);
      if (id == null) continue;
      ids.add(id);
      batch[_categoryKey(scope, id)] = cat;
    }

    await _storage.catalogBox.putAll(batch);
    await _storage.catalogBox.put(_categoryIdsKey(scope), ids);
  }

  Future<void> cacheBrands({
    required String scope,
    required List<Map<String, dynamic>> brands,
  }) async {
    final slugs = <String>[];
    final batch = <String, dynamic>{};

    for (final brand in brands) {
      final slug = (brand['slug'] ?? '').toString();
      if (slug.isEmpty) continue;
      slugs.add(slug);
      batch[_brandKey(scope, slug)] = brand;
    }

    await _storage.catalogBox.putAll(batch);
    await _storage.catalogBox.put(_brandSlugsKey(scope), slugs);
  }

  List<Map<String, dynamic>> getProducts({
    required String scope,
    int page = 1,
    int perPage = 12,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? sortBy,
  }) {
    _migrateLegacyIfNecessary(scope);

    Iterable<int> candidateIds;
    final query = (search ?? '').trim();

    if (query.isNotEmpty) {
      candidateIds = _searchIndex.queryProductIds(scope: scope, query: query);
    } else if (categoryId != null) {
      candidateIds = _getSet<int>(_categoryProductsKey(scope, categoryId));
    } else if (brandSlug != null) {
      candidateIds = _getSet<int>(
        _brandProductsKey(scope, brandSlug.toLowerCase()),
      );
    } else if (sortBy == 'featured' || sortBy == 'default') {
      // For default sort, we might want to prioritize featured, but we still need all for the base list
      candidateIds = _getSet<int>(_productIdsKey(scope));
    } else {
      candidateIds = _getSet<int>(_productIdsKey(scope));
    }

    final products = <Map<String, dynamic>>[];
    for (final id in candidateIds) {
      final raw = _storage.catalogBox.get(_productKey(scope, id));
      if (raw is Map) {
        final decoded = Map<String, dynamic>.from(raw);
        if (_matchesFilters(decoded, stock, categoryId, brandSlug)) {
          products.add(decoded);
        }
      }
    }

    _sortInPlace(products, sortBy);

    final start = (page - 1) * perPage;
    if (start >= products.length) return [];
    final end = (start + perPage) > products.length
        ? products.length
        : (start + perPage);

    return products.sublist(start, end);
  }

  Map<String, dynamic>? getProductById({
    required String scope,
    required int productId,
  }) {
    final raw = _storage.catalogBox.get(_productKey(scope, productId));
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Map<String, dynamic>? getProductBySlug({
    required String scope,
    required String slug,
  }) {
    final ids = _getSet<int>(_productIdsKey(scope));
    for (final id in ids) {
      final raw = _storage.catalogBox.get(_productKey(scope, id));
      if (raw is Map) {
        final decoded = Map<String, dynamic>.from(raw);
        if (decoded['slug'] == slug) {
          return decoded;
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> getCategories({required String scope}) {
    final ids = _getSet<int>(_categoryIdsKey(scope));
    final categories = <Map<String, dynamic>>[];
    for (final id in ids) {
      final raw = _storage.catalogBox.get(_categoryKey(scope, id));
      if (raw is Map) categories.add(Map<String, dynamic>.from(raw));
    }
    return categories;
  }

  List<Map<String, dynamic>> getBrands({required String scope}) {
    final slugs = _getSet<String>(_brandSlugsKey(scope));
    final brands = <Map<String, dynamic>>[];
    for (final slug in slugs) {
      final raw = _storage.catalogBox.get(_brandKey(scope, slug));
      if (raw is Map) brands.add(Map<String, dynamic>.from(raw));
    }
    return brands;
  }

  Set<int> getCategoryIdsForBrand({
    required String scope,
    required String brandSlug,
  }) {
    final productIds = _getSet<int>(
      _brandProductsKey(scope, brandSlug.toLowerCase()),
    );
    final categoryIds = <int>{};
    for (final id in productIds) {
      final raw = _storage.catalogBox.get(_productKey(scope, id));
      if (raw is Map) {
        final decoded = Map<String, dynamic>.from(raw);
        categoryIds.addAll(_extractCategoryIds(decoded));
      }
    }
    return categoryIds;
  }

  bool _matchesFilters(
    Map<String, dynamic> item,
    String stock,
    int? categoryId,
    String? brandSlug,
  ) {
    if (stock != 'all' && !_matchesStock(item, stock)) return false;
    // Secondary checks if candidateIds was broad
    if (categoryId != null && !_matchesCategory(item, categoryId)) return false;
    if (brandSlug != null && !_matchesBrand(item, brandSlug.toLowerCase())) {
      return false;
    }
    return true;
  }

  void _sortInPlace(List<Map<String, dynamic>> list, String? sortBy) {
    final normalizedSort = (sortBy ?? 'default').trim().toLowerCase();
    list.sort((a, b) {
      switch (normalizedSort) {
        case 'price_asc':
          final byPrice = _priceFrom(a).compareTo(_priceFrom(b));
          if (byPrice != 0) {
            return byPrice;
          }
          return _defaultCompare(a, b, includeAvailability: false);
        case 'price_desc':
          final byPrice = _priceFrom(b).compareTo(_priceFrom(a));
          if (byPrice != 0) {
            return byPrice;
          }
          return _defaultCompare(a, b, includeAvailability: false);
        case 'newest':
          final byNewest = (_idFrom(b) ?? 0).compareTo(_idFrom(a) ?? 0);
          if (byNewest != 0) {
            return byNewest;
          }
          return _defaultCompare(a, b, includeAvailability: false);
        case 'default':
        case 'featured':
        default:
          return _defaultCompare(a, b);
      }
    });
  }

  // --- Helpers ---

  Set<T> _getSet<T>(String key) {
    final raw = _storage.catalogBox.get(key);
    if (raw is List) return raw.cast<T>().toSet();
    return <T>{};
  }

  int? _idFrom(Map<String, dynamic> item) {
    final raw = item['id'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  bool _isFeatured(Map<String, dynamic> item) =>
      item['featured'] == true || item['is_featured'] == true;

  bool _isInStock(Map<String, dynamic> item) {
    final status = (item['stock_status'] ?? '').toString().toLowerCase();
    if (status == 'instock' || status == 'onbackorder') {
      return true;
    }
    if (status == 'outofstock') {
      return false;
    }

    return _boolish(item['in_stock']) || _boolish(item['is_in_stock']);
  }

  List<int> _extractCategoryIds(Map<String, dynamic> item) {
    final cats = item['categories'];
    if (cats is List) {
      return cats
          .map((c) => _idFrom(Map<String, dynamic>.from(c)))
          .whereType<int>()
          .toList();
    }
    return [];
  }

  String? _extractBrandSlug(Map<String, dynamic> item) {
    final brands = item['brands'];
    if (brands is List && brands.isNotEmpty) {
      return (brands.first['slug'] ?? '').toString().toLowerCase();
    }
    return item['brand_slug']?.toString().toLowerCase();
  }

  double _priceFrom(Map<String, dynamic> item) =>
      double.tryParse(item['price']?.toString() ?? '0') ?? 0;
  int _customOrderFrom(Map<String, dynamic> item) =>
      item['menu_order'] ?? item['custom_order'] ?? 999;

  bool _matchesStock(Map<String, dynamic> item, String stock) {
    final normalized = stock.trim().toLowerCase();
    final inStock = _isInStock(item);
    if (normalized == 'instock') {
      return inStock;
    }
    if (normalized == 'outofstock') {
      return !inStock;
    }
    return true;
  }

  int _defaultCompare(
    Map<String, dynamic> a,
    Map<String, dynamic> b, {
    bool includeAvailability = true,
  }) {
    if (includeAvailability) {
      final aStock = _isInStock(a);
      final bStock = _isInStock(b);
      if (aStock != bStock) {
        return aStock ? -1 : 1;
      }
    }

    final aFeat = _isFeatured(a);
    final bFeat = _isFeatured(b);
    if (aFeat != bFeat) {
      return aFeat ? -1 : 1;
    }

    final customOrder = _customOrderFrom(a).compareTo(_customOrderFrom(b));
    if (customOrder != 0) {
      return customOrder;
    }

    final idCompare = (_idFrom(a) ?? 0).compareTo(_idFrom(b) ?? 0);
    if (idCompare != 0) {
      return idCompare;
    }

    return (_nameFrom(a)).compareTo(_nameFrom(b));
  }

  bool _boolish(dynamic raw) {
    if (raw is bool) {
      return raw;
    }
    final normalized = '$raw'.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'instock';
  }

  bool _matchesCategory(Map<String, dynamic> item, int catId) =>
      _extractCategoryIds(item).contains(catId);
  bool _matchesBrand(Map<String, dynamic> item, String slug) =>
      _extractBrandSlug(item) == slug;

  String _nameFrom(Map<String, dynamic> item) {
    return (item['name'] ?? item['product_name'] ?? '').toString().trim();
  }

  Future<void> _migrateLegacyIfNecessary(String scope) async {
    if (_isMigrating) return;
    final legacyIds = _storage.catalogBox.get(_legacyProductIdsKey(scope));
    if (legacyIds == null) return;

    _isMigrating = true;
    try {
      final ids = (legacyIds as List).cast<int>();
      final products = <Map<String, dynamic>>[];
      for (final id in ids) {
        final raw = _storage.catalogBox.get('p::$scope::$id');
        if (raw is Map) products.add(Map<String, dynamic>.from(raw));
      }
      if (products.isNotEmpty) {
        await cacheProducts(scope: scope, products: products);
      }
      await _storage.catalogBox.delete(_legacyProductIdsKey(scope));
    } finally {
      _isMigrating = false;
    }
  }
}
