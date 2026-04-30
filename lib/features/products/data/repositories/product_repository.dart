import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/local/catalog_local_store.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';

class HomeBannerData {
  final bool enabled;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String buttonLink;
  final List<int> productIds;

  const HomeBannerData({
    required this.enabled,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonLink,
    required this.productIds,
  });

  const HomeBannerData.empty()
    : enabled = false,
      imageUrl = '',
      title = '',
      subtitle = '',
      buttonLabel = '',
      buttonLink = '',
      productIds = const [];

  bool get hasImage => imageUrl.isNotEmpty;

  HomeBannerData copyWith({
    bool? enabled,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? buttonLabel,
    String? buttonLink,
    List<int>? productIds,
  }) {
    return HomeBannerData(
      enabled: enabled ?? this.enabled,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      buttonLabel: buttonLabel ?? this.buttonLabel,
      buttonLink: buttonLink ?? this.buttonLink,
      productIds: productIds ?? this.productIds,
    );
  }
}

class ProductRepository {
  final DioClient _dioClient;
  final StorageService _storageService = StorageService();
  final CatalogLocalStore _catalogLocalStore = CatalogLocalStore();
  final ReachabilityService _reachabilityService = ReachabilityService();
  static const String _pricingRev = '2026-03-09-1';
  String _lastResolvedScope = 'guest';

  ProductRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  void invalidateCache() {
    // Cache invalidation no longer needed - removed static session-sensitive cache
  }

  Future<List<ProductModel>> getProducts({
    int page = 1,
    int perPage = AppConfig.productsPerPage,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? orderBy,
    String? order,
    bool guest = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    if (reachability.status == ReachabilityStatus.offline) {
      return _loadProductsFromLocal(
        scope: scope,
        page: page,
        perPage: perPage,
        categoryId: categoryId,
        search: search,
        brandSlug: brandSlug,
        stock: stock,
        sortBy: orderBy == 'price' ? 'price_$order' : orderBy,
      );
    }

    try {
      final query = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'pricing_rev': _pricingRev,
      };
      query.addAll(await _userScopeQuery(guest: guest));
      if (categoryId != null) {
        query['category'] = categoryId;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (brandSlug != null && brandSlug.trim().isNotEmpty) {
        query['brand_slug'] = brandSlug.trim();
      }
      if (stock != 'all') {
        query['stock'] = stock;
      }
      if (orderBy == null && _shouldRequestInStockFirst(stock: stock)) {
        query['stock_order'] = 'in_first';
      }
      if (orderBy != null) {
        query['orderby'] = orderBy;
      }
      if (order != null) {
        query['order'] = order;
      }
      if (guest) {
        query['guest'] = 1;
      }

      final response = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: query,
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 304) {
        final rawProducts = _extractProductsData(response.data);
        debugPrint(
          '[REPO] getProducts(page: $page, cat: $categoryId, search: $search) -> Returned ${rawProducts.length} items',
        );
        if (rawProducts.isNotEmpty) {
          debugPrint(
            '[REPO] First product keys: ${rawProducts.first.keys.toList()}',
          );
          debugPrint(
            '[REPO] First product featured: ${rawProducts.first['featured']} / ${rawProducts.first['is_featured']}',
          );
        }

        // Background task: If this is the first page of a general query, refresh the local store.
        if (page == 1 &&
            categoryId == null &&
            search == null &&
            brandSlug == null) {
          _catalogLocalStore
              .cacheProducts(scope: scope, products: rawProducts)
              .catchError(
                (e) => debugPrint(
                  '[SYNC_ERROR] Background products cache failed: $e',
                ),
              );
        } else {
          await _catalogLocalStore.cacheProducts(
            scope: scope,
            products: rawProducts,
          );
        }

        return _toProductModels(
          rawProducts,
          context: 'getProducts:/dms/v1/products-plus',
        );
      }

      throw Exception('Failed to load products: ${response.statusCode}');
    } on DioException catch (e) {
      final fallback = _loadProductsFromLocal(
        scope: scope,
        page: page,
        perPage: perPage,
        categoryId: categoryId,
        search: search,
        brandSlug: brandSlug,
        stock: stock,
        sortBy: orderBy == 'price' ? 'price_$order' : orderBy,
      );
      if (fallback.isNotEmpty) {
        return fallback;
      }
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<List<ProductModel>> searchProductsWithFilters({
    required ProductSearchQuery query,
    bool guest = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    if (reachability.status == ReachabilityStatus.offline) {
      return _searchProductsFromLocal(scope: scope, query: query);
    }

    try {
      final params = <String, dynamic>{
        ...query.toQueryParameters(),
        ...await _userScopeQuery(guest: guest),
        'pricing_rev': _pricingRev,
        if (guest) 'guest': 1,
      };
      final hasExplicitOrdering =
          params['orderby'] != null &&
          params['orderby'].toString().trim().isNotEmpty;
      if (!params.containsKey('stock_order') &&
          !hasExplicitOrdering &&
          _shouldRequestInStockFirst(
            stock: (params['stock'] ?? params['stock_status'] ?? 'all')
                .toString(),
          )) {
        params['stock_order'] = 'in_first';
      }

      final response = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: params,
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 304) {
        final rawProducts = _extractProductsData(response.data);
        await _catalogLocalStore.cacheProducts(
          scope: scope,
          products: rawProducts,
        );
        return _toProductModels(
          rawProducts,
          context: 'searchProductsWithFilters:/dms/v1/products-plus',
        );
      }

      throw Exception(
        'Failed to load filtered products: ${response.statusCode}',
      );
    } on DioException catch (e) {
      final fallback = _searchProductsFromLocal(scope: scope, query: query);
      if (fallback.isNotEmpty) {
        return fallback;
      }
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<ProductModel?> getProductById(int id, {bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final local = _catalogLocalStore.getProductById(
      scope: scope,
      productId: id,
    );
    if (local != null && local.isNotEmpty) {
      return _tryParseProduct(local, context: 'getProductById:local-cache');
    }

    final products = await getProductsByIds(<int>[id], guest: guest);
    if (products.isEmpty) return null;
    return products.first;
  }

  Future<ProductModel?> getProductBySlug(
    String slug, {
    bool guest = false,
  }) async {
    if (slug.trim().isEmpty) return null;

    final localScope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    // Check local store first (as fallback/optimization)
    final local = _catalogLocalStore.getProductBySlug(
      scope: localScope,
      slug: slug,
    );
    if (local != null) {
      return _tryParseProduct(local, context: 'getProductBySlug:local-cache');
    }

    if (reachability.status == ReachabilityStatus.offline) {
      return null;
    }

    try {
      final query = <String, dynamic>{
        'slug': slug,
        'pricing_rev': _pricingRev,
        ...await _userScopeQuery(guest: guest),
        if (guest) 'guest': 1,
      };

      final response = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: query,
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      if (response.statusCode == 200) {
        final rawProducts = _extractProductsData(response.data);
        if (rawProducts.isNotEmpty) {
          final raw = rawProducts.first;
          await _catalogLocalStore.cacheProducts(
            scope: localScope,
            products: <Map<String, dynamic>>[raw],
          );
          return _tryParseProduct(raw, context: 'getProductBySlug:remote');
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<ProductModel>> getProductsByIds(
    List<int> ids, {
    bool guest = false,
  }) async {
    if (ids.isEmpty) {
      return <ProductModel>[];
    }

    final localScope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;
    if (reachability.status == ReachabilityStatus.offline) {
      return _catalogLocalStore
          .getProducts(scope: localScope, page: 1, perPage: 2000)
          .where((product) {
            final rawId = product['id'];
            final productId = rawId is int
                ? rawId
                : int.tryParse('${rawId ?? ''}');
            return productId != null && ids.contains(productId);
          })
          .map(
            (raw) =>
                _tryParseProduct(raw, context: 'getProductsByIds:offline-local'),
          )
          .whereType<ProductModel>()
          .toList(growable: false);
    }

    final scopeQuery = await _userScopeQuery(guest: guest);
    final response = await _dioClient.dio.get(
      '/dms/v1/products-plus',
      queryParameters: <String, dynamic>{
        'include': ids.join(','),
        'per_page': ids.length,
        'pricing_rev': _pricingRev,
        ...scopeQuery,
        if (guest) 'guest': 1,
      },
      options: _requestOptions(
        skipAuth: guest,
        cachePolicy: CachePolicy.noCache,
      ),
    );

    final rawProducts = _extractProductsData(response.data);
    await _catalogLocalStore.cacheProducts(
      scope: localScope,
      products: rawProducts,
    );
    return _toProductModels(
      rawProducts,
      context: 'getProductsByIds:/dms/v1/products-plus',
    );
  }

  Future<List<CategoryModel>> getCategories({bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    // Fast path: if we are definitely offline, return local immediately
    if (reachability.status == ReachabilityStatus.offline) {
      final local = _catalogLocalStore.getCategories(scope: scope);
      if (local.isNotEmpty) {
        return local
            .where((entry) => !_isCategoryHidden(entry))
            .map(CategoryModel.fromJson)
            .where((category) => category.name.isNotEmpty)
            .toList(growable: false);
      }
    }

    Future<List<CategoryModel>> fromEndpoint(
      String endpoint, {
      required bool skipAuth,
    }) async {
      final response = await _dioClient.dio.get(
        endpoint,
        queryParameters: <String, dynamic>{
          'per_page': AppConfig.categoriesPerPage,
          ...await _userScopeQuery(guest: guest),
          if (guest) 'guest': 1,
        },
        options: _requestOptions(
          skipAuth: skipAuth,
          cachePolicy: CachePolicy.noCache,
        ),
      );
      final payload = response.data;
      late final List<dynamic> list;
      try {
        list = ApiContract.expectList(
          payload,
          endpoint: endpoint,
          envelopeKeys: const <String>['data', 'items', 'categories'],
        );
      } on ApiContractException {
        if (payload is Map && payload.values.every((e) => e is Map)) {
          debugPrint(
            '[API_CONTRACT_WARNING] $endpoint returned map-object categories payload; applying compatibility normalization.',
          );
          list = payload.values.toList();
        } else {
          rethrow;
        }
      }

      return list
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) => !_isCategoryHidden(entry))
          .map(CategoryModel.fromJson)
          .where((category) => category.name.isNotEmpty)
          .toList();
    }

    try {
      final categories = await fromEndpoint(
        '/dms/v1/categories-guest',
        skipAuth: true,
      );
      await _catalogLocalStore.cacheCategories(
        scope: scope,
        categories: categories
            .map(
              (category) => <String, dynamic>{
                'id': category.id,
                'name': category.name,
                'slug': category.slug,
                'parent': category.parentId,
                'count': category.count,
                'image_url': category.imageUrl,
                'menu_order': category.menuOrder,
              },
            )
            .toList(growable: false),
      );
      return categories;
    } on DioException catch (_) {
      try {
        final categories = await fromEndpoint(
          '/dms/v1/categories',
          skipAuth: guest,
        );
        await _catalogLocalStore.cacheCategories(
          scope: scope,
          categories: categories
              .map(
                (category) => <String, dynamic>{
                  'id': category.id,
                  'name': category.name,
                  'slug': category.slug,
                  'parent': category.parentId,
                  'count': category.count,
                  'image_url': category.imageUrl,
                  'menu_order': category.menuOrder,
                },
              )
              .toList(growable: false),
        );
        return categories;
      } catch (_) {
        final local = _catalogLocalStore.getCategories(scope: scope);
        if (local.isNotEmpty) {
          return local
              .where((entry) => !_isCategoryHidden(entry))
              .map(CategoryModel.fromJson)
              .where((category) => category.name.isNotEmpty)
              .toList(growable: false);
        }
        rethrow;
      }
    }
  }

  Future<List<BrandModel>> getBrands({bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    if (reachability.status == ReachabilityStatus.offline) {
      final local = _catalogLocalStore.getBrands(scope: scope);
      if (local.isNotEmpty) {
        return local
            .where((entry) => !_isCategoryHidden(entry))
            .map(BrandModel.fromJson)
            .where((brand) => brand.name.isNotEmpty)
            .toList(growable: false);
      }
    }

    Future<List<BrandModel>> fromEndpoint(
      String endpoint, {
      required bool skipAuth,
    }) async {
      final response = await _dioClient.dio.get(
        endpoint,
        queryParameters: <String, dynamic>{
          'per_page': AppConfig.brandsPerPage,
          ...await _userScopeQuery(guest: guest),
          if (guest) 'guest': 1,
        },
        options: _requestOptions(
          skipAuth: skipAuth,
          cachePolicy: CachePolicy.noCache,
        ),
      );
      final payload = response.data;
      late final List<dynamic> list;
      try {
        list = ApiContract.expectList(
          payload,
          endpoint: endpoint,
          envelopeKeys: const <String>['data', 'items', 'brands'],
        );
      } on ApiContractException {
        if (payload is Map && payload.values.every((e) => e is Map)) {
          debugPrint(
            '[API_CONTRACT_WARNING] $endpoint returned map-object brands payload; applying compatibility normalization.',
          );
          list = payload.values.toList();
        } else {
          rethrow;
        }
      }

      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((entry) => !_isCategoryHidden(entry))
          .map(BrandModel.fromJson)
          .where((brand) => brand.name.isNotEmpty)
          .toList();
    }

    try {
      final brands = await fromEndpoint('/dms/v1/brands-guest', skipAuth: true);
      await _catalogLocalStore.cacheBrands(
        scope: scope,
        brands: brands
            .map(
              (brand) => <String, dynamic>{
                'id': brand.id,
                'name': brand.name,
                'slug': brand.slug,
                'count': brand.count,
                'image_url': brand.imageUrl,
                'show_in_app': true,
                'hidden': false,
              },
            )
            .toList(growable: false),
      );
      return brands;
    } on DioException catch (_) {
      try {
        final brands = await fromEndpoint('/dms/v1/brands', skipAuth: guest);
        await _catalogLocalStore.cacheBrands(
          scope: scope,
          brands: brands
              .map(
                (brand) => <String, dynamic>{
                  'id': brand.id,
                  'name': brand.name,
                  'slug': brand.slug,
                  'count': brand.count,
                  'image_url': brand.imageUrl,
                  'show_in_app': true,
                  'hidden': false,
                },
              )
              .toList(growable: false),
        );
        return brands;
      } catch (_) {
        final local = _catalogLocalStore.getBrands(scope: scope);
        if (local.isNotEmpty) {
          return local
              .where((entry) => !_isCategoryHidden(entry))
              .map(BrandModel.fromJson)
              .where((brand) => brand.name.isNotEmpty)
              .toList(growable: false);
        }
        rethrow;
      }
    }
  }

  Future<Set<int>> getCategoryIdsForBrand(
    String brandSlug, {
    bool guest = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    return _catalogLocalStore.getCategoryIdsForBrand(
      scope: scope,
      brandSlug: brandSlug,
    );
  }

  /// Synchronous version for UI filtering.
  /// Falls back to the most recently resolved scope if none is provided.
  Set<int> getActiveCategoryIdsForBrand(String brandSlug, {String? scope}) {
    final resolvedScope = (scope ?? _lastResolvedScope).trim().isEmpty
        ? 'guest'
        : (scope ?? _lastResolvedScope).trim();
    return _catalogLocalStore.getCategoryIdsForBrand(
      scope: resolvedScope,
      brandSlug: brandSlug,
    );
  }

  Future<HomeBannerData> getCachedHomeBannerData({bool guest = true}) async {
    final key = 'home_banner_${guest ? 'guest' : 'user'}';
    final raw = _storageService.settingsBox.get(key);
    if (raw is! String || raw.isEmpty) return const HomeBannerData.empty();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return HomeBannerData(
        enabled: map['enabled'] == true,
        imageUrl: map['image_url'] ?? '',
        title: map['title'] ?? '',
        subtitle: map['subtitle'] ?? '',
        buttonLabel: map['button_label'] ?? '',
        buttonLink: map['button_link'] ?? '',
        productIds: _parseProductIds(map['product_ids']),
      );
    } catch (_) {
      return const HomeBannerData.empty();
    }
  }

  Future<HomeBannerData> getHomeBannerData({bool guest = true}) async {
    final primary = await _fromHomeBannerEndpoint(guest: guest);
    HomeBannerData result = primary;

    if (!primary.hasImage) {
      final layoutBanner = await _fromHomeLayoutEndpoint(guest: guest);
      if (layoutBanner.hasImage) {
        result = layoutBanner.copyWith(
          title: primary.title.isNotEmpty ? primary.title : layoutBanner.title,
          subtitle: primary.subtitle.isNotEmpty
              ? primary.subtitle
              : layoutBanner.subtitle,
          buttonLabel: primary.buttonLabel.isNotEmpty
              ? primary.buttonLabel
              : layoutBanner.buttonLabel,
          buttonLink: primary.buttonLink.isNotEmpty
              ? primary.buttonLink
              : layoutBanner.buttonLink,
        );
      }
    }

    if (result.hasImage) {
      final key = 'home_banner_${guest ? 'guest' : 'user'}';
      await _storageService.settingsBox.put(
        key,
        jsonEncode({
          'enabled': result.enabled,
          'image_url': result.imageUrl,
          'title': result.title,
          'subtitle': result.subtitle,
          'button_label': result.buttonLabel,
          'button_link': result.buttonLink,
          'product_ids': result.productIds,
        }),
      );
    }

    return result;
  }

  Future<void> syncCatalogSnapshot({bool guest = true}) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;
    if (reachability.status == ReachabilityStatus.offline) {
      return;
    }

    try {
      // 1. Fetch Featured Products (High Priority)
      final featuredResponse = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: <String, dynamic>{
          'featured': 1,
          'per_page': 40,
          'pricing_rev': _pricingRev,
          ...await _userScopeQuery(guest: guest),
          if (guest) 'guest': 1,
        },
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );
      final featured = _extractProductsData(featuredResponse.data);
      debugPrint(
        '[SYNC] syncCatalogSnapshot FEATURED -> Found ${featured.length}',
      );
      if (featured.isNotEmpty) {
        await _catalogLocalStore.cacheProducts(
          scope: scope,
          products: featured,
        );
      }

      // 2. Fetch Latest Arrivals
      final latestResponse = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: <String, dynamic>{
          'orderby': 'date',
          'order': 'desc',
          'per_page': 80,
          'pricing_rev': _pricingRev,
          ...await _userScopeQuery(guest: guest),
          if (guest) 'guest': 1,
        },
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );
      final latest = _extractProductsData(latestResponse.data);
      if (latest.isNotEmpty) {
        await _catalogLocalStore.cacheProducts(scope: scope, products: latest);
      }
    } catch (e) {
      debugPrint('[SYNC_ERROR] Catalog snapshot failed: $e');
    }

    try {
      await getCategories(guest: guest);
    } catch (_) {}

    try {
      await getBrands(guest: guest);
    } catch (_) {}
  }

  Future<List<ProductModel>> getCachedProducts({
    int page = 1,
    int perPage = AppConfig.productsPerPage,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? sortBy,
    bool guest = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    return _loadProductsFromLocal(
      scope: scope,
      page: page,
      perPage: perPage,
      categoryId: categoryId,
      search: search,
      brandSlug: brandSlug,
      stock: stock,
      sortBy: sortBy,
    );
  }

  Future<List<CategoryModel>> getCachedCategories({bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final local = _catalogLocalStore.getCategories(scope: scope);
    return local
        .where((entry) => !_isCategoryHidden(entry))
        .map(CategoryModel.fromJson)
        .where((category) => category.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<BrandModel>> getCachedBrands({bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final local = _catalogLocalStore.getBrands(scope: scope);
    return local.map(BrandModel.fromJson).toList(growable: false);
  }

  Future<String> _scopeFor({required bool guest}) async {
    if (guest) {
      _lastResolvedScope = 'guest';
      return 'guest';
    }

    final user = await _storageService.getUser();
    if (user == null || user.isGuest) {
      _lastResolvedScope = 'guest';
      return 'guest';
    }

    if (user.id != null) {
      final scope = 'user_${user.id}';
      _lastResolvedScope = scope;
      return scope;
    }

    final username = user.username.trim().isEmpty
        ? 'unknown'
        : user.username.trim();
    final scope = 'user_$username';
    _lastResolvedScope = scope;
    return scope;
  }

  List<ProductModel> _loadProductsFromLocal({
    required String scope,
    required int page,
    required int perPage,
    required int? categoryId,
    required String? search,
    required String? brandSlug,
    required String stock,
    String? sortBy,
  }) {
    final local = _catalogLocalStore.getProducts(
      scope: scope,
      page: page,
      perPage: perPage,
      categoryId: categoryId,
      search: search,
      brandSlug: brandSlug,
      stock: stock,
      sortBy: sortBy,
    );
    return _toProductModels(local, context: 'getCachedProducts:local');
  }

  List<ProductModel> _searchProductsFromLocal({
    required String scope,
    required ProductSearchQuery query,
  }) {
    final rawBrandSlug = query.extraParams['brand_slug'];
    final brandSlug = rawBrandSlug?.toString().trim();
    final local = _catalogLocalStore.getProducts(
      scope: scope,
      page: query.page,
      perPage: query.perPage,
      categoryId: query.categoryIds.isEmpty ? null : query.categoryIds.first,
      search: query.search,
      brandSlug: brandSlug?.isEmpty ?? true ? null : brandSlug,
      stock: query.stockStatus == 'any' ? 'all' : query.stockStatus,
      sortBy: _mapSortOption(query.sortOption),
    );
    return _toProductModels(local, context: 'searchProductsFromLocal:local');
  }

  String _mapSortOption(ProductSortOption option) {
    switch (option) {
      case ProductSortOption.defaultOrder:
        return 'default';
      case ProductSortOption.priceLowToHigh:
        return 'price_asc';
      case ProductSortOption.priceHighToLow:
        return 'price_desc';
    }
  }

  bool _shouldRequestInStockFirst({required String stock}) {
    final normalized = stock.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'all' ||
        normalized == 'any' ||
        normalized == 'instock';
  }

  Future<Map<String, dynamic>> _userScopeQuery({required bool guest}) async {
    if (guest) return const <String, dynamic>{};

    final user = await _storageService.getUser();
    if (user == null || user.isGuest) {
      return const <String, dynamic>{};
    }

    final group = user.group.trim();
    final currency = AppCurrencies.normalizeCode(user.currency);

    return <String, dynamic>{
      if (group.isNotEmpty) 'user_group': group,
      'currency': currency,
    };
  }

  Future<HomeBannerData> _fromHomeBannerEndpoint({required bool guest}) async {
    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/home-banner',
        queryParameters: <String, dynamic>{if (guest) 'guest': 1},
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      final data = response.data;
      if (data is! Map) {
        return const HomeBannerData.empty();
      }

      final map = Map<String, dynamic>.from(data);
      final enabled = map['enabled'] == true;
      final image = _normalizeUrl(map['image_url']);
      if (!enabled) {
        return HomeBannerData(
          enabled: false,
          imageUrl: '',
          title: _normalizeText(map['title']),
          subtitle: _normalizeText(map['subtitle']),
          buttonLabel: _normalizeText(map['button_label']),
          buttonLink: _normalizeUrl(map['button_link']),
          productIds: _parseProductIds(map['product_ids']),
        );
      }

      return HomeBannerData(
        enabled: true,
        imageUrl: image,
        title: _normalizeText(map['title']),
        subtitle: _normalizeText(map['subtitle']),
        buttonLabel: _normalizeText(map['button_label']),
        buttonLink: _normalizeUrl(map['button_link']),
        productIds: _parseProductIds(map['product_ids']),
      );
    } catch (_) {
      return const HomeBannerData.empty();
    }
  }

  Future<HomeBannerData> _fromHomeLayoutEndpoint({required bool guest}) async {
    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/app/home-layout',
        queryParameters: <String, dynamic>{if (guest) 'guest': 1},
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      final payload = response.data;
      if (payload is! Map) {
        return const HomeBannerData.empty();
      }

      final root = Map<String, dynamic>.from(payload);
      final sections = root['sections'];
      if (sections is! List) {
        return const HomeBannerData.empty();
      }

      for (final raw in sections) {
        if (raw is! Map) continue;
        final section = Map<String, dynamic>.from(raw);
        final type = (section['type'] ?? '').toString().trim().toLowerCase();
        if (type != 'banner') continue;

        final image = _normalizeUrl(section['image']);
        if (image.isEmpty) continue;

        return HomeBannerData(
          enabled: true,
          imageUrl: image,
          title: _normalizeText(section['title']),
          subtitle: _normalizeText(section['subtitle']),
          buttonLabel: _normalizeText(section['button_label']),
          buttonLink: _normalizeUrl(section['link']),
          productIds: _parseProductIds(section['product_ids']),
        );
      }

      return const HomeBannerData.empty();
    } catch (_) {
      return const HomeBannerData.empty();
    }
  }

  Options _requestOptions({
    required bool skipAuth,
    CachePolicy? cachePolicy,
    Duration? maxStale,
  }) {
    return _dioClient.buildOptions(
      skipAuth: skipAuth,
      cachePolicy: cachePolicy,
      maxStale: maxStale,
    );
  }

  String _normalizeText(dynamic value) {
    return TextSanitizer.fix(value);
  }

  List<int> _parseProductIds(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) {
            if (item is int) return item;
            if (item is num) return item.toInt();
            return int.tryParse(item.toString().trim());
          })
          .whereType<int>()
          .toList(growable: false);
    }

    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return const <int>[];
      }

      return normalized
          .split(',')
          .map((item) => int.tryParse(item.trim()))
          .whereType<int>()
          .toList(growable: false);
    }

    return const <int>[];
  }

  bool _isCategoryHidden(Map<String, dynamic> raw) {
    const hideKeys = <String>[
      'dms_hide_in_app',
      'lpco_hide_in_app',
      'hide_in_app',
      'is_hidden',
      'hidden',
      'dms_hidden',
      'lpco_hidden',
      'app_hidden',
      'dms_app_hidden',
    ];
    for (final key in hideKeys) {
      if (_isTruthyFlag(raw[key])) {
        return true;
      }
    }

    const visibilityKeys = <String>[
      'visibility',
      'app_visibility',
      'dms_visibility',
    ];
    for (final key in visibilityKeys) {
      final value = '${raw[key] ?? ''}'.trim().toLowerCase();
      if (value.isEmpty) {
        continue;
      }
      if (const <String>{
        'hidden',
        'private',
        'none',
        'disabled',
        'off',
        '0',
        'false',
        'no',
      }.contains(value)) {
        return true;
      }
    }

    const showKeys = <String>[
      'show_in_app',
      'lpco_show_in_app',
      'dms_show_in_app',
    ];
    for (final key in showKeys) {
      if (!raw.containsKey(key)) {
        continue;
      }
      if (!_isTruthyFlag(raw[key])) {
        return true;
      }
    }

    return false;
  }

  bool _isTruthyFlag(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value > 0;
    }

    final normalized = '$value'.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null') {
      return false;
    }

    return const <String>{
      '1',
      'true',
      'yes',
      'on',
      'hide',
      'hidden',
      'private',
    }.contains(normalized);
  }

  String _normalizeUrl(dynamic value) {
    var url = (value ?? '').toString().trim();
    if (url.isEmpty) return '';

    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (url.startsWith('/')) {
      url = '${AppConfig.baseUrl}$url';
    }

    try {
      return Uri.parse(url).toString();
    } catch (_) {
      return url.replaceAll(' ', '%20');
    }
  }

  ProductModel? _tryParseProduct(
    Map<String, dynamic> raw, {
    required String context,
  }) {
    try {
      return ProductModel.fromJson(raw);
    } catch (error, stackTrace) {
      final id = raw['id'];
      debugPrint(
        '[PRODUCT_PARSE_GUARD] failed in $context for product id=$id: $error',
      );
      if (kDebugMode) {
        debugPrintStack(
          label: '[PRODUCT_PARSE_GUARD_STACK]',
          stackTrace: stackTrace,
        );
      }
      return null;
    }
  }

  List<ProductModel> _toProductModels(
    List<Map<String, dynamic>> rawProducts, {
    required String context,
  }) {
    final parsed = <ProductModel>[];
    for (final raw in rawProducts) {
      final model = _tryParseProduct(raw, context: context);
      if (model != null) {
        parsed.add(model);
      }
    }
    return parsed;
  }
}

List<Map<String, dynamic>> _extractProductsData(dynamic responseData) {
  final List<Map<String, dynamic>> parsed = <Map<String, dynamic>>[];
  if (responseData is List) {
    for (final item in responseData) {
      if (item is Map<String, dynamic>) {
        parsed.add(Map<String, dynamic>.from(item));
      } else if (item is Map) {
        parsed.add(Map<String, dynamic>.from(item));
      }
    }
    return parsed;
  }

  if (responseData is Map) {
    final map = Map<String, dynamic>.from(responseData);
    final dynamic data = map['items'] ?? map['data'] ?? map['products'];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          parsed.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          parsed.add(Map<String, dynamic>.from(item));
        }
      }
      return parsed;
    }

    if (map.values.every((e) => e is Map)) {
      debugPrint(
        '[API_CONTRACT_WARNING] /dms/v1/products-plus returned map-object payload; applying compatibility normalization.',
      );
      for (final item in map.values) {
        parsed.add(Map<String, dynamic>.from(item as Map));
      }
      return parsed;
    }

    throw const ApiContractException(
      ApiFailure(
        code: 'invalid_products_payload',
        message: 'صيغة بيانات المنتجات غير مدعومة.',
        status: 500,
        endpoint: '/dms/v1/products-plus',
      ),
    );
  }
  throw const ApiContractException(
    ApiFailure(
      code: 'invalid_products_payload',
      message: 'صيغة بيانات المنتجات غير مدعومة.',
      status: 500,
      endpoint: '/dms/v1/products-plus',
    ),
  );
}
