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
  Future<void> search({required bool reset, bool persistRecent = true}) async {
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
      find.byKey(
        const ValueKey<String>('brand_scoped_category_item_deli_1_deli'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_2_deli-calculators',
        ),
      ),
      findsOneWidget,
    );
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
        find.byKey(
          const ValueKey<String>(
            'brand_scoped_category_item_deli_3_deli-gel-pens',
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

    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_2_other-category',
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
