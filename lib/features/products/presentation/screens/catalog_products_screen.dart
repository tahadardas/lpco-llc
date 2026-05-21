import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/widgets/cart_currency_conflict_dialog.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';
import 'package:lpco_llc/features/products/domain/catalog_visibility_policy.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/cubit/search_filter_cubit.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_empty_state.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_filter_sheet.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_results_summary.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_search_bar.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_suggestions_panel.dart';
import 'package:lpco_llc/features/products/presentation/widgets/brand_scoped_category_menu.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_share_link.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card.dart';

class CatalogProductsScreen extends StatefulWidget {
  final int? categoryId;
  final String? brandSlug;
  final String title;
  final String initialSearch;
  final bool requireExplicitSearch;
  final bool autoFocusSearch;
  final int? initialCuratedCategoryId;
  final String? initialCuratedCategorySlug;
  final String? initialCuratedCategoryLabel;

  const CatalogProductsScreen({
    super.key,
    required this.title,
    this.categoryId,
    this.brandSlug,
    this.initialSearch = '',
    this.requireExplicitSearch = false,
    this.autoFocusSearch = false,
    this.initialCuratedCategoryId,
    this.initialCuratedCategorySlug,
    this.initialCuratedCategoryLabel,
  });

  @override
  State<CatalogProductsScreen> createState() => _CatalogProductsScreenState();
}

class _CatalogProductsScreenState extends State<CatalogProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final SearchFilterCubit _searchFilterCubit;
  String _basePath = AppRoutePaths.catalog;

  bool get _isGuest => context.read<AuthCubit>().state is! Authenticated;
  bool get _isCategoryListing =>
      widget.categoryId != null && widget.categoryId! > 0;
  bool get _isBrandListing => (widget.brandSlug?.trim().isNotEmpty ?? false);
  bool get _isScopedListing => _isCategoryListing || _isBrandListing;
  Set<int> get _implicitCategoryIds =>
      _isCategoryListing ? <int>{widget.categoryId!} : const <int>{};

  String get _searchHintText {
    if (_isCategoryListing) {
      return '\u0627\u0628\u062d\u062b \u062f\u0627\u062e\u0644 \u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645';
    }
    if (_isBrandListing) {
      return '\u0627\u0628\u062d\u062b \u062f\u0627\u062e\u0644 \u0647\u0630\u0647 \u0627\u0644\u0639\u0644\u0627\u0645\u0629';
    }
    return '\u0627\u0628\u062d\u062b \u0628\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u062a\u062c \u0623\u0648 SKU \u0623\u0648 \u0628\u0627\u0631\u0643\u0648\u062f';
  }

  String get _scopedEmptyMessage {
    if (_isBrandListing) {
      if (_searchFilterCubit.activeCuratedCategoryId != null) {
        return '\u0644\u0627 \u062A\u0648\u062C\u062F \u0645\u0646\u062A\u062C\u0627\u062A \u0636\u0645\u0646 \u0647\u0630\u0627 \u0627\u0644\u062A\u0635\u0646\u064A\u0641 \u0644\u0647\u0630\u0647 \u0627\u0644\u0639\u0644\u0627\u0645\u0629 \u062D\u0627\u0644\u064A\u0627\u064B';
      }
      return '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u062a\u0627\u062d\u0629 \u0644\u0647\u0630\u0647 \u0627\u0644\u0639\u0644\u0627\u0645\u0629 \u062d\u0627\u0644\u064a\u0627\u064b';
    }
    return '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u062a\u0627\u062d\u0629 \u0641\u064a \u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645 \u062d\u0627\u0644\u064a\u0627\u064b';
  }

  String get _scopedNoResultsMessage {
    if (_isBrandListing) {
      return '\u0644\u0627 \u062a\u0648\u062c\u062f \u0646\u062a\u0627\u0626\u062c \u0645\u0637\u0627\u0628\u0642\u0629 \u062f\u0627\u062e\u0644 \u0647\u0630\u0647 \u0627\u0644\u0639\u0644\u0627\u0645\u0629';
    }
    return '\u0644\u0627 \u062a\u0648\u062c\u062f \u0646\u062a\u0627\u0626\u062c \u0645\u0637\u0627\u0628\u0642\u0629 \u062f\u0627\u062e\u0644 \u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645';
  }

  double _topContentPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        BrandAppBar.toolbarHeightValue +
        14;
  }

  double _bottomSafeInset(BuildContext context, {double extra = 0}) {
    final mediaQuery = MediaQuery.of(context);
    final systemInset = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewPadding.bottom,
    );
    return systemInset + extra;
  }

  @override
  void initState() {
    super.initState();
    _syncScope();
    _searchFilterCubit = SearchFilterCubit();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    // Track original base path to preserve navigation shell branch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uri = GoRouterState.of(context).uri;
      setState(() {
        _basePath = uri.queryParameters['basePath'] ?? uri.path;
      });
    });

    _initializeSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldFocus =
          widget.autoFocusSearch ||
          GoRouterState.of(context).uri.queryParameters['focus'] == '1';
      if (shouldFocus) {
        _searchFocusNode.requestFocus();
        if (!_isScopedListing) {
          _searchFilterCubit.loadRecentSearches();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.unfocus();
    _scrollController.removeListener(_onScroll);
    _scrollDebounce?.cancel();
    _searchFilterCubit.close();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncScope() {
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      final user = authState.user;
      context.read<ProductCubit>().setScope(
        userScope: 'user_${user.id ?? user.username}',
        isGuest: false,
      );
      return;
    }
    context.read<ProductCubit>().setScope(userScope: 'guest', isGuest: true);
  }

  void _initializeSearch() {
    final extraParams = <String, dynamic>{};
    final brandSlug = widget.brandSlug?.trim();
    if (brandSlug != null && brandSlug.isNotEmpty) {
      extraParams['brand_slug'] = brandSlug;
    }

    final initialCategories = <int>[
      if (widget.categoryId != null && widget.categoryId! > 0)
        widget.categoryId!,
      if ((widget.categoryId == null || widget.categoryId! <= 0) &&
          !_isBrandListing &&
          widget.initialCuratedCategoryId != null &&
          widget.initialCuratedCategoryId! > 0)
        widget.initialCuratedCategoryId!,
    ];

    _setSearchControllerText(widget.initialSearch);
    _searchFilterCubit.initialize(
      isGuest: _isGuest,
      extraParams: extraParams,
      initialCategoryIds: initialCategories,
      initialCuratedCategorySlug: widget.initialCuratedCategorySlug,
      initialCuratedCategoryLabel: widget.initialCuratedCategoryLabel,
      initialSearch: widget.initialSearch,
      initialPerPage: _isBrandListing ? 20 : null,
      requireExplicitSearch: widget.requireExplicitSearch,
    );
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_isScopedListing &&
        _searchFocusNode.hasFocus &&
        _searchController.text.trim().isEmpty) {
      _searchFilterCubit.loadRecentSearches();
    }
  }

  void _onScroll() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      final state = _searchFilterCubit.state;
      if (state.status != SearchFilterStatus.loaded || !state.hasMore) {
        return;
      }

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 400) {
        _searchFilterCubit.loadMore();
      }
    });
  }

  void _setSearchControllerText(String value) {
    final normalized = value.trim();
    _searchController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _openBarcodeScanner() async {
    final code = await context.push<String>(
      AppRoutePaths.scannerSearchEntry(basePath: _basePath),
    );
    if (!mounted || code == null) return;

    final normalized = code.trim();
    if (normalized.isEmpty) return;

    _setSearchControllerText(normalized);
    setState(() {});
    await _searchFilterCubit.submitBarcodeSearch(normalized);
  }

  Future<void> _onRecentSearchTap(String term) async {
    _setSearchControllerText(term);
    setState(() {});
    await _searchFilterCubit.useRecentSearch(term);
    if (mounted) {
      _searchFocusNode.unfocus();
    }
  }

  Future<void> _clearSearch() async {
    _setSearchControllerText('');
    setState(() {});
    await _searchFilterCubit.submitSearch('');
  }

  bool _showRecentSearches(SearchFilterState state) {
    return !_isScopedListing &&
        _searchFocusNode.hasFocus &&
        _searchController.text.trim().isEmpty &&
        state.recentSearches.isNotEmpty;
  }

  bool _isIdleSearchState(SearchFilterState state) {
    return !_isScopedListing &&
        widget.requireExplicitSearch &&
        state.status == SearchFilterStatus.initial &&
        state.products.isEmpty &&
        state.query.search.trim().isEmpty &&
        !state.hasFiltersApplied;
  }

  bool _hasVisibleFilters(SearchFilterState state) {
    final normalizedCategoryIds = state.query.categoryIds
        .where((id) => id > 0)
        .toSet();
    final visibleCategoryIds = normalizedCategoryIds.difference(
      _implicitCategoryIds,
    );
    final hasCuratedBrandFilter =
        _isBrandListing && _searchFilterCubit.activeCuratedCategoryId != null;
    return state.query.minPrice != null ||
        state.query.maxPrice != null ||
        hasCuratedBrandFilter ||
        visibleCategoryIds.isNotEmpty ||
        state.query.attributeFilter != null ||
        state.query.stockStatus != 'any' ||
        state.query.sortOption != ProductSortOption.defaultOrder;
  }

  bool _isAwaitingInitialScopedLoad(SearchFilterState state) {
    return state.status == SearchFilterStatus.initial &&
        state.products.isEmpty &&
        !widget.requireExplicitSearch &&
        (_isScopedListing || widget.initialSearch.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      listenWhen: (previous, current) => current is CartCurrencyConflict,
      listener: (context, state) async {
        if (state is CartCurrencyConflict) {
          await showCartCurrencyConflictDialog(context, state);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: BrandAppBar(
          title: widget.title.isNotEmpty
              ? widget.title
              : (_isCategoryListing
                    ? 'المنتجات'
                    : (_isBrandListing ? 'الماركة' : 'تصفح')),
          showBack: true,
        ),
        body: BlocBuilder<SearchFilterCubit, SearchFilterState>(
          bloc: _searchFilterCubit,
          builder: (context, state) {
            final showSuggestions = _showSuggestions(state);
            final idleSearch = _isIdleSearchState(state);
            return Column(
              children: <Widget>[
                _searchBar(state),
                if (_isBrandListing) _brandScopedCategoryMenu(state),
                if (idleSearch)
                  Expanded(child: _idleDiscovery(state))
                else ...<Widget>[
                  if (_showRecentSearches(state)) _recentSearches(state),
                  if (!_isBrandListing) _resultsSummary(state),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(child: _content(state)),
                        if (showSuggestions)
                          Align(
                            alignment: Alignment.topCenter,
                            child: _suggestionsPanel(state),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchBar(SearchFilterState state) {
    final activeFilters = _activeFilterCount(state);
    return CatalogSearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      topPadding: _topContentPadding(context),
      activeFilters: activeFilters,
      hintText: _searchHintText,
      showBarcodeAction: !_isScopedListing,
      onClearSearch: _clearSearch,
      onOpenBarcodeScanner: _openBarcodeScanner,
      onOpenFilter: () => _openFilterBottomSheet(state),
      onChanged: (value) {
        setState(() {});
        _searchFilterCubit.onSearchChanged(value);
        if (!_isScopedListing && value.trim().isEmpty) {
          _searchFilterCubit.loadRecentSearches();
        }
      },
      onSubmitted: (value) => _searchFilterCubit.submitSearch(value),
    );
  }

  Widget _recentSearches(SearchFilterState state) {
    return SizedBox(
      height: 50,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        scrollDirection: Axis.horizontal,
        children: [
          ...state.recentSearches.map(
            (term) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: InputChip(
                avatar: const Icon(Icons.history_rounded, size: 16),
                label: Text(term),
                onPressed: () => _onRecentSearchTap(term),
                onDeleted: () => _searchFilterCubit.removeRecentSearch(term),
              ),
            ),
          ),
          if (state.recentSearches.isNotEmpty)
            TextButton(
              onPressed: () => _searchFilterCubit.clearRecentSearches(),
              child: const Text('مسح الكل'),
            ),
        ],
      ),
    );
  }

  Widget _idleDiscovery(SearchFilterState state) {
    final trendingTerms = _buildTrendingTerms(state);
    final categories = state.categories
        .where(
          (category) => _isVisibleDiscoveryCategory(category, state.categories),
        )
        .take(8)
        .toList(growable: false);
    final brands = context
        .read<ProductCubit>()
        .state
        .brands
        .where(CatalogVisibilityPolicy.isVisibleBrand)
        .take(8)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        14,
        4,
        14,
        _bottomSafeInset(context, extra: 18),
      ),
      children: [
        if (state.recentSearches.isNotEmpty) ...[
          const _SearchSectionTitle('عمليات البحث الأخيرة'),
          const SizedBox(height: 6),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...state.recentSearches.map(
                  (term) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: InputChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(term),
                      onPressed: () => _onRecentSearchTap(term),
                      onDeleted: () =>
                          _searchFilterCubit.removeRecentSearch(term),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _searchFilterCubit.clearRecentSearches(),
                  child: const Text('مسح الكل'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (trendingTerms.isNotEmpty) ...[
          const _SearchSectionTitle('عمليات البحث الشائعة'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trendingTerms
                .map(
                  (term) => ActionChip(
                    avatar: const Icon(Icons.trending_up_rounded, size: 16),
                    label: Text(term),
                    onPressed: () async {
                      _setSearchControllerText(term);
                      await _searchFilterCubit.submitSearch(term);
                    },
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
        ],
        if (categories.isNotEmpty) ...[
          const _SearchSectionTitle('تصفح حسب الأقسام'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => ActionChip(
                    avatar: const Icon(Icons.grid_view_rounded, size: 16),
                    label: Text(category.name),
                    onPressed: () => _searchFilterCubit.applyFilters(
                      categoryIds: <int>[category.id],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
        ],
        if (brands.isNotEmpty) ...[
          const _SearchSectionTitle('تصفح حسب الماركات'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brands
                .map(
                  (brand) => ActionChip(
                    avatar: const Icon(Icons.sell_rounded, size: 16),
                    label: Text(brand.name),
                    onPressed: () {
                      context.push(AppRoutePaths.brandUrl(brand.slug));
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  List<String> _buildTrendingTerms(SearchFilterState state) {
    final values = <String>[];
    final seen = <String>{};

    void add(String raw) {
      final normalized = raw.trim();
      if (normalized.isEmpty) return;
      if (normalized.length < 2) return;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        values.add(normalized);
      }
    }

    for (final term in state.recentSearches) {
      add(term);
      if (values.length >= 10) return values;
    }

    for (final category in state.categories.where(
      (category) => _isVisibleDiscoveryCategory(category, state.categories),
    )) {
      add(category.name);
      if (values.length >= 10) return values;
    }

    for (final brand in context.read<ProductCubit>().state.brands.where(
      CatalogVisibilityPolicy.isVisibleBrand,
    )) {
      add(brand.name);
      if (values.length >= 10) return values;
    }

    return values;
  }

  bool _showSuggestions(SearchFilterState state) {
    return !_isScopedListing &&
        _searchFocusNode.hasFocus &&
        _searchController.text.trim().isNotEmpty &&
        _buildSuggestions(state).isNotEmpty;
  }

  Widget _suggestionsPanel(SearchFilterState state) {
    final suggestions = _buildSuggestions(state);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final maxPanelHeight =
        MediaQuery.sizeOf(context).height * (keyboardVisible ? 0.28 : 0.36);
    return CatalogSuggestionsPanel(
      suggestions: suggestions,
      maxPanelHeight: maxPanelHeight.clamp(150.0, 280.0),
      onTap: _applySuggestion,
    );
  }

  Widget _resultsSummary(SearchFilterState state) {
    final hasQuery = state.query.search.trim().isNotEmpty;
    final isIdleSearch = _isIdleSearchState(state);
    final isLoading =
        state.isTyping || state.status == SearchFilterStatus.loading;
    final normalizedTitle = widget.title.trim();
    final summary = isIdleSearch
        ? 'اكتشف مجموعتنا الرائعة'
        : hasQuery
        ? 'نتائج البحث: "${state.query.search}"'
        : _isScopedListing
        ? (normalizedTitle.isEmpty ? 'نتائج البحث' : 'قسم $normalizedTitle')
        : 'جميع المنتجات';

    return CatalogResultsSummary(
      summary: summary,
      count: state.products.length,
      isLoading: isLoading,
      hasFilters: _hasVisibleFilters(state),
      onClearFilters: _clearVisibleFilters,
    );
  }

  Widget _brandScopedCategoryMenu(SearchFilterState state) {
    final brandSlug = widget.brandSlug?.trim() ?? '';
    final productState = context.watch<ProductCubit>().state;
    final brand = _findCurrentBrand(productState.brands, brandSlug);
    final productDerivedCategoryIds = context
        .read<ProductCubit>()
        .getActiveCategoryIdsForBrand(brandSlug);

    return BrandScopedCategoryMenu(
      brand: brand,
      brandSlug: widget.brandSlug,
      brandTitle: widget.title,
      categories: state.categories,
      productDerivedCategoryIds: productDerivedCategoryIds,
      selectedCategoryIds: _searchFilterCubit.activeCuratedCategoryId != null
          ? <int>{_searchFilterCubit.activeCuratedCategoryId!}
          : const <int>{},
      onSelectCategory: (item) => _searchFilterCubit.applyCuratedCategory(
        item.categoryId,
        categorySlug: item.categorySlug,
        labelAr: item.labelAr,
      ),
      onClearCategory: () => _searchFilterCubit.applyCuratedCategory(null),
    );
  }

  BrandModel? _findCurrentBrand(List<BrandModel> brands, String brandSlug) {
    final normalizedSlug = BrandScopedCategoryResolver.normalizeBrandKey(
      brandSlug,
    );
    if (normalizedSlug.isEmpty) {
      return null;
    }

    for (final brand in brands) {
      if (BrandScopedCategoryResolver.normalizeBrandKey(brand.slug) ==
          normalizedSlug) {
        return brand;
      }
    }

    return BrandModel(
      id: 0,
      name: widget.title.trim().isEmpty ? normalizedSlug : widget.title.trim(),
      slug: normalizedSlug,
      count: 0,
      imageUrl: '',
    );
  }

  List<CatalogSuggestionItem> _buildSuggestions(SearchFilterState state) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const <CatalogSuggestionItem>[];
    }

    final suggestions = <CatalogSuggestionItem>[];
    final seen = <String>{};

    void add(CatalogSuggestionItem suggestion) {
      final key = '${suggestion.type.name}:${suggestion.key}'.toLowerCase();
      if (seen.add(key)) {
        suggestions.add(suggestion);
      }
    }

    for (final term in state.recentSearches) {
      if (term.toLowerCase().contains(query)) {
        add(
          CatalogSuggestionItem(
            type: CatalogSuggestionType.recent,
            key: term,
            title: term,
            subtitle: 'بحث سابق',
            icon: Icons.history_rounded,
          ),
        );
      }
      if (suggestions.length >= 8) return suggestions;
    }

    for (final product in state.products) {
      final name = product.name.trim();
      if (name.isNotEmpty && name.toLowerCase().contains(query)) {
        add(
          CatalogSuggestionItem(
            type: CatalogSuggestionType.product,
            key: 'p_${product.id}',
            title: name,
            subtitle: product.sku.trim().isEmpty
                ? 'منتج'
                : 'SKU: ${product.sku}',
            icon: Icons.inventory_2_outlined,
          ),
        );
      }

      final sku = product.sku.trim();
      if (sku.isNotEmpty && sku.toLowerCase().contains(query)) {
        add(
          CatalogSuggestionItem(
            type: CatalogSuggestionType.sku,
            key: 'sku_$sku',
            title: sku,
            subtitle: 'مطابق SKU',
            icon: Icons.qr_code_rounded,
          ),
        );
      }
      if (suggestions.length >= 8) return suggestions;
    }

    if (!_isBrandListing) {
      for (final category in state.categories) {
        if (!_isVisibleDiscoveryCategory(category, state.categories)) {
          continue;
        }
        final name = category.name.trim();
        if (name.toLowerCase().contains(query)) {
          add(
            CatalogSuggestionItem(
              type: CatalogSuggestionType.category,
              key: 'c_${category.id}',
              title: name,
              subtitle: 'قسم',
              icon: Icons.grid_view_rounded,
              categoryId: category.id,
            ),
          );
        }
        if (suggestions.length >= 8) return suggestions;
      }
    }

    final brands = context.read<ProductCubit>().state.brands;
    for (final brand in brands) {
      if (!CatalogVisibilityPolicy.isVisibleBrand(brand)) {
        continue;
      }
      final name = brand.name.trim();
      if (name.toLowerCase().contains(query)) {
        add(
          CatalogSuggestionItem(
            type: CatalogSuggestionType.brand,
            key: 'b_${brand.slug}',
            title: name,
            subtitle: 'علامة تجارية',
            icon: Icons.sell_rounded,
            brandSlug: brand.slug,
          ),
        );
      }
      if (suggestions.length >= 8) return suggestions;
    }

    final onlyDigits = RegExp(r'^\d{6,}$').hasMatch(query);
    if (onlyDigits) {
      add(
        CatalogSuggestionItem(
          type: CatalogSuggestionType.barcode,
          key: 'barcode_$query',
          title: query,
          subtitle: 'رقم باركود مخصص',
          icon: Icons.qr_code_scanner_rounded,
        ),
      );
    }

    return suggestions;
  }

  bool _isVisibleDiscoveryCategory(
    CategoryModel category,
    List<CategoryModel> allCategories,
  ) {
    if (category.parentId > 0) {
      return CatalogVisibilityPolicy.isVisibleLeafCategory(category);
    }

    return CatalogVisibilityPolicy.isVisibleParentCategory(
      category,
      CatalogVisibilityPolicy.visibleCategoryChildren(category, allCategories),
    );
  }

  Future<void> _applySuggestion(CatalogSuggestionItem suggestion) async {
    switch (suggestion.type) {
      case CatalogSuggestionType.category:
        await _searchFilterCubit.applyFilters(
          categoryIds: suggestion.categoryId == null
              ? const <int>[]
              : <int>[suggestion.categoryId!],
        );
        break;
      case CatalogSuggestionType.brand:
        if (suggestion.brandSlug != null && suggestion.brandSlug!.isNotEmpty) {
          if (mounted) {
            context.push(AppRoutePaths.brandUrl(suggestion.brandSlug!));
          }
        }
        break;
      case CatalogSuggestionType.barcode:
        _setSearchControllerText(suggestion.title);
        await _searchFilterCubit.submitBarcodeSearch(suggestion.title);
        break;
      case CatalogSuggestionType.recent:
      case CatalogSuggestionType.product:
      case CatalogSuggestionType.sku:
        _setSearchControllerText(suggestion.title);
        await _searchFilterCubit.submitSearch(suggestion.title);
        break;
    }

    if (mounted) {
      _searchFocusNode.unfocus();
    }
  }

  Widget _content(SearchFilterState state) {
    final awaitingInitialScopedLoad = _isAwaitingInitialScopedLoad(state);
    final isInitialLoading =
        awaitingInitialScopedLoad ||
        state.isTyping ||
        (state.status == SearchFilterStatus.loading && state.products.isEmpty);

    final isRefreshingSearch =
        state.status == SearchFilterStatus.loading && state.products.isNotEmpty;

    if (isInitialLoading) {
      return _loadingSkeleton();
    }

    if (isRefreshingSearch) {
      return _loadingSkeleton();
    }

    if (state.status == SearchFilterStatus.error && state.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => _searchFilterCubit.refresh(forceRemote: true),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.status == SearchFilterStatus.empty || state.products.isEmpty) {
      return SizedBox.expand(child: _emptyState(state));
    }

    final savedIds = context.watch<ProductCubit>().state.savedProductIds;
    final showSkeleton = state.status == SearchFilterStatus.loading;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _searchFilterCubit.refresh(forceRemote: true),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _productsGrid(state: state, savedIds: savedIds),
              if (state.status == SearchFilterStatus.loadingMore)
                _loadingMore(),
            ],
          ),
        ),
        if (showSkeleton)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _loadingSkeleton() {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        14,
        6,
        14,
        _bottomSafeInset(context, extra: 12),
      ),
      itemCount: 6,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: ProductCard.preferredGridExtent(isGuest: _isGuest),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => SkeletonBlock(
        height: ProductCard.preferredGridExtent(isGuest: _isGuest),
      ),
    );
  }

  Widget _emptyState(SearchFilterState state) {
    final hasSearch = state.query.search.trim().isNotEmpty;
    final hasFilters = _hasVisibleFilters(state);
    final isIdleSearch = _isIdleSearchState(state);

    return CatalogEmptyState(
      isIdleSearch: isIdleSearch,
      hasSearch: hasSearch,
      hasFilters: hasFilters,
      isScopedListing: _isScopedListing,
      scopedEmptyMessage: _scopedEmptyMessage,
      scopedNoResultsMessage: _scopedNoResultsMessage,
      onFocusSearch: () => _searchFocusNode.requestFocus(),
      onClearSearch: _clearSearch,
      onClearFilters: _clearVisibleFilters,
      onEditFilters: () => _openFilterBottomSheet(state),
    );
  }

  Widget _productsGrid({
    required SearchFilterState state,
    required Set<int> savedIds,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        14,
        6,
        14,
        _bottomSafeInset(context, extra: 12),
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = state.products[index];
          return _productCard(product, savedIds);
        }, childCount: state.products.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: ProductCard.preferredGridExtent(isGuest: _isGuest),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
      ),
    );
  }

  Widget _loadingMore() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        _bottomSafeInset(context, extra: 12),
      ),
      sliver: SliverGrid(
        delegate: SliverChildListDelegate.fixed([
          SkeletonBlock(
            height: ProductCard.preferredGridExtent(isGuest: _isGuest),
          ),
          SkeletonBlock(
            height: ProductCard.preferredGridExtent(isGuest: _isGuest),
          ),
        ]),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: ProductCard.preferredGridExtent(isGuest: _isGuest),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
      ),
    );
  }

  Widget _productCard(ProductModel product, Set<int> savedIds) {
    return ProductCard(
      product: product,
      isGuest: _isGuest,
      isSaved: savedIds.contains(product.id),
      currencyCode: context.read<AuthCubit>().currentUser?.currency ?? 'syp',
      userGroup: context.read<AuthCubit>().currentUser?.group ?? '',
      onTap: () =>
          context.push(AppRoutePaths.productUrl(product.id), extra: product),
      onToggleSave: () async {
        await context.read<ProductCubit>().toggleSaved(product.id);
        if (mounted) setState(() {});
      },
      onAddToCart: (unit) => _addToCart(product, unit),
      onShare: () => _shareProduct(product),
    );
  }

  Future<void> _openFilterBottomSheet(SearchFilterState state) async {
    final draft = await showCatalogFilterBottomSheet(
      context: context,
      state: state,
      hideCategorySection: _isBrandListing,
      lockedCategoryId: _isCategoryListing ? widget.categoryId : null,
      lockedCategoryName: _isCategoryListing ? widget.title : null,
    );

    if (draft == null) {
      return;
    }

    await _searchFilterCubit.applyFilters(
      minPrice: draft.minPrice,
      clearMinPrice: draft.clearMinPrice,
      maxPrice: draft.maxPrice,
      clearMaxPrice: draft.clearMaxPrice,
      categoryIds: _isBrandListing ? null : draft.categoryIds,
      attributeFilter: draft.attributeFilter,
      clearAttributeFilter: draft.attributeFilter == null,
      stockStatus: draft.stockStatus,
      sortOption: draft.sortOption,
    );
  }

  int _activeFilterCount(SearchFilterState state) {
    final visibleCategoryIds = state.query.categoryIds
        .where((id) => id > 0)
        .toSet()
        .difference(_implicitCategoryIds);
    var count = 0;
    if (_isBrandListing && _searchFilterCubit.activeCuratedCategoryId != null) {
      count++;
    }
    if (visibleCategoryIds.isNotEmpty) count++;
    if (state.query.attributeFilter != null) count++;
    if (state.query.stockStatus.toLowerCase() != 'any') count++;
    if (state.query.sortOption != ProductSortOption.defaultOrder) count++;
    if (state.query.minPrice != null) count++;
    if (state.query.maxPrice != null) count++;
    return count;
  }

  Future<void> _clearVisibleFilters() async {
    if (_isBrandListing) {
      await _searchFilterCubit.clearAllFilters();
      return;
    }
    await _searchFilterCubit.applyFilters(
      clearMinPrice: true,
      clearMaxPrice: true,
      categoryIds: _implicitCategoryIds.toList(growable: false),
      clearAttributeFilter: true,
      stockStatus: 'any',
      sortOption: ProductSortOption.defaultOrder,
    );
  }

  Future<void> _addToCart(ProductModel product, ProductCardUnit unit) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      await context.push(AppRoutePaths.login);
      return;
    }

    await context.read<CartCubit>().addToCart(
      CartItemModel(
        productId: product.id,
        name: product.name,
        price: unit.price.toString(),
        image: product.firstImage,
        selectedVariants: const {},
        unitType: unit.type,
        unitLabel: unit.label,
        piecesCount: unit.piecesCount,
        currency: authState.user.currency,
      ),
    );

    if (!mounted || context.read<CartCubit>().state is CartCurrencyConflict) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى السلة')));
  }

  void _shareProduct(ProductModel product) {
    SharePlus.instance.share(ShareParams(text: buildProductShareText(product)));
  }
}

class _SearchSectionTitle extends StatelessWidget {
  final String title;

  const _SearchSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}
