import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';
import 'package:lpco_llc/features/products/presentation/cubit/search_filter_cubit.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';
import 'package:lpco_llc/features/products/presentation/widgets/brand_scoped_category_menu.dart';

class _TestSearchFilterCubit extends SearchFilterCubit {
  void seed(SearchFilterState value) {
    emit(value);
  }

  @override
  Future<void> search({
    required bool reset,
    bool persistRecent = true,
    bool forceRefresh = false,
  }) async {
    emit(
      state.copyWith(
        status: SearchFilterStatus.loaded,
        query: reset ? state.query.copyWith(page: 1) : state.query,
        hasMore: false,
        errorMessage: '',
      ),
    );
  }
}

const BrandModel _deliBrand = BrandModel(
  id: 1,
  name: '\u062F\u0644\u064A',
  slug: 'deli',
  count: 12,
  imageUrl: '',
);

const CategoryModel _deliRootCategory = CategoryModel(
  id: 100,
  name: 'Deli',
  slug: 'deli',
  count: 12,
  imageUrl: '',
);

const CategoryModel _deliCalculatorsCategory = CategoryModel(
  id: 101,
  name: 'Deli Calculators',
  slug: 'deli-calculators',
  count: 5,
  imageUrl: '',
);

const CategoryModel _deliGelCategory = CategoryModel(
  id: 102,
  name: 'Deli Gel Pens',
  slug: 'deli-gel-pens',
  count: 7,
  imageUrl: '',
  menuOrder: 2,
);

const CategoryModel _otherCategory = CategoryModel(
  id: 999,
  name: 'Other',
  slug: 'other-category',
  count: 2,
  imageUrl: '',
);

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    BrandModel? brand = _deliBrand,
    String brandSlug = 'deli',
    List<CategoryModel> categories = const <CategoryModel>[
      _deliRootCategory,
      _deliCalculatorsCategory,
      _deliGelCategory,
    ],
    Set<int> selectedCategoryIds = const <int>{},
    Set<int> productDerivedCategoryIds = const <int>{100, 101, 102},
    required FutureOr<void> Function(ResolvedBrandScopedCategoryItem item)
    onSelectCategory,
    required FutureOr<void> Function() onClearCategory,
    Size size = const Size(900, 1400),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BrandScopedCategoryMenu(
              brand: brand,
              brandSlug: brandSlug,
              brandTitle: brand?.name ?? brandSlug,
              categories: categories,
              selectedCategoryIds: selectedCategoryIds,
              productDerivedCategoryIds: productDerivedCategoryIds,
              onSelectCategory: onSelectCategory,
              onClearCategory: onClearCategory,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menu appears for categories linked to the brand slug', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_menu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brand_scoped_category_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_1_deli-calculators',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_2_deli-gel-pens',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_sheet')),
      findsOneWidget,
    );
  });

  testWidgets('many categories stay in a scrollable bottom sheet', (
    tester,
  ) async {
    final categories = List<CategoryModel>.generate(
      41,
      (index) => CategoryModel(
        id: index + 1,
        name: 'Category ${index + 1}',
        slug: 'category-${index + 1}',
        count: index + 1,
        imageUrl: '',
      ),
    );
    final brand = BrandModel(
      id: 8,
      name: 'Deli',
      slug: 'deli',
      count: 41,
      imageUrl: '',
      linkedCategoryIds: categories.map((category) => category.id).toList(),
    );

    await pumpMenu(
      tester,
      brand: brand,
      categories: categories,
      productDerivedCategoryIds: const <int>{},
      size: const Size(390, 844),
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brand_scoped_category_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_sheet')),
      findsOneWidget,
    );
    expect(find.byType(Wrap), findsWidgets);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('category button leaves vertical product scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                BrandScopedCategoryMenu(
                  brand: _deliBrand,
                  brandSlug: _deliBrand.slug,
                  brandTitle: _deliBrand.name,
                  categories: const <CategoryModel>[
                    _deliRootCategory,
                    _deliCalculatorsCategory,
                    _deliGelCategory,
                  ],
                  selectedCategoryIds: const <int>{},
                  productDerivedCategoryIds: const <int>{100, 101, 102},
                  onSelectCategory: (_) async {},
                  onClearCategory: () async {},
                ),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey<String>('products_vertical_scroll'),
                    itemCount: 30,
                    itemBuilder: (_, index) =>
                        SizedBox(height: 80, child: Text('Product $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product 0'), findsOneWidget);
    expect(find.text('Product 20'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey<String>('products_vertical_scroll')),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product 0'), findsNothing);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('products_vertical_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('menu hides slug-only categories without available product ids', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      productDerivedCategoryIds: const <int>{},
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_menu')),
      findsNothing,
    );
  });

  testWidgets('unlinked brands hide the menu gracefully', (tester) async {
    await pumpMenu(
      tester,
      brand: const BrandModel(
        id: 2,
        name: 'Acme',
        slug: 'acme',
        count: 0,
        imageUrl: '',
      ),
      brandSlug: 'acme',
      categories: const <CategoryModel>[_otherCategory],
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_menu')),
      findsNothing,
    );
  });

  testWidgets(
    'tapping linked category applies category filter and keeps brand scope',
    (tester) async {
      final cubit = _TestSearchFilterCubit()
        ..seed(
          const SearchFilterState(
            status: SearchFilterStatus.loaded,
            categories: <CategoryModel>[
              _deliRootCategory,
              _deliCalculatorsCategory,
              _deliGelCategory,
            ],
            query: ProductSearchQuery(
              search: 'pen',
              stockStatus: 'instock',
              extraParams: <String, dynamic>{'brand_slug': 'deli'},
            ),
          ),
        );
      addTearDown(cubit.close);

      await pumpMenu(
        tester,
        categories: cubit.state.categories,
        selectedCategoryIds: cubit.state.query.categoryIds.toSet(),
        onSelectCategory: (item) => cubit.applyCuratedCategory(
          item.categoryId,
          categorySlug: item.categorySlug,
          labelAr: item.labelAr,
        ),
        onClearCategory: () => cubit.applyCuratedCategory(null),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('brand_scoped_category_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'brand_scoped_category_item_deli_2_deli-gel-pens',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.query.categoryIds, <int>[102]);
      expect(cubit.state.query.extraParams['brand_slug'], 'deli');
      expect(cubit.state.query.search, 'pen');
      expect(cubit.state.query.stockStatus, 'instock');
    },
  );

  testWidgets('product-derived categories are included as fallback', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      categories: const <CategoryModel>[
        _deliCalculatorsCategory,
        _otherCategory,
      ],
      productDerivedCategoryIds: const <int>{999},
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brand_scoped_category_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_1_other-category',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'clearing linked category returns to all products within the same brand',
    (tester) async {
      final cubit = _TestSearchFilterCubit()
        ..seed(
          const SearchFilterState(
            status: SearchFilterStatus.loaded,
            categories: <CategoryModel>[
              _deliRootCategory,
              _deliCalculatorsCategory,
            ],
            query: ProductSearchQuery(
              search: 'pen',
              categoryIds: <int>[101],
              sortOption: ProductSortOption.priceHighToLow,
              extraParams: <String, dynamic>{'brand_slug': 'deli'},
            ),
          ),
        );
      addTearDown(cubit.close);

      await pumpMenu(
        tester,
        categories: cubit.state.categories,
        selectedCategoryIds: cubit.state.query.categoryIds.toSet(),
        onSelectCategory: (item) => cubit.applyCuratedCategory(
          item.categoryId,
          categorySlug: item.categorySlug,
          labelAr: item.labelAr,
        ),
        onClearCategory: () => cubit.applyCuratedCategory(null),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('brand_scoped_category_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('brand_scoped_category_all')),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.query.categoryIds, isEmpty);
      expect(cubit.state.query.extraParams['brand_slug'], 'deli');
      expect(cubit.state.query.search, 'pen');
      expect(cubit.state.query.sortOption, ProductSortOption.priceHighToLow);
    },
  );
}
