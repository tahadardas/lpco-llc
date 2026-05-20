import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/models/home_banner_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

enum ProductStatus { initial, loading, loaded, loadingMore, error }

enum ProductViewMode { grid, list }

class ProductState {
  final ProductStatus status;
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final List<BrandModel> brands;
  final List<ProductModel> bannerProducts;
  final int page;
  final bool hasMore;
  final String errorMessage;
  final int? selectedCategoryId;
  final String? selectedBrandSlug;
  final String searchQuery;
  final String stockFilter;
  final String sortBy;
  final ProductViewMode viewMode;
  final Set<int> savedProductIds;
  final bool isGuest;
  final String userScope;
  final String homeBannerImageUrl;
  final String homeBannerTitle;
  final String homeBannerSubtitle;
  final String homeBannerButtonLabel;
  final String homeBannerButtonLink;
  final bool homeBannerEnabled;
  final List<int> bannerProductIds;
  final bool initialSyncDone;
  final bool useActiveProductIndex;
  final List<HomeBannerSlideData> homeBanners;

  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const <ProductModel>[],
    this.categories = const <CategoryModel>[],
    this.brands = const <BrandModel>[],
    this.bannerProducts = const <ProductModel>[],
    this.page = 1,
    this.hasMore = true,
    this.errorMessage = '',
    this.selectedCategoryId,
    this.selectedBrandSlug,
    this.searchQuery = '',
    this.stockFilter = 'all',
    this.sortBy = 'default',
    this.viewMode = ProductViewMode.grid,
    this.savedProductIds = const <int>{},
    this.isGuest = true,
    this.userScope = 'guest',
    this.homeBannerImageUrl = '',
    this.homeBannerTitle = '',
    this.homeBannerSubtitle = '',
    this.homeBannerButtonLabel = '',
    this.homeBannerButtonLink = '',
    this.homeBannerEnabled = true,
    this.bannerProductIds = const [],
    this.initialSyncDone = false,
    this.useActiveProductIndex = false,
    this.homeBanners = const <HomeBannerSlideData>[],
  });

  ProductState copyWith({
    ProductStatus? status,
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    List<BrandModel>? brands,
    List<ProductModel>? bannerProducts,
    int? page,
    bool? hasMore,
    String? errorMessage,
    int? selectedCategoryId,
    bool clearSelectedCategoryId = false,
    String? selectedBrandSlug,
    bool clearSelectedBrandSlug = false,
    String? searchQuery,
    String? stockFilter,
    String? sortBy,
    ProductViewMode? viewMode,
    Set<int>? savedProductIds,
    bool? isGuest,
    String? userScope,
    String? homeBannerImageUrl,
    String? homeBannerTitle,
    String? homeBannerSubtitle,
    String? homeBannerButtonLabel,
    String? homeBannerButtonLink,
    bool? homeBannerEnabled,
    List<int>? bannerProductIds,
    bool? initialSyncDone,
    bool? useActiveProductIndex,
    List<HomeBannerSlideData>? homeBanners,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      bannerProducts: bannerProducts ?? this.bannerProducts,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedCategoryId: clearSelectedCategoryId
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedBrandSlug: clearSelectedBrandSlug
          ? null
          : (selectedBrandSlug ?? this.selectedBrandSlug),
      searchQuery: searchQuery ?? this.searchQuery,
      stockFilter: stockFilter ?? this.stockFilter,
      sortBy: sortBy ?? this.sortBy,
      viewMode: viewMode ?? this.viewMode,
      savedProductIds: savedProductIds ?? this.savedProductIds,
      isGuest: isGuest ?? this.isGuest,
      userScope: userScope ?? this.userScope,
      homeBannerImageUrl: homeBannerImageUrl ?? this.homeBannerImageUrl,
      homeBannerTitle: homeBannerTitle ?? this.homeBannerTitle,
      homeBannerSubtitle: homeBannerSubtitle ?? this.homeBannerSubtitle,
      homeBannerButtonLabel:
          homeBannerButtonLabel ?? this.homeBannerButtonLabel,
      homeBannerButtonLink: homeBannerButtonLink ?? this.homeBannerButtonLink,
      homeBannerEnabled: homeBannerEnabled ?? this.homeBannerEnabled,
      bannerProductIds: bannerProductIds ?? this.bannerProductIds,
      initialSyncDone: initialSyncDone ?? this.initialSyncDone,
      useActiveProductIndex:
          useActiveProductIndex ?? this.useActiveProductIndex,
      homeBanners: homeBanners ?? this.homeBanners,
    );
  }
}

class ProductCubit extends Cubit<ProductState> {
  final ProductRepository _repository;
  final StorageService _storageService;
  Timer? _debounce;
  bool _isSyncing = false;

  ProductCubit({ProductRepository? repository, StorageService? storageService})
    : _repository = repository ?? ProductRepository(),
      _storageService = storageService ?? StorageService(),
      super(const ProductState());

  void setScope({required String userScope, required bool isGuest}) {
    if (state.userScope == userScope && state.isGuest == isGuest) {
      return;
    }

    final savedIds = _storageService.getSavedProductIds(userScope).toSet();
    emit(
      state.copyWith(
        userScope: userScope,
        isGuest: isGuest,
        savedProductIds: savedIds,
        status: ProductStatus.initial,
      ),
    );
  }

  Future<void> initialize({bool forceRefresh = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    // Reset sync status for new fetch cycle (categorical/search changes)
    if (state.status == ProductStatus.loading) {
      emit(state.copyWith(initialSyncDone: false));
    }
    var catalogRevisionChanged = false;
    try {
      catalogRevisionChanged = await _repository.syncCatalogRevision(
        guest: state.isGuest,
      );
    } catch (_) {}

    if (!catalogRevisionChanged && !forceRefresh) {
      try {
        final results = await Future.wait([
          _repository.getCachedProducts(
            page: 1,
            perPage: AppConfig.productsPerPage,
            categoryId: state.selectedCategoryId,
            search: state.searchQuery.isEmpty ? null : state.searchQuery,
            brandSlug: state.selectedBrandSlug,
            stock: state.stockFilter,
            sortBy: state.sortBy,
            guest: state.isGuest,
          ),
          _repository.getCachedCategories(guest: state.isGuest),
          _repository.getCachedBrands(guest: state.isGuest),
          _repository.getCachedHomeBannerData(guest: state.isGuest),
          _repository.getCachedHomeBannersData(guest: state.isGuest),
        ]);

        final cachedProducts = results[0] as List<ProductModel>;
        final cachedCategories = results[1] as List<CategoryModel>;
        final cachedBrands = results[2] as List<BrandModel>;
        final cachedBanner = results[3] as HomeBannerData;
        final cachedBannersList = results[4] as List<HomeBannerSlideData>;

        if (cachedProducts.isNotEmpty || cachedCategories.isNotEmpty) {
          _logBrandOrder(
            'local cached ids=${_idsForLog(cachedProducts)}',
            brandSlug: state.selectedBrandSlug,
          );
          emit(
            state.copyWith(
              status: ProductStatus.loaded,
              products: cachedProducts,
              categories: cachedCategories,
              brands: cachedBrands,
              page: 1,
              hasMore: cachedProducts.length >= AppConfig.productsPerPage,
              homeBannerImageUrl: cachedBanner.imageUrl,
              homeBannerTitle: cachedBanner.title,
              homeBannerSubtitle: cachedBanner.subtitle,
              homeBannerButtonLabel: cachedBanner.buttonLabel,
              homeBannerButtonLink: cachedBanner.buttonLink,
              homeBannerEnabled: cachedBanner.enabled,
              bannerProductIds: cachedBanner.productIds,
              useActiveProductIndex: true,
              homeBanners: cachedBannersList,
            ),
          );
        } else {
          emit(state.copyWith(status: ProductStatus.loading));
        }
      } catch (_) {
        emit(state.copyWith(status: ProductStatus.loading));
      }
    } else {
      emit(state.copyWith(status: ProductStatus.loading));
    }

    // 2. Fetch Remote (Background)
    try {
      _logBrandOrder(
        'ui ids before remote=${_idsForLog(state.products)}',
        brandSlug: state.selectedBrandSlug,
      );
      _logBrandOrder(
        'request brand=${state.selectedBrandSlug?.trim()} page=1 sortBy=${state.sortBy}',
        brandSlug: state.selectedBrandSlug,
      );
      final productsPageFuture = _repository.getProductsPage(
        page: 1,
        categoryId: state.selectedCategoryId,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        brandSlug: state.selectedBrandSlug,
        stock: state.stockFilter,
        orderBy: _mapOrderBy(state.sortBy),
        order: _mapOrder(state.sortBy),
        guest: state.isGuest,
        forceRefresh: forceRefresh,
      );
      final results = await Future.wait([
        productsPageFuture,
        _repository.getCategories(guest: state.isGuest, forceRefresh: forceRefresh),
        _repository.getBrands(guest: state.isGuest, forceRefresh: forceRefresh),
        _repository.getHomeBannerData(guest: state.isGuest, forceRefresh: forceRefresh),
        _repository.getHomeBannersData(guest: state.isGuest, forceRefresh: forceRefresh),
      ]);

      final productsPage = results[0] as CatalogProductsPage;
      final remoteProducts = productsPage.products;
      final bannerData = results[3] as HomeBannerData;
      final remoteBannersList = results[4] as List<HomeBannerSlideData>;
      _logBrandOrder(
        'remote ids=${_idsForLog(remoteProducts)}',
        brandSlug: state.selectedBrandSlug,
      );

      List<ProductModel> bannerProducts = [];
      if (bannerData.productIds.isNotEmpty) {
        try {
          bannerProducts = await _repository.getProductsByIds(
            bannerData.productIds,
            guest: state.isGuest,
            includeGallery: true,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '[BANNER_SYNC_ERROR] Failed to fetch banner products: $e',
            );
          }
        }
      }

      emit(
        state.copyWith(
          status: ProductStatus.loaded,
          products: remoteProducts,
          categories: results[1] as List<CategoryModel>,
          brands: results[2] as List<BrandModel>,
          bannerProducts: bannerProducts,
          page: 1,
          hasMore: productsPage.meta.hasMore,
          errorMessage: '',
          homeBannerImageUrl: bannerData.imageUrl,
          homeBannerTitle: bannerData.title,
          homeBannerSubtitle: bannerData.subtitle,
          homeBannerButtonLabel: bannerData.buttonLabel,
          homeBannerButtonLink: bannerData.buttonLink,
          homeBannerEnabled: bannerData.enabled,
          bannerProductIds: bannerData.productIds,
          initialSyncDone: true,
          useActiveProductIndex: true,
          homeBanners: remoteBannersList,
        ),
      );
      _logBrandOrder(
        'ui ids after remote=${_idsForLog(remoteProducts)}',
        brandSlug: state.selectedBrandSlug,
      );
    } catch (e) {
      if (state.products.isEmpty) {
        emit(
          state.copyWith(
            status: ProductStatus.error,
            errorMessage: ApiContract.safeMessageFromException(e),
          ),
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> loadMore() async {
    if (state.status == ProductStatus.loadingMore ||
        !state.hasMore ||
        _isSyncing) {
      return;
    }

    emit(state.copyWith(status: ProductStatus.loadingMore));

    try {
      final nextPage = state.page + 1;
      _logBrandOrder(
        'request brand=${state.selectedBrandSlug?.trim()} page=$nextPage sortBy=${state.sortBy}',
        brandSlug: state.selectedBrandSlug,
      );
      final nextPageResult = await _repository.getProductsPage(
        page: nextPage,
        categoryId: state.selectedCategoryId,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        brandSlug: state.selectedBrandSlug,
        stock: state.stockFilter,
        orderBy: _mapOrderBy(state.sortBy),
        order: _mapOrder(state.sortBy),
        guest: state.isGuest,
      );
      final nextItems = nextPageResult.products;
      _logBrandOrder(
        'remote ids=${_idsForLog(nextItems)}',
        brandSlug: state.selectedBrandSlug,
      );

      // Deduplicate by ID
      final existingIds = state.products.map((p) => p.id).toSet();
      final deduped = nextItems
          .where((p) => !existingIds.contains(p.id))
          .toList();
      final merged = [...state.products, ...deduped];

      emit(
        state.copyWith(
          status: ProductStatus.loaded,
          products: merged,
          page: nextPage,
          hasMore: nextPageResult.meta.hasMore,
        ),
      );
      _logBrandOrder(
        'ui ids after remote=${_idsForLog(merged)}',
        brandSlug: state.selectedBrandSlug,
      );
    } catch (e) {
      emit(
        state.copyWith(status: ProductStatus.loaded),
      ); // Silently fail load more if we have data
    }
  }

  Future<void> setCategory(int? categoryId) async {
    if (state.selectedCategoryId == categoryId) return;
    emit(
      state.copyWith(
        selectedCategoryId: categoryId,
        clearSelectedCategoryId: categoryId == null,
        products: [],
        status: ProductStatus.loading,
      ),
    );
    await initialize();
  }

  Future<void> setSortBy(String sortBy) async {
    if (state.sortBy == sortBy) return;
    emit(
      state.copyWith(
        sortBy: sortBy,
        products: [],
        status: ProductStatus.loading,
      ),
    );
    await initialize();
  }

  void setSearch(String value) {
    _debounce?.cancel();
    emit(state.copyWith(searchQuery: value));
    _debounce = Timer(const Duration(milliseconds: 500), () => initialize());
  }

  Future<void> refresh({bool forceRemote = true}) async {
    emit(
      state.copyWith(
        page: 1,
        // Retain existing products to prevent UI flash
        status: ProductStatus.loading,
        initialSyncDone: false,
      ),
    );
    if (forceRemote) {
      await _repository.syncCatalogRevision(guest: state.isGuest);
    }
    await initialize(forceRefresh: forceRemote);
  }

  bool isSaved(int productId) => state.savedProductIds.contains(productId);

  Future<Set<int>> getCategoryIdsForBrand(String brandSlug) {
    return _repository.getCategoryIdsForBrand(brandSlug);
  }

  /// Returns category IDs for a brand from the local cache synchronously.
  /// Used for UI filtering when the index is already loaded.
  Set<int> getActiveCategoryIdsForBrand(String brandSlug) {
    // Only return if we have reasonable confidence the index is ready
    if (!state.useActiveProductIndex) return {};
    return _repository.getActiveCategoryIdsForBrand(
      brandSlug,
      scope: state.userScope,
    );
  }

  Future<List<ProductModel>> loadSavedProducts() async {
    final persistedSavedIds = _storageService
        .getSavedProductIds(state.userScope)
        .toSet();
    final savedIds = <int>{...state.savedProductIds, ...persistedSavedIds};
    emit(state.copyWith(savedProductIds: savedIds));

    if (savedIds.isEmpty) return [];

    try {
      final products = await _repository.getProductsByIds(
        savedIds.toList(),
        guest: state.isGuest,
        includeGallery: true,
      );
      return products;
    } catch (e) {
      if (kDebugMode) {
        print('[SAVES_ERROR] Error loading saved products: $e');
      }
      return [];
    }
  }

  String? _mapOrderBy(String sortBy) {
    if (sortBy == 'price_asc' || sortBy == 'price_desc') return 'price';
    if (sortBy == 'newest') return 'date';
    return null;
  }

  String? _mapOrder(String sortBy) {
    if (sortBy == 'price_asc') return 'asc';
    if (sortBy == 'price_desc' || sortBy == 'newest') return 'desc';
    return null;
  }

  void _logBrandOrder(String message, {required String? brandSlug}) {
    if (!kDebugMode) {
      return;
    }
    final normalized = brandSlug?.trim();
    if (normalized == null || normalized.isEmpty || state.sortBy != 'default') {
      return;
    }
    debugPrint('[BRAND_ORDER] $message');
  }

  String _idsForLog(List<ProductModel> products) {
    const maxIds = 30;
    final ids = products.take(maxIds).map((product) => product.id).toList();
    final suffix = products.length > maxIds ? ', ...' : '';
    return '[${ids.join(',')}$suffix]';
  }

  // ... toggleSaved and other UI-only methods remain same ...
  Future<void> toggleSaved(int productId) async {
    final next = Set<int>.from(state.savedProductIds);
    if (next.contains(productId)) {
      next.remove(productId);
    } else {
      next.add(productId);
    }
    emit(state.copyWith(savedProductIds: next));
    await _storageService.saveSavedProductIds(state.userScope, next.toList());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
