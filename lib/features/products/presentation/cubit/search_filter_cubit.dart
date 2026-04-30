import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

enum SearchFilterStatus { initial, loading, loaded, loadingMore, empty, error }

class AttributeTermOption {
  final String attribute;
  final String term;
  final String label;
  final String? colorHex;

  const AttributeTermOption({
    required this.attribute,
    required this.term,
    required this.label,
    this.colorHex,
  });

  String get key => '${attribute.toLowerCase()}|${term.toLowerCase()}';
}

class SearchFilterState {
  final SearchFilterStatus status;
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final List<AttributeTermOption> colorOptions;
  final List<AttributeTermOption> sizeOptions;
  final ProductSearchQuery query;
  final bool isGuest;
  final bool requireExplicitSearch;
  final bool hasMore;
  final String errorMessage;
  final List<String> recentSearches;
  final bool isTyping;
  final String userScope;

  const SearchFilterState({
    this.status = SearchFilterStatus.initial,
    this.products = const <ProductModel>[],
    this.categories = const <CategoryModel>[],
    this.colorOptions = const <AttributeTermOption>[],
    this.sizeOptions = const <AttributeTermOption>[],
    this.query = const ProductSearchQuery(),
    this.isGuest = true,
    this.requireExplicitSearch = false,
    this.hasMore = true,
    this.errorMessage = '',
    this.recentSearches = const <String>[],
    this.isTyping = false,
    this.userScope = 'guest',
  });

  bool get hasFiltersApplied {
    return query.search.trim().isNotEmpty ||
        query.minPrice != null ||
        query.maxPrice != null ||
        query.categoryIds.isNotEmpty ||
        query.attributeFilter != null ||
        query.stockStatus != 'any' ||
        query.sortOption != ProductSortOption.defaultOrder;
  }

  SearchFilterState copyWith({
    SearchFilterStatus? status,
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    List<AttributeTermOption>? colorOptions,
    List<AttributeTermOption>? sizeOptions,
    ProductSearchQuery? query,
    bool? isGuest,
    bool? requireExplicitSearch,
    bool? hasMore,
    String? errorMessage,
    List<String>? recentSearches,
    bool? isTyping,
    String? userScope,
  }) {
    return SearchFilterState(
      status: status ?? this.status,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      colorOptions: colorOptions ?? this.colorOptions,
      sizeOptions: sizeOptions ?? this.sizeOptions,
      query: query ?? this.query,
      isGuest: isGuest ?? this.isGuest,
      requireExplicitSearch:
          requireExplicitSearch ?? this.requireExplicitSearch,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      recentSearches: recentSearches ?? this.recentSearches,
      isTyping: isTyping ?? this.isTyping,
      userScope: userScope ?? this.userScope,
    );
  }
}

class SearchFilterCubit extends Cubit<SearchFilterState> {
  final ProductRepository _repository;
  final StorageService _storageService;

  Timer? _debounce;
  int _requestId = 0;
  String _activeCuratedCategorySlug = '';
  int? _activeCuratedCategoryId;
  String _activeCuratedCategoryLabel = '';

  /// The currently active curated category ID (for UI selection highlighting).
  int? get activeCuratedCategoryId => _activeCuratedCategoryId;

  static const Duration _searchDebounceDuration = Duration(milliseconds: 500);
  static const int _brandListingPerPage = 20;

  SearchFilterCubit({
    ProductRepository? repository,
    StorageService? storageService,
  }) : _repository = repository ?? ProductRepository(),
       _storageService = storageService ?? StorageService(),
       super(const SearchFilterState());

  void _emitSafe(SearchFilterState next) {
    if (!isClosed) {
      emit(next);
    }
  }

  Future<void> initialize({
    bool isGuest = true,
    Map<String, dynamic> extraParams = const <String, dynamic>{},
    List<int> initialCategoryIds = const <int>[],
    String? initialCuratedCategorySlug,
    String? initialCuratedCategoryLabel,
    String initialSearch = '',
    int? initialPerPage,
    bool requireExplicitSearch = false,
  }) async {
    final shouldAutoSearch = !requireExplicitSearch;
    final hasBrandScope = _hasBrandScope(extraParams);
    final resolvedPerPage = initialPerPage != null && initialPerPage > 0
        ? initialPerPage
        : (hasBrandScope ? _brandListingPerPage : state.query.perPage);
    _activeCuratedCategorySlug = _normalizeCategorySlug(
      initialCuratedCategorySlug,
    );
    _activeCuratedCategoryLabel = initialCuratedCategoryLabel?.trim() ?? '';
    var initialQuery = state.query.copyWith(
      page: 1,
      search: initialSearch.trim(),
      perPage: resolvedPerPage,
      extraParams: extraParams,
      categoryIds: initialCategoryIds,
    );

    _emitSafe(
      state.copyWith(
        status: shouldAutoSearch
            ? SearchFilterStatus.loading
            : SearchFilterStatus.initial,
        isGuest: isGuest,
        requireExplicitSearch: requireExplicitSearch,
        query: initialQuery,
        hasMore: shouldAutoSearch,
        errorMessage: '',
        isTyping: false,
      ),
    );

    final scope = await _resolveUserScope(isGuest);
    List<CategoryModel> categories = state.categories;
    try {
      categories = await _repository.getCategories(guest: isGuest);
    } catch (_) {}

    final normalizedCuratedSlug = _activeCuratedCategorySlug;
    if (categories.isNotEmpty) {
      CategoryModel? matchedCategory;
      final targetIdFromQuery =
          (initialQuery.categoryIds.isNotEmpty &&
              initialQuery.categoryIds.first > 0)
          ? initialQuery.categoryIds.first
          : null;

      // 1. Try to match by ID first (most precise)
      if (targetIdFromQuery != null) {
        for (final category in categories) {
          if (category.id == targetIdFromQuery) {
            matchedCategory = category;
            break;
          }
        }
      }

      // 2. Try to match by Slug if ID didn't work or wasn't provided
      if (matchedCategory == null && normalizedCuratedSlug.isNotEmpty) {
        for (final category in categories) {
          if (_normalizeCategorySlug(category.slug) == normalizedCuratedSlug) {
            matchedCategory = category;
            break;
          }
        }
      }

      if (matchedCategory != null) {
        if (hasBrandScope) {
          _activeCuratedCategoryId = matchedCategory.id;
          _activeCuratedCategorySlug = _normalizeCategorySlug(
            matchedCategory.slug,
          );
          _activeCuratedCategoryLabel =
              initialCuratedCategoryLabel?.trim().isNotEmpty == true
              ? initialCuratedCategoryLabel!.trim()
              : matchedCategory.name.trim();
          initialQuery = initialQuery.copyWith(
            categoryIds: <int>[matchedCategory.id],
          );
          debugPrint(
            '🎯 CuratedCategory RESOLVED: ID=${matchedCategory.id}, Slug=${matchedCategory.slug}',
          );
        } else if (initialQuery.categoryIds.isEmpty &&
            normalizedCuratedSlug.isNotEmpty) {
          initialQuery = initialQuery.copyWith(
            categoryIds: <int>[matchedCategory.id],
          );
        }
      }
    }

    if (isClosed) return;

    _emitSafe(
      state.copyWith(
        status: shouldAutoSearch
            ? SearchFilterStatus.loading
            : SearchFilterStatus.initial,
        isGuest: isGuest,
        userScope: scope,
        requireExplicitSearch: requireExplicitSearch,
        query: initialQuery,
        categories: categories,
        hasMore: shouldAutoSearch,
        errorMessage: '',
        isTyping: false,
        recentSearches: _storageService.getRecentSearches(
          limit: 5,
          userScope: scope,
        ),
      ),
    );

    if (requireExplicitSearch) {
      return;
    }
    await search(reset: true, persistRecent: false);
  }

  Future<void> refresh() async {
    await search(reset: true);
  }

  void onSearchChanged(String value) {
    if (isClosed) return;
    final normalized = value.trim();
    final params = Map<String, dynamic>.from(state.query.extraParams)
      ..remove('sku')
      ..remove('barcode');
    _emitSafe(
      state.copyWith(
        query: state.query.copyWith(
          search: normalized,
          page: 1,
          extraParams: params,
        ),
        isTyping: true,
      ),
    );

    _debounce?.cancel();
    _debounce = Timer(_searchDebounceDuration, () async {
      await search(reset: true);
      _emitSafe(state.copyWith(isTyping: false));
    });
  }

  Future<void> submitSearch(String value) async {
    if (isClosed) return;
    _debounce?.cancel();
    final params = Map<String, dynamic>.from(state.query.extraParams)
      ..remove('sku')
      ..remove('barcode');
    _emitSafe(
      state.copyWith(
        query: state.query.copyWith(
          search: value.trim(),
          page: 1,
          extraParams: params,
        ),
        isTyping: false,
      ),
    );
    await search(reset: true);
  }

  Future<void> submitBarcodeSearch(String code) async {
    if (isClosed) return;
    _debounce?.cancel();
    final normalized = code.trim();
    if (normalized.isEmpty) return;

    final params = Map<String, dynamic>.from(state.query.extraParams)
      ..['sku'] = normalized
      ..['barcode'] = normalized;

    _emitSafe(
      state.copyWith(
        query: state.query.copyWith(
          search: normalized,
          page: 1,
          extraParams: params,
        ),
        isTyping: false,
      ),
    );

    await search(reset: true);
  }

  Future<void> useRecentSearch(String term) async {
    await submitSearch(term);
  }

  Future<void> applyFilters({
    num? minPrice,
    bool clearMinPrice = false,
    num? maxPrice,
    bool clearMaxPrice = false,
    List<int>? categoryIds,
    AttributeTermFilter? attributeFilter,
    bool clearAttributeFilter = false,
    String? stockStatus,
    ProductSortOption? sortOption,
  }) async {
    if (isClosed) return;
    if (categoryIds != null) {
      _activeCuratedCategorySlug = '';
      _activeCuratedCategoryId = null;
      _activeCuratedCategoryLabel = '';
    }
    final updatedQuery = state.query.copyWith(
      minPrice: minPrice,
      clearMinPrice: clearMinPrice,
      maxPrice: maxPrice,
      clearMaxPrice: clearMaxPrice,
      categoryIds: categoryIds ?? state.query.categoryIds,
      attributeFilter: attributeFilter,
      clearAttributeFilter: clearAttributeFilter,
      stockStatus: stockStatus,
      sortOption: sortOption,
      page: 1,
    );

    _emitSafe(state.copyWith(query: updatedQuery));
    await search(reset: true);
  }

  Future<void> applyCuratedCategory(
    int? categoryId, {
    String? categorySlug,
    String? labelAr,
  }) async {
    if (isClosed) return;

    if (categoryId != null && categoryId > 0) {
      // Use client-side filtering instead of sending category to the API.
      // Some brands have brand-specific category slugs on WooCommerce but
      // the products aren't assigned to those sub-categories — combining
      // brand_slug + category in the API query returns 0 results.
      // By keeping only brand_slug in the API query we get all brand products,
      // then _applyScopedFilters filters by category locally using a 3-tier
      // strategy: ID → slug → Arabic name matching.
      _activeCuratedCategorySlug = _normalizeCategorySlug(categorySlug ?? '');
      _activeCuratedCategoryId = categoryId;
      _activeCuratedCategoryLabel = labelAr?.trim() ?? '';
    } else {
      _activeCuratedCategorySlug = '';
      _activeCuratedCategoryId = null;
      _activeCuratedCategoryLabel = '';
    }

    final updatedQuery = state.query.copyWith(
      categoryIds: categoryId != null && categoryId > 0
          ? <int>[categoryId]
          : const <int>[],
      page: 1,
    );

    _emitSafe(state.copyWith(query: updatedQuery));
    await search(reset: true);
  }

  Future<void> clearAllFilters() async {
    if (isClosed) return;
    _activeCuratedCategorySlug = '';
    _activeCuratedCategoryId = null;
    _activeCuratedCategoryLabel = '';
    final resetQuery = ProductSearchQuery(
      search: state.query.search,
      page: 1,
      perPage: state.query.perPage,
      extraParams: state.query.extraParams,
    );
    _emitSafe(state.copyWith(query: resetQuery));
    await search(reset: true);
  }

  Future<void> loadMore() async {
    if (state.status == SearchFilterStatus.loadingMore || !state.hasMore) {
      return;
    }

    final nextQuery = state.query.copyWith(page: state.query.page + 1);
    _emitSafe(
      state.copyWith(
        status: SearchFilterStatus.loadingMore,
        query: nextQuery,
        errorMessage: '',
      ),
    );

    await search(reset: false);
  }

  Future<void> loadRecentSearches() async {
    _emitSafe(
      state.copyWith(
        recentSearches: _storageService.getRecentSearches(
          limit: 5,
          userScope: state.userScope,
        ),
      ),
    );
  }

  Future<void> removeRecentSearch(String term) async {
    await _storageService.removeRecentSearch(term, userScope: state.userScope);
    await loadRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    await _storageService.clearRecentSearches(userScope: state.userScope);
    _emitSafe(state.copyWith(recentSearches: const <String>[]));
  }

  Future<void> search({required bool reset, bool persistRecent = true}) async {
    if (isClosed) return;
    final runId = ++_requestId;
    final requestQuery = reset ? state.query.copyWith(page: 1) : state.query;
    if (reset &&
        state.requireExplicitSearch &&
        !_hasSearchIntent(requestQuery)) {
      _emitSafe(
        state.copyWith(
          status: SearchFilterStatus.initial,
          products: const <ProductModel>[],
          query: requestQuery,
          hasMore: false,
          colorOptions: const <AttributeTermOption>[],
          sizeOptions: const <AttributeTermOption>[],
          errorMessage: '',
          isTyping: false,
        ),
      );
      return;
    }

    if (reset) {
      _emitSafe(
        state.copyWith(
          status: SearchFilterStatus.loading,
          query: requestQuery,
          hasMore: true,
          errorMessage: '',
        ),
      );
    }

    try {
      final fetched = await _fetchProductsForQuery(
        _queryForRepository(requestQuery),
      );

      if (runId != _requestId || isClosed) {
        return;
      }

      final strictSearch = _shouldUseStrictSearch(requestQuery);
      final searchedProducts = strictSearch
          ? _applyStrictSearchFilter(fetched, requestQuery.search)
          : fetched;
      final effectiveFetched = _applyScopedFilters(
        searchedProducts,
        requestQuery,
      );

      final previousProducts = reset ? const <ProductModel>[] : state.products;
      final merged = _mergeUniqueProducts(previousProducts, effectiveFetched);
      final sorted = _sortProducts(merged, requestQuery.sortOption);
      final extractedAttributes = _extractAttributeOptions(merged);
      final hasMore = fetched.length >= requestQuery.perPage;
      final status = merged.isEmpty
          ? SearchFilterStatus.empty
          : SearchFilterStatus.loaded;

      _emitSafe(
        state.copyWith(
          status: status,
          products: sorted,
          query: requestQuery,
          hasMore: hasMore,
          colorOptions: extractedAttributes.$1,
          sizeOptions: extractedAttributes.$2,
          errorMessage: '',
        ),
      );

      if (persistRecent && requestQuery.search.trim().isNotEmpty) {
        await _storageService.saveRecentSearch(
          requestQuery.search,
          maxItems: 5,
          userScope: state.userScope,
        );
        if (runId == _requestId && !isClosed) {
          _emitSafe(
            state.copyWith(
              recentSearches: _storageService.getRecentSearches(
                limit: 5,
                userScope: state.userScope,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (runId != _requestId || isClosed) {
        return;
      }
      final errorMessage = ApiContract.safeMessageFromException(e);
      if (!reset && state.products.isNotEmpty) {
        _emitSafe(
          state.copyWith(
            status: SearchFilterStatus.loaded,
            hasMore: false,
            errorMessage: errorMessage,
          ),
        );
        return;
      }
      _emitSafe(
        state.copyWith(
          status: SearchFilterStatus.error,
          errorMessage: errorMessage,
        ),
      );
    }
  }

  bool _hasSearchIntent(ProductSearchQuery query) {
    final hasText = query.search.trim().isNotEmpty;
    if (hasText) {
      return true;
    }

    final hasFilter =
        query.minPrice != null ||
        query.maxPrice != null ||
        query.categoryIds.isNotEmpty ||
        query.attributeFilter != null ||
        query.stockStatus != 'any' ||
        query.sortOption != ProductSortOption.defaultOrder;
    if (hasFilter) {
      return true;
    }

    for (final entry in query.extraParams.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      final value = '${entry.value ?? ''}'.trim();
      if (value.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _shouldUseStrictSearch(ProductSearchQuery query) {
    final raw = query.search.trim();
    if (raw.length < 2) {
      return false;
    }
    final hasBarcodeLookup = query.extraParams.containsKey('barcode');
    final hasSkuLookup = query.extraParams.containsKey('sku');
    return !(hasBarcodeLookup || hasSkuLookup);
  }

  List<ProductModel> _applyStrictSearchFilter(
    List<ProductModel> products,
    String rawSearch,
  ) {
    final normalizedQuery = _normalizeSearchText(rawSearch);
    if (normalizedQuery.isEmpty) {
      return products;
    }

    final terms = normalizedQuery
        .split(' ')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) {
      return products;
    }

    final strongMatches = products
        .where((product) {
          final searchable = <String>[
            product.name,
            product.sku,
            product.slug,
            ..._barcodeMetaValues(product),
          ];

          for (final rawField in searchable) {
            final field = _normalizeSearchText(rawField);
            if (field.isEmpty) {
              continue;
            }
            if (terms.every(field.contains)) {
              return true;
            }
          }
          return false;
        })
        .toList(growable: false);

    if (strongMatches.isNotEmpty) {
      return strongMatches;
    }

    return products
        .where((product) {
          for (final category in product.categories) {
            final normalizedCategory = _normalizeSearchText(category.name);
            if (normalizedCategory.isEmpty) {
              continue;
            }
            if (terms.every(normalizedCategory.contains)) {
              return true;
            }
          }
          return false;
        })
        .toList(growable: false);
  }

  List<String> _barcodeMetaValues(ProductModel product) {
    final values = <String>[];
    for (final meta in product.metaData) {
      final key = meta.key.toLowerCase();
      if (key.contains('barcode') ||
          key.contains('sku') ||
          key.contains('code')) {
        values.add('${meta.value ?? ''}');
      }
    }
    return values;
  }

  String _normalizeSearchText(String value) {
    var normalized = value.toLowerCase().trim();
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
        .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
  }

  String _normalizeCategorySlug(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  bool _hasBrandScope(Map<String, dynamic> extraParams) {
    final brandSlug = '${extraParams['brand_slug'] ?? ''}'.trim();
    return brandSlug.isNotEmpty;
  }

  bool _hasCuratedSelection(ProductSearchQuery query) {
    return query.categoryIds.any((id) => id > 0) ||
        (_activeCuratedCategoryId != null && _activeCuratedCategoryId! > 0) ||
        _activeCuratedCategorySlug.isNotEmpty ||
        _activeCuratedCategoryLabel.isNotEmpty;
  }

  ProductSearchQuery _queryForRepository(ProductSearchQuery query) {
    if (!_hasBrandScope(query.extraParams)) {
      return query;
    }
    if (!_hasCuratedSelection(query)) {
      return query;
    }

    // Keep selected category in UI state while avoiding backend over-filtering
    // for brand-scoped curated menus with inconsistent taxonomy mapping.
    return query.copyWith(categoryIds: const <int>[]);
  }

  Future<List<ProductModel>> _fetchProductsForQuery(
    ProductSearchQuery requestQuery,
  ) async {
    return _repository.searchProductsWithFilters(
      query: requestQuery,
      guest: state.isGuest,
    );
  }

  List<ProductModel> _applyScopedFilters(
    List<ProductModel> products,
    ProductSearchQuery query,
  ) {
    if (products.isEmpty) {
      return products;
    }

    var filtered = products;
    final normalizedBrandSlug = '${query.extraParams['brand_slug'] ?? ''}'
        .trim()
        .toLowerCase();
    if (normalizedBrandSlug.isNotEmpty) {
      filtered = filtered
          .where((product) {
            final productBrandSlug = product.brand?.slug.trim().toLowerCase();
            if (productBrandSlug == null || productBrandSlug.isEmpty) {
              return true;
            }
            return productBrandSlug == normalizedBrandSlug;
          })
          .toList(growable: false);
      if (filtered.isEmpty) {
        return filtered;
      }
    }

    final normalizedCategoryIds = query.categoryIds
        .where((id) => id > 0)
        .toSet();
    final hasBrandScope = _hasBrandScope(query.extraParams);
    if (normalizedCategoryIds.isNotEmpty && !hasBrandScope) {
      filtered = filtered
          .where(
            (product) => product.categories.any(
              (category) => normalizedCategoryIds.contains(category.id),
            ),
          )
          .toList(growable: false);
      return filtered;
    }
    if (normalizedCategoryIds.isNotEmpty && hasBrandScope) {
      _activeCuratedCategoryId = normalizedCategoryIds.first;
    }

    // Client-side curated category filtering.
    // 4-tier strategy: ID (with hierarchy) → slug (with hierarchy) → Arabic name matching → Name Fallback.
    final hasCuratedFilter =
        (_activeCuratedCategoryId != null && _activeCuratedCategoryId! > 0) ||
        _activeCuratedCategorySlug.isNotEmpty ||
        _activeCuratedCategoryLabel.isNotEmpty;

    if (!hasCuratedFilter) {
      return filtered;
    }

    // Tier 1: Match by category ID (inclusive of descendants).
    if (_activeCuratedCategoryId != null && _activeCuratedCategoryId! > 0) {
      final targetId = _activeCuratedCategoryId!;
      final byId = filtered
          .where((product) {
            return product.categories.any((cRef) {
              if (cRef.id == targetId) return true;
              // Check if curated category is an ancestor of this product's category
              return _getCategoryAncestry(cRef.id).contains(targetId);
            });
          })
          .toList(growable: false);

      if (byId.isNotEmpty) {
        debugPrint(
          '✅ ScopedFilter: Tier 1 (ID + Hierarchy) matched ${byId.length} products for ID: $targetId',
        );
        return byId;
      }
    }

    // Tier 2: Match by category slug (inclusive of descendants).
    if (_activeCuratedCategorySlug.isNotEmpty) {
      final bySlug = filtered
          .where((product) {
            return product.categories.any((cRef) {
              final normalizedRefSlug = _normalizeCategorySlug(cRef.slug);
              if (normalizedRefSlug == _activeCuratedCategorySlug) return true;

              // Hierarchy check via slug: If we find the CategoryModel for this ref, check its ancestry
              final catModel = _findCategoryById(cRef.id);
              if (catModel != null) {
                final ancestry = _getCategoryAncestry(catModel.id);
                return ancestry.any((ancestorId) {
                  final ancestor = _findCategoryById(ancestorId);
                  return ancestor != null &&
                      _normalizeCategorySlug(ancestor.slug) ==
                          _activeCuratedCategorySlug;
                });
              }
              return false;
            });
          })
          .toList(growable: false);

      if (bySlug.isNotEmpty) {
        debugPrint(
          '✅ ScopedFilter: Tier 2 (Slug + Hierarchy) matched ${bySlug.length} products for slug: $_activeCuratedCategorySlug',
        );
        return bySlug;
      }
    }

    // Tier 3: Match by Arabic category name.
    // Products are often in generic categories (e.g. 'محايات') rather than
    // brand-specific ones (e.g. 'zidny-erasers'). Name matching bridges this.
    if (_activeCuratedCategoryLabel.isNotEmpty) {
      final label = _normalizeArabic(_activeCuratedCategoryLabel);
      final byName = filtered
          .where(
            (product) => product.categories.any((c) {
              final name = _normalizeArabic(c.name);
              if (name.isEmpty) return false;
              return name == label ||
                  name.contains(label) ||
                  label.contains(name);
            }),
          )
          .toList(growable: false);
      if (byName.isNotEmpty) {
        debugPrint(
          '🔍 ScopedFilter: Curated filter matched ${byName.length} products by Name: $_activeCuratedCategoryLabel',
        );
        return byName;
      }
    }

    // Tier 4: Radical Safety Net - Match by Product Name.
    // If the item is in the brand scope and specifically mentions the curated category label.
    if (_activeCuratedCategoryLabel.isNotEmpty) {
      final label = _normalizeArabic(_activeCuratedCategoryLabel);
      final byProductName = filtered
          .where((product) {
            final name = _normalizeArabic(product.name);
            return name.contains(label);
          })
          .toList(growable: false);

      if (byProductName.isNotEmpty) {
        debugPrint(
          '✅ ScopedFilter: Tier 4 (Name Fallback) matched ${byProductName.length} products for label: $_activeCuratedCategoryLabel',
        );
        return byProductName;
      }
    }

    // All tiers failed — curated filter is active but no products match.
    // Output deep diagnostic logs if we have products that were rejected.
    if (filtered.isNotEmpty) {
      debugPrint('❌ ScopedFilter: FAILED to match any Tier. FilterContext:');
      debugPrint('   - ActiveID: $_activeCuratedCategoryId');
      debugPrint('   - ActiveSlug: $_activeCuratedCategorySlug');
      debugPrint('   - ActiveLabel: $_activeCuratedCategoryLabel');

      final firstP = filtered.first;
      final pCats = firstP.categories
          .map((c) => '${c.name}(${c.id})')
          .join(', ');
      debugPrint(
        '   - Sample Rejected Product: ${firstP.name} (SKU: ${firstP.sku})',
      );
      debugPrint('   - Product Categories: $pCats');

      for (final cRef in firstP.categories) {
        final ancestry = _getCategoryAncestry(cRef.id).join(', ');
        debugPrint('     * Ancestry for ${cRef.id}: [$ancestry]');
      }
    }

    return const <ProductModel>[];
  }

  Set<int> _getCategoryAncestry(int categoryId) {
    final ancestry = <int>{};
    var currentId = categoryId;

    // Avoid infinite loops in case of malformed data
    int safetyMaxDepth = 10;
    while (currentId > 0 && safetyMaxDepth-- > 0) {
      final model = _findCategoryById(currentId);
      if (model == null) break;

      ancestry.add(model.id);
      if (model.parentId <= 0 || model.parentId == currentId) break;
      currentId = model.parentId;
    }
    return ancestry;
  }

  CategoryModel? _findCategoryById(int id) {
    for (final cat in state.categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _requestId++;
    return super.close();
  }

  List<ProductModel> _mergeUniqueProducts(
    List<ProductModel> base,
    List<ProductModel> incoming,
  ) {
    if (incoming.isEmpty) {
      return base;
    }

    final ids = base.map((product) => product.id).toSet();
    final merged = <ProductModel>[...base];
    for (final product in incoming) {
      if (ids.contains(product.id)) {
        continue;
      }
      ids.add(product.id);
      merged.add(product);
    }
    return merged;
  }

  (List<AttributeTermOption>, List<AttributeTermOption>)
  _extractAttributeOptions(List<ProductModel> products) {
    final colorMap = <String, AttributeTermOption>{};
    final sizeMap = <String, AttributeTermOption>{};

    void addColor({
      required String attribute,
      required String term,
      required String label,
      String? colorHex,
    }) {
      final normalizedAttribute = attribute.trim();
      final normalizedTerm = term.trim();
      final normalizedLabel = label.trim();
      if (normalizedAttribute.isEmpty ||
          normalizedTerm.isEmpty ||
          normalizedLabel.isEmpty) {
        return;
      }
      final option = AttributeTermOption(
        attribute: normalizedAttribute,
        term: normalizedTerm,
        label: normalizedLabel,
        colorHex: _normalizeHexColor(colorHex),
      );
      colorMap[option.key] = option;
    }

    void addSize({
      required String attribute,
      required String term,
      required String label,
    }) {
      final normalizedAttribute = attribute.trim();
      final normalizedTerm = term.trim();
      final normalizedLabel = label.trim();
      if (normalizedAttribute.isEmpty ||
          normalizedTerm.isEmpty ||
          normalizedLabel.isEmpty) {
        return;
      }
      final option = AttributeTermOption(
        attribute: normalizedAttribute,
        term: normalizedTerm,
        label: normalizedLabel,
      );
      sizeMap[option.key] = option;
    }

    for (final product in products) {
      for (final attribute in product.attributes) {
        final slug = attribute.slug.trim();
        if (slug.isEmpty || attribute.options.isEmpty) {
          continue;
        }

        final isColorAttr = _looksLikeColorAttribute(slug, attribute.name);
        final isSizeAttr = _looksLikeSizeAttribute(slug, attribute.name);

        if (isColorAttr) {
          for (final option in attribute.options) {
            final optionValue = option.trim();
            if (optionValue.isEmpty) continue;
            addColor(attribute: slug, term: optionValue, label: optionValue);
          }
        }

        if (isSizeAttr) {
          for (final option in attribute.options) {
            final optionValue = option.trim();
            if (optionValue.isEmpty) continue;
            addSize(attribute: slug, term: optionValue, label: optionValue);
          }
        }
      }

      final colorAttributeSlug = _findColorAttributeSlug(product.attributes);
      if (colorAttributeSlug != null) {
        for (final color in product.colorOptions) {
          final term = color.colorSlug.trim().isNotEmpty
              ? color.colorSlug.trim()
              : color.colorName.trim();
          final label = color.colorName.trim().isNotEmpty
              ? color.colorName.trim()
              : term;
          if (term.isEmpty || label.isEmpty) continue;
          addColor(
            attribute: colorAttributeSlug,
            term: term,
            label: label,
            colorHex: color.colorHex,
          );
        }

        for (final variation in product.variations) {
          final term = variation.colorSlug.trim().isNotEmpty
              ? variation.colorSlug.trim()
              : variation.colorName.trim();
          final label = variation.colorName.trim().isNotEmpty
              ? variation.colorName.trim()
              : term;
          if (term.isEmpty || label.isEmpty) continue;
          addColor(
            attribute: colorAttributeSlug,
            term: term,
            label: label,
            colorHex: variation.colorHex,
          );
        }
      }
    }

    final colorOptions = colorMap.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final sizeOptions = sizeMap.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return (colorOptions, sizeOptions);
  }

  bool _looksLikeColorAttribute(String slug, String name) {
    final value = '${slug.toLowerCase()} ${name.toLowerCase()}';
    return value.contains('color') || value.contains('لون');
  }

  bool _looksLikeSizeAttribute(String slug, String name) {
    final value = '${slug.toLowerCase()} ${name.toLowerCase()}';
    return value.contains('size') ||
        value.contains('قياس') ||
        value.contains('مقاس');
  }

  String? _findColorAttributeSlug(List<dynamic> attributes) {
    for (final raw in attributes) {
      if (raw is! ProductAttribute) {
        continue;
      }
      if (_looksLikeColorAttribute(raw.slug, raw.name)) {
        return raw.slug;
      }
    }
    return null;
  }

  String? _normalizeHexColor(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$').hasMatch(value)) {
      return value;
    }
    return null;
  }

  List<ProductModel> _sortProducts(
    List<ProductModel> products,
    ProductSortOption option,
  ) {
    if (products.length <= 1 || option == ProductSortOption.defaultOrder) {
      return products;
    }

    final originalIndexById = <int, int>{
      for (final entry in products.asMap().entries) entry.value.id: entry.key,
    };
    final sorted = <ProductModel>[...products];
    sorted.sort((a, b) {
      final priceCompare = switch (option) {
        ProductSortOption.priceLowToHigh => a.basePrice.compareTo(b.basePrice),
        ProductSortOption.priceHighToLow => b.basePrice.compareTo(a.basePrice),
        ProductSortOption.defaultOrder => 0,
      };
      if (priceCompare != 0) {
        return priceCompare;
      }

      final originalA = originalIndexById[a.id] ?? 0;
      final originalB = originalIndexById[b.id] ?? 0;
      return originalA.compareTo(originalB);
    });
    return sorted;
  }

  Future<String> _resolveUserScope(bool isGuest) async {
    if (isGuest) {
      return 'guest';
    }

    final userId = await _storageService.getUserId();
    if (userId != null && userId.trim().isNotEmpty) {
      return 'user_${userId.trim()}';
    }

    return 'guest';
  }

  String _normalizeArabic(String text) {
    if (text.isEmpty) return '';
    var normalized = text.trim().toLowerCase();

    // 1. Normalize Alif variations
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');

    // 2. Normalize Teh Marbuta
    normalized = normalized.replaceAll('ة', 'ه');

    // 3. Normalize Ya / Alef Maksura / Hamza on Ya
    // Often 'ئ' is typed as 'ي' or 'ى' in search or tagging
    normalized = normalized.replaceAll(RegExp(r'[ىئ]'), 'ي');

    // 4. Normalize Hamza on Vav / Vav
    normalized = normalized.replaceAll('ؤ', 'و');

    // 5. Remove diacritics (Harakaat)
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');

    // 6. Remove Tatweel (stretch)
    normalized = normalized.replaceAll('\u0640', '');

    // 7. Normalize whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }
}
