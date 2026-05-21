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
import 'package:lpco_llc/features/products/data/models/home_banner_model.dart';
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



class CatalogResponseMeta {
  final int page;
  final int perPage;
  final int count;
  final int? total;
  final int? totalPages;
  final String catalogRevision;

  const CatalogResponseMeta({
    required this.page,
    required this.perPage,
    required this.count,
    this.total,
    this.totalPages,
    this.catalogRevision = '',
  });

  bool get hasServerPaging => totalPages != null && totalPages! >= 0;

  bool get hasMore {
    if (totalPages != null) {
      return page < totalPages!;
    }
    return count >= perPage;
  }

  factory CatalogResponseMeta.fromJson(
    Map<String, dynamic> json, {
    required int fallbackPage,
    required int fallbackPerPage,
    required int fallbackCount,
  }) {
    return CatalogResponseMeta(
      page: _intFrom(json['page']) ?? fallbackPage,
      perPage: _intFrom(json['per_page']) ?? fallbackPerPage,
      count: _intFrom(json['count']) ?? fallbackCount,
      total: _intFrom(json['total']),
      totalPages: _intFrom(json['total_pages']),
      catalogRevision: (json['catalog_revision'] ?? '').toString(),
    );
  }
}

class CatalogProductsPage {
  final List<ProductModel> products;
  final CatalogResponseMeta meta;
  final bool fromLocalFallback;

  const CatalogProductsPage({
    required this.products,
    required this.meta,
    this.fromLocalFallback = false,
  });
}

class ProductRepository {
  final DioClient _dioClient;
  final StorageService _storageService = StorageService();
  final CatalogLocalStore _catalogLocalStore = CatalogLocalStore();
  final ReachabilityService _reachabilityService = ReachabilityService();
  static const String _pricingRev = ''; // Empty to force live data
  String _lastResolvedScope = 'guest';

  ProductRepository({DioClient? dioClient})
    : _dioClient = dioClient ?? DioClient();

  void invalidateCache() {
    // Cache invalidation no longer needed - removed static session-sensitive cache
  }

  Future<bool> syncCatalogRevision({bool guest = false}) async {
    final reachability = _reachabilityService.current;
    if (reachability.status == ReachabilityStatus.offline) {
      return false;
    }

    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/catalog-version',
        queryParameters: <String, dynamic>{
          '_t': DateTime.now().millisecondsSinceEpoch,
          if (guest) 'guest': 1,
        },
        options: _requestOptions(
          skipAuth: true,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      final payload = response.data;
      if (payload is! Map) {
        return false;
      }

      final map = Map<String, dynamic>.from(payload);
      final revision = (map['catalog_revision'] ?? '').toString().trim();
      if (revision.isEmpty) {
        return false;
      }

      const metaKey = 'catalog_revision::global';
      final previous = _storageService.readSyncMeta(metaKey);
      final previousRevision = (previous?['catalog_revision'] ?? '')
          .toString()
          .trim();
      if (previousRevision == revision) {
        return false;
      }

      await _catalogLocalStore.clearAllCatalogProducts();
      await _storageService.saveSyncMeta(metaKey, <String, dynamic>{
        'catalog_revision': revision,
        'products_updated_at': (map['products_updated_at'] ?? '').toString(),
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint(
          '[CATALOG_REVISION] changed $previousRevision -> $revision; cleared catalog product/category/brand cache.',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CATALOG_REVISION] check failed: $e');
      }
      return false;
    }
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
    bool forceRefresh = false,
  }) async {
    final result = await getProductsPage(
      page: page,
      perPage: perPage,
      categoryId: categoryId,
      search: search,
      brandSlug: brandSlug,
      stock: stock,
      orderBy: orderBy,
      order: order,
      guest: guest,
    );
    return result.products;
  }

  Future<CatalogProductsPage> getProductsPage({
    int page = 1,
    int perPage = AppConfig.productsPerPage,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? orderBy,
    String? order,
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;
    final normalizedBrandSlug = _normalizeBrandSlug(brandSlug);
    final hasBrandScope = normalizedBrandSlug != null;
    final hasSearch = search?.trim().isNotEmpty == true;
    final isBrandDefaultOrder = hasBrandScope && orderBy == null;
    final canCacheOrderedBrand =
        isBrandDefaultOrder &&
        page >= 1 &&
        categoryId == null &&
        !hasSearch &&
        _isAllStock(stock);

    if (reachability.status == ReachabilityStatus.offline) {
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
      return CatalogProductsPage(
        products: fallback,
        meta: CatalogResponseMeta(
          page: page,
          perPage: perPage,
          count: fallback.length,
        ),
        fromLocalFallback: true,
      );
    }

    try {
      final query = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'envelope': 1,
        'include_gallery': 1,
      };
      if (forceRefresh) {
        query['_t'] = DateTime.now().millisecondsSinceEpoch;
      }
      if (_pricingRev.isNotEmpty) {
        query['pricing_rev'] = _pricingRev;
      }
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
      if (orderBy == null &&
          !isBrandDefaultOrder &&
          _shouldRequestInStockFirst(stock: stock)) {
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

      if (kDebugMode && hasBrandScope) {
        debugPrint(
          '[BRAND_ORDER] request brand=$normalizedBrandSlug page=$page sortBy=${orderBy ?? 'default'}',
        );
      }

      final response = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: query,
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: forceRefresh ? CachePolicy.noCache : CachePolicy.noCache, // Wait, it already used noCache? No, wait, if it already uses noCache, that's fine, adding _t forces bypass.
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 304) {
        final parsedPage = _extractProductsPage(
          response.data,
          fallbackPage: page,
          fallbackPerPage: perPage,
        );
        final rawProducts = parsedPage.$1;
        final meta = parsedPage.$2;
        if (kDebugMode && hasBrandScope) {
          debugPrint(
            '[BRAND_ORDER] remote ids=${_idsForLog(_rawProductIds(rawProducts))} brand=$normalizedBrandSlug page=$page',
          );
        }
        if (rawProducts.isNotEmpty) {
          if (kDebugMode) {
            final first = rawProducts.first;
            debugPrint(
              '[REPO] getProducts page=$page count=${rawProducts.length} total=${meta.total} totalPages=${meta.totalPages} scope=${guest ? 'guest' : 'user'} params={cat:$categoryId, brand:$brandSlug, search:${search?.trim().isNotEmpty == true}}',
            );
            debugPrint(
              '[REPO] sample product id=${first['id']} sku=${first['sku']}',
            );
          }
        } else if (kDebugMode) {
          debugPrint(
            '[REPO] getProducts page=$page returned 0 products scope=${guest ? 'guest' : 'user'} params={cat:$categoryId, brand:$brandSlug, search:${search?.trim().isNotEmpty == true}}',
          );
        }

        // Background task: If this is the first page of a general query, refresh the local store.
        if (page == 1 &&
            categoryId == null &&
            search == null &&
            brandSlug == null) {
          _catalogLocalStore
              .cacheProducts(scope: scope, products: rawProducts)
              .catchError((e) {
                if (kDebugMode) {
                  debugPrint(
                    '[SYNC_ERROR] Background products cache failed: $e',
                  );
                }
              });
        } else {
          await _catalogLocalStore.cacheProducts(
            scope: scope,
            products: rawProducts,
            orderedBrandSlug: canCacheOrderedBrand ? normalizedBrandSlug : null,
            replaceOrderedBrandIndex: canCacheOrderedBrand && page == 1,
          );
        }

        final products = _toProductModels(
          rawProducts,
          context: 'getProductsPage:/dms/v1/products-plus',
        );
        return CatalogProductsPage(products: products, meta: meta);
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
        return CatalogProductsPage(
          products: fallback,
          meta: CatalogResponseMeta(
            page: page,
            perPage: perPage,
            count: fallback.length,
          ),
          fromLocalFallback: true,
        );
      }
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<List<ProductModel>> searchProductsWithFilters({
    required ProductSearchQuery query,
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    final result = await searchProductsWithFiltersPage(
      query: query,
      guest: guest,
      forceRefresh: forceRefresh,
    );
    return result.products;
  }

  Future<CatalogProductsPage> searchProductsWithFiltersPage({
    required ProductSearchQuery query,
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    if (reachability.status == ReachabilityStatus.offline) {
      final fallback = _searchProductsFromLocal(scope: scope, query: query);
      return CatalogProductsPage(
        products: fallback,
        meta: CatalogResponseMeta(
          page: query.page,
          perPage: query.perPage,
          count: fallback.length,
        ),
        fromLocalFallback: true,
      );
    }

    try {
      final params = <String, dynamic>{
        ...query.toQueryParameters(),
        ...await _userScopeQuery(guest: guest),
        'envelope': 1,
        'include_gallery': 1,
        if (guest) 'guest': 1,
      };
      if (forceRefresh) {
        params['_t'] = DateTime.now().millisecondsSinceEpoch;
      }
      if (_pricingRev.isNotEmpty) {
        params['pricing_rev'] = _pricingRev;
      }
      final hasExplicitOrdering =
          params['orderby'] != null &&
          params['orderby'].toString().trim().isNotEmpty;
      if (!params.containsKey('stock_order') &&
          !hasExplicitOrdering &&
          !_hasBrandScopeParam(params) &&
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
        final parsedPage = _extractProductsPage(
          response.data,
          fallbackPage: query.page,
          fallbackPerPage: query.perPage,
        );
        final rawProducts = parsedPage.$1;
        final meta = parsedPage.$2;
        final brandSlug = _brandScopeFromParams(params);
        if (kDebugMode && brandSlug != null) {
          debugPrint(
            '[BRAND_ORDER] remote ids=${_idsForLog(_rawProductIds(rawProducts))} brand=$brandSlug page=${query.page}',
          );
        }
        final canCacheOrderedBrandSearch =
            brandSlug != null && _isPlainDefaultBrandQuery(query);
        await _catalogLocalStore.cacheProducts(
          scope: scope,
          products: rawProducts,
          orderedBrandSlug: canCacheOrderedBrandSearch ? brandSlug : null,
          replaceOrderedBrandIndex:
              canCacheOrderedBrandSearch && query.page == 1,
        );
        if (kDebugMode) {
          debugPrint(
            '[REPO] search query="${query.search}" count=${rawProducts.length} total=${meta.total} page=${meta.page}/${meta.totalPages ?? 0} scope=${guest ? 'guest' : 'user'} params=$params',
          );
        }
        final products = _toProductModels(
          rawProducts,
          context: 'searchProductsWithFiltersPage:/dms/v1/products-plus',
        );
        return CatalogProductsPage(products: products, meta: meta);
      }

      throw Exception(
        'Failed to load filtered products: ${response.statusCode}',
      );
    } on DioException catch (e) {
      final fallback = _searchProductsFromLocal(scope: scope, query: query);
      if (fallback.isNotEmpty) {
        return CatalogProductsPage(
          products: fallback,
          meta: CatalogResponseMeta(
            page: query.page,
            perPage: query.perPage,
            count: fallback.length,
          ),
          fromLocalFallback: true,
        );
      }
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  /// Returns the number of products for a specific brand + category combination.
  /// Returns null if the count cannot be determined. Does not fail the UI.
  Future<int?> getBrandCategoryProductCount({
    required String brandSlug,
    required int categoryId,
    bool guest = true,
  }) async {
    try {
      final query = <String, dynamic>{
        'brand_slug': brandSlug.trim(),
        'category': categoryId,
        'per_page': 1,
        'page': 1,
        'envelope': 1,
        if (guest) 'guest': 1,
      };
      final response = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: query,
        options: _requestOptions(skipAuth: guest),
      );
      final meta = CatalogResponseMeta.fromJson(
        response.data,
        fallbackPage: 1,
        fallbackPerPage: 1,
        fallbackCount: 0,
      );
      return (meta.total ?? 0) > 0 ? meta.total : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProductModel?> getProductById(int id, {bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;
    if (reachability.status == ReachabilityStatus.offline) {
      final local = _catalogLocalStore.getProductById(
        scope: scope,
        productId: id,
      );
      if (local != null && local.isNotEmpty) {
        return _tryParseProduct(local, context: 'getProductById:local-cache');
      }
      return null;
    }

    try {
      final products = await getProductsByIds(
        <int>[id],
        guest: guest,
        includeGallery: true,
      );
      if (products.isNotEmpty) return products.first;
    } catch (_) {
      final local = _catalogLocalStore.getProductById(
        scope: scope,
        productId: id,
      );
      if (local != null && local.isNotEmpty) {
        return _tryParseProduct(
          local,
          context: 'getProductById:local-fallback',
        );
      }
    }
    return null;
  }

  Future<ProductModel?> getProductBySlug(
    String slug, {
    bool guest = false,
  }) async {
    if (slug.trim().isEmpty) return null;

    final localScope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    if (reachability.status == ReachabilityStatus.offline) {
      final local = _catalogLocalStore.getProductBySlug(
        scope: localScope,
        slug: slug,
      );
      return local == null
          ? null
          : _tryParseProduct(local, context: 'getProductBySlug:local-cache');
    }

    try {
      final query = <String, dynamic>{
        'slug': slug,
        'envelope': 1,
        'include_gallery': 1,
        ...await _userScopeQuery(guest: guest),
        if (guest) 'guest': 1,
      };
      if (_pricingRev.isNotEmpty) {
        query['pricing_rev'] = _pricingRev;
      }

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
      final local = _catalogLocalStore.getProductBySlug(
        scope: localScope,
        slug: slug,
      );
      return local == null
          ? null
          : _tryParseProduct(local, context: 'getProductBySlug:local-fallback');
    }
  }

  Future<List<ProductModel>> getProductsByIds(
    List<int> ids, {
    bool guest = false,
    bool includeGallery = false,
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
            (raw) => _tryParseProduct(
              raw,
              context: 'getProductsByIds:offline-local',
            ),
          )
          .whereType<ProductModel>()
          .toList(growable: false);
    }

    final scopeQuery = await _userScopeQuery(guest: guest);
    final query = <String, dynamic>{
      'include': ids.join(','),
      'per_page': ids.length,
      'envelope': 1,
      ...scopeQuery,
      if (guest) 'guest': 1,
      if (includeGallery) 'include_gallery': 1,
    };
    if (_pricingRev.isNotEmpty) {
      query['pricing_rev'] = _pricingRev;
    }

    final response = await _dioClient.dio.get(
      '/dms/v1/products-plus',
      queryParameters: query,
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

  Future<List<CategoryModel>> getCategories({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    // Fast path: if we are definitely offline, return local immediately
    if (reachability.status == ReachabilityStatus.offline && !forceRefresh) {
      final local = _catalogLocalStore.getCategories(scope: scope);
      if (local.isNotEmpty) {
        final categories = local
            .where((entry) => !_isCategoryHidden(entry))
            .map(CategoryModel.fromJson)
            .where((category) => category.name.isNotEmpty)
            .toList(growable: false);
        _logCategoryCounts('local cached', categories);
        return categories;
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
          if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
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
          if (kDebugMode) {
            debugPrint(
              '[API_CONTRACT_WARNING] $endpoint returned map-object categories payload; applying compatibility normalization.',
            );
          }
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
      _logCategoryCounts('remote', categories);
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
        _logCategoryCounts('remote', categories);
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
          final categories = local
              .where((entry) => !_isCategoryHidden(entry))
              .map(CategoryModel.fromJson)
              .where((category) => category.name.isNotEmpty)
              .toList(growable: false);
          _logCategoryCounts('local fallback', categories);
          return categories;
        }
        rethrow;
      }
    }
  }

  Future<List<BrandModel>> getBrands({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;

    if (reachability.status == ReachabilityStatus.offline && !forceRefresh) {
      final local = _catalogLocalStore.getBrands(scope: scope);
      if (local.isNotEmpty) {
        final brands = local
            .where((entry) => !_isCategoryHidden(entry))
            .map(BrandModel.fromJson)
            .where((brand) => brand.name.isNotEmpty)
            .toList(growable: false);
        _logBrandCounts('local cached', brands);
        return brands;
      }
    }

    Future<List<BrandModel>> fromEndpoint(
      String endpoint, {
      required bool skipAuth,
    }) async {
      final brands = <BrandModel>[];
      for (var page = 1; page <= 20; page += 1) {
        final response = await _dioClient.dio.get(
          endpoint,
          queryParameters: <String, dynamic>{
            'per_page': AppConfig.brandsPerPage,
            'page': page,
            ...await _userScopeQuery(guest: guest),
            if (guest) 'guest': 1,
            if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
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
            if (kDebugMode) {
              debugPrint(
                '[API_CONTRACT_WARNING] $endpoint returned map-object brands payload; applying compatibility normalization.',
              );
            }
            list = payload.values.toList();
          } else {
            rethrow;
          }
        }

        final pageBrands = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((entry) => !_isCategoryHidden(entry))
            .map(BrandModel.fromJson)
            .where((brand) => brand.name.isNotEmpty)
            .toList(growable: false);
        brands.addAll(pageBrands);

        if (list.length < AppConfig.brandsPerPage) {
          break;
        }
      }

      return brands;
    }

    Future<List<BrandModel>> fetchAndCache(
      String endpoint, {
      required bool skipAuth,
    }) async {
      final brands = await fromEndpoint(endpoint, skipAuth: skipAuth);
      _logBrandCounts('remote', brands);
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
                'linked_category_ids': brand.linkedCategoryIds,
                'linked_category_slugs': brand.linkedCategorySlugs,
                'show_in_app': true,
                'hidden': false,
              },
            )
            .toList(growable: false),
      );
      return brands;
    }

    try {
      if (guest) {
        return await fetchAndCache('/dms/v1/brands-guest', skipAuth: true);
      }
      return await fetchAndCache('/dms/v1/brands', skipAuth: false);
    } on DioException catch (_) {
      try {
        return await fetchAndCache(
          guest ? '/dms/v1/brands' : '/dms/v1/brands-guest',
          skipAuth: true,
        );
      } catch (_) {
        final local = _catalogLocalStore.getBrands(scope: scope);
        if (local.isNotEmpty) {
          final brands = local
              .where((entry) => !_isCategoryHidden(entry))
              .map(BrandModel.fromJson)
              .where((brand) => brand.name.isNotEmpty)
              .toList(growable: false);
          _logBrandCounts('local fallback', brands);
          return brands;
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

  Future<List<HomeBannerSlideData>> getCachedHomeBannersData({bool guest = true}) async {
    final key = 'home_banners_list_${guest ? 'guest' : 'user'}';
    final raw = _storageService.settingsBox.get(key);
    if (raw is! String || raw.isEmpty) return <HomeBannerSlideData>[];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map>().map((map) {
        return HomeBannerSlideData.fromJson(Map<String, dynamic>.from(map));
      }).toList();
    } catch (_) {
      return <HomeBannerSlideData>[];
    }
  }

  HomeBannerSlideData _parseSlideData(Map<String, dynamic> map, {bool defaultEnabled = true}) {
    if (!map.containsKey('enabled')) {
      map['enabled'] = defaultEnabled;
    }
    if (!map.containsKey('id')) {
      map['id'] = '${DateTime.now().microsecondsSinceEpoch}';
    }
    return HomeBannerSlideData.fromJson(map);
  }

  Future<List<HomeBannerSlideData>> getHomeBannersData({bool guest = true, bool forceRefresh = false}) async {
    final banners = <HomeBannerSlideData>[];

    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/home-banners', // First attempt the multi-banner endpoint
        queryParameters: <String, dynamic>{
          if (guest) 'guest': 1,
          if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: _requestOptions(skipAuth: guest, cachePolicy: CachePolicy.noCache),
      );
      final data = response.data;
      if (data is Map) {
        if (data.containsKey('items') && data['items'] is List) {
          banners.addAll((data['items'] as List).whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
        } else if (data.containsKey('banners') && data['banners'] is List) {
          banners.addAll((data['banners'] as List).whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
        } else if (data.containsKey('data') && data['data'] is List) {
          banners.addAll((data['data'] as List).whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
        }
      } else if (data is List) {
        banners.addAll(data.whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
      }
    } catch (_) {}

    // Fallback to legacy single banner endpoint if the list is empty
    if (banners.isEmpty) {
      try {
        final response = await _dioClient.dio.get(
          '/dms/v1/home-banner',
          queryParameters: <String, dynamic>{
            if (guest) 'guest': 1,
            if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
          },
          options: _requestOptions(skipAuth: guest, cachePolicy: CachePolicy.noCache),
        );
        final data = response.data;
        if (data is Map) {
          if (data.containsKey('items') && data['items'] is List) {
            banners.addAll((data['items'] as List).whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
          } else if (data.containsKey('banners') && data['banners'] is List) {
            banners.addAll((data['banners'] as List).whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
          } else if (data.containsKey('data') && data['data'] is List) {
            banners.addAll((data['data'] as List).whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
          } else {
            banners.add(_parseSlideData(Map<String, dynamic>.from(data)));
          }
        } else if (data is List) {
          banners.addAll(data.whereType<Map>().map((m) => _parseSlideData(Map<String, dynamic>.from(m))));
        }
      } catch (_) {}
    }

    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/app/home-layout',
        queryParameters: <String, dynamic>{
          if (guest) 'guest': 1,
          if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: _requestOptions(skipAuth: guest, cachePolicy: CachePolicy.noCache),
      );
      final data = response.data;
      if (data is Map && data['sections'] is List) {
        for (final raw in data['sections']) {
          if (raw is! Map) continue;
          final section = Map<String, dynamic>.from(raw);
          final type = (section['type'] ?? '').toString().trim().toLowerCase();
          if (type != 'banner') continue;
          banners.add(_parseSlideData(section, defaultEnabled: true));
        }
      }
    } catch (_) {}

    final enabledBanners = banners.where((b) => b.enabled).take(30).toList();

    if (enabledBanners.isNotEmpty) {
      final key = 'home_banners_list_${guest ? 'guest' : 'user'}';
      final listJson = enabledBanners.map((b) => b.toJson()).toList();
      await _storageService.settingsBox.put(key, jsonEncode(listJson));
      
      final first = enabledBanners.first;
      final oldKey = 'home_banner_${guest ? 'guest' : 'user'}';
      await _storageService.settingsBox.put(oldKey, jsonEncode(first.toJson()));
    }

    return enabledBanners;
  }

  Future<HomeBannerData> getHomeBannerData({bool guest = true, bool forceRefresh = false}) async {
    final primary = await _fromHomeBannerEndpoint(guest: guest, forceRefresh: forceRefresh);
    HomeBannerData result = primary;

    if (!primary.hasImage) {
      final layoutBanner = await _fromHomeLayoutEndpoint(guest: guest, forceRefresh: forceRefresh);
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

    final key = 'home_banner_${guest ? 'guest' : 'user'}';
    await _storageService.settingsBox.put(
      key,
      jsonEncode(<String, dynamic>{
        'enabled': result.enabled,
        'image_url': result.imageUrl,
        'title': result.title,
        'subtitle': result.subtitle,
        'button_label': result.buttonLabel,
        'button_link': result.buttonLink,
        'product_ids': result.productIds,
      }),
    );

    return result;
  }

  Future<void> syncCatalogSnapshot({bool guest = true}) async {
    final scope = await _scopeFor(guest: guest);
    final reachability = _reachabilityService.current;
    if (reachability.status == ReachabilityStatus.offline) {
      return;
    }

    try {
      await syncCatalogRevision(guest: guest);
      await _syncAllProductPages(scope: scope, guest: guest);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SYNC_ERROR] Catalog snapshot failed: $e');
      }
    }

    try {
      await getCategories(guest: guest);
    } catch (_) {}

    try {
      await getBrands(guest: guest);
    } catch (_) {}
  }

  Future<void> _syncAllProductPages({
    required String scope,
    required bool guest,
  }) async {
    const perPage = 100;
    var page = 1;
    var synced = 0;
    int? totalPages;

    while (true) {
      final params = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'orderby': 'date',
        'order': 'desc',
        'envelope': 1,
        'include_gallery': 1,
        ...await _userScopeQuery(guest: guest),
        if (guest) 'guest': 1,
      };
      if (_pricingRev.isNotEmpty) {
        params['pricing_rev'] = _pricingRev;
      }

      final response = await _dioClient.dio.get(
        '/dms/v1/products-plus',
        queryParameters: params,
        options: _requestOptions(
          skipAuth: guest,
          cachePolicy: CachePolicy.noCache,
        ),
      );

      final parsedPage = _extractProductsPage(
        response.data,
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
      final rawProducts = parsedPage.$1;
      final meta = parsedPage.$2;
      totalPages = meta.totalPages;

      if (rawProducts.isNotEmpty) {
        await _catalogLocalStore.cacheProducts(
          scope: scope,
          products: rawProducts,
        );
        synced += rawProducts.length;
      }

      if (kDebugMode) {
        debugPrint(
          '[SYNC] catalog page=$page count=${rawProducts.length} synced=$synced totalPages=${totalPages ?? 0} scope=$scope',
        );
      }

      final hasMore = totalPages != null
          ? page < totalPages
          : rawProducts.length >= perPage;
      if (!hasMore) {
        break;
      }
      page += 1;
      if (page > 200) {
        break;
      }
    }
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
    final categories = local
        .where((entry) => !_isCategoryHidden(entry))
        .map(CategoryModel.fromJson)
        .where((category) => category.name.isNotEmpty)
        .toList(growable: false);
    _logCategoryCounts('local cached', categories);
    return categories;
  }

  Future<List<BrandModel>> getCachedBrands({bool guest = false}) async {
    final scope = await _scopeFor(guest: guest);
    final local = _catalogLocalStore.getBrands(scope: scope);
    final brands = local.map(BrandModel.fromJson).toList(growable: false);
    _logBrandCounts('local cached', brands);
    return brands;
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

  bool _isAllStock(String stock) {
    final normalized = stock.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'all' || normalized == 'any';
  }

  String? _normalizeBrandSlug(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _hasBrandScopeParam(Map<String, dynamic> params) {
    return _brandScopeFromParams(params) != null;
  }

  String? _brandScopeFromParams(Map<String, dynamic> params) {
    final raw = params['brand_slug'];
    final normalized = raw?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _isPlainDefaultBrandQuery(ProductSearchQuery query) {
    final extraKeys = query.extraParams.keys
        .map((key) => key.trim().toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
    return query.sortOption == ProductSortOption.defaultOrder &&
        query.search.trim().isEmpty &&
        query.categoryIds.isEmpty &&
        query.minPrice == null &&
        query.maxPrice == null &&
        query.attributeFilter == null &&
        _isAllStock(query.stockStatus) &&
        extraKeys.difference(const <String>{'brand_slug'}).isEmpty;
  }

  Iterable<int> _rawProductIds(List<Map<String, dynamic>> products) {
    return products.map((raw) => _intFrom(raw['id'])).whereType<int>();
  }

  String _idsForLog(Iterable<int> ids) {
    const maxIds = 30;
    final values = ids.take(maxIds).toList(growable: false);
    final suffix = ids.length > maxIds ? ', ...' : '';
    return '[${values.join(',')}$suffix]';
  }

  void _logCategoryCounts(String source, List<CategoryModel> categories) {
    if (!kDebugMode) return;
    debugPrint(
      '[CATALOG_COUNTS] $source categories=${_categoryCountsForLog(categories)}',
    );
  }

  void _logBrandCounts(String source, List<BrandModel> brands) {
    if (!kDebugMode) return;
    debugPrint('[CATALOG_COUNTS] $source brands=${_brandCountsForLog(brands)}');
  }

  String _categoryCountsForLog(List<CategoryModel> categories) {
    const maxItems = 30;
    final values = categories
        .take(maxItems)
        .map((category) => '${category.id}:${category.count}')
        .toList(growable: false);
    final suffix = categories.length > maxItems ? ', ...' : '';
    return '[${values.join(',')}$suffix]';
  }

  String _brandCountsForLog(List<BrandModel> brands) {
    const maxItems = 30;
    final values = brands
        .take(maxItems)
        .map((brand) => '${brand.slug}:${brand.count}')
        .toList(growable: false);
    final suffix = brands.length > maxItems ? ', ...' : '';
    return '[${values.join(',')}$suffix]';
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

  Future<HomeBannerData> _fromHomeBannerEndpoint({required bool guest, bool forceRefresh = false}) async {
    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/home-banner',
        queryParameters: <String, dynamic>{
          if (guest) 'guest': 1,
          if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
        },
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

  Future<HomeBannerData> _fromHomeLayoutEndpoint({required bool guest, bool forceRefresh = false}) async {
    try {
      final response = await _dioClient.dio.get(
        '/dms/v1/app/home-layout',
        queryParameters: <String, dynamic>{
          if (guest) 'guest': 1,
          if (forceRefresh) '_t': DateTime.now().millisecondsSinceEpoch,
        },
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
      if (kDebugMode) {
        debugPrint(
          '[PRODUCT_PARSE_GUARD] failed in $context for product id=$id: $error',
        );
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

int? _intFrom(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

(List<Map<String, dynamic>>, CatalogResponseMeta) _extractProductsPage(
  dynamic responseData, {
  required int fallbackPage,
  required int fallbackPerPage,
}) {
  final products = _extractProductsData(responseData);
  Map<String, dynamic> metaMap = const <String, dynamic>{};
  if (responseData is Map) {
    final map = Map<String, dynamic>.from(responseData);
    final rawMeta = map['meta'];
    if (rawMeta is Map) {
      metaMap = Map<String, dynamic>.from(rawMeta);
    }
  }

  final meta = CatalogResponseMeta.fromJson(
    metaMap,
    fallbackPage: fallbackPage,
    fallbackPerPage: fallbackPerPage,
    fallbackCount: products.length,
  );
  return (products, meta);
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
      if (kDebugMode) {
        debugPrint(
          '[API_CONTRACT_WARNING] /dms/v1/products-plus returned map-object payload; applying compatibility normalization.',
        );
      }
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
