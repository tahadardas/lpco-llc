import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';
import 'package:lpco_llc/features/products/presentation/cubit/search_filter_cubit.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';
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

class _DuplicateSlugMenuSource extends BrandScopedCategoryMenuSource {
  const _DuplicateSlugMenuSource();

  @override
  List<BrandScopedCategoryItemConfig> get items =>
      const <BrandScopedCategoryItemConfig>[
        BrandScopedCategoryItemConfig(
          brandId: 'deli',
          brandAliases: <String>['deli'],
          brandLabelAr: 'Deli',
          labelAr: 'Hole Punchers',
          categorySlug: 'hole-punchers-staplers-binder-clips',
          sectionTitleAr: 'Quick Categories',
          orderIndex: 2,
        ),
        BrandScopedCategoryItemConfig(
          brandId: 'deli',
          brandAliases: <String>['deli'],
          brandLabelAr: 'Deli',
          labelAr: 'Binder Clips',
          categorySlug: 'hole-punchers-staplers-binder-clips',
          sectionTitleAr: 'Quick Categories',
          orderIndex: 3,
        ),
      ];
}

const CategoryModel _deliBallpointCategory = CategoryModel(
  id: 101,
  name: 'Ballpoint Pens',
  slug: 'ballpoint-pens',
  count: 12,
  imageUrl: '',
);

const CategoryModel _deliGelCategory = CategoryModel(
  id: 102,
  name: 'Gel Pens',
  slug: 'gel-ink-pens',
  count: 7,
  imageUrl: '',
);

const CategoryModel _zeroBallpointCategory = CategoryModel(
  id: 201,
  name: 'Ballpoint Pens',
  slug: 'ballpoint-pens',
  count: 4,
  imageUrl: '',
);

const CategoryModel _otherCategory = CategoryModel(
  id: 999,
  name: 'Other',
  slug: 'other-category',
  count: 2,
  imageUrl: '',
);

const CategoryModel _sharedResolvedCategory = CategoryModel(
  id: 301,
  name: 'Office Tools',
  slug: 'hole-punchers-staplers-binder-clips',
  count: 8,
  imageUrl: '',
);

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    required String brandSlug,
    required List<CategoryModel> categories,
    required Set<int> selectedCategoryIds,
    required FutureOr<void> Function(ResolvedBrandScopedCategoryItem item)
    onSelectCategory,
    required FutureOr<void> Function() onClearCategory,
    BrandScopedCategoryMenuSource menuSource =
        const LocalBrandScopedCategoryMenuSource(),
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
              brandSlug: brandSlug,
              brandTitle: '',
              categories: categories,
              selectedCategoryIds: selectedCategoryIds,
              onSelectCategory: onSelectCategory,
              onClearCategory: onClearCategory,
              menuSource: menuSource,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menu appears for configured brand aliases', (tester) async {
    await pumpMenu(
      tester,
      brandSlug: 'zero-miss',
      categories: const <CategoryModel>[_zeroBallpointCategory],
      selectedCategoryIds: const <int>{},
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_menu')),
      findsOneWidget,
    );
    expect(find.text('تصنيفات Zero'), findsNothing);
  });

  testWidgets('non-curated brands do not show the menu', (tester) async {
    await pumpMenu(
      tester,
      brandSlug: 'acme',
      categories: const <CategoryModel>[_otherCategory],
      selectedCategoryIds: const <int>{},
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    expect(
      find.byKey(const ValueKey<String>('brand_scoped_category_menu')),
      findsNothing,
    );
  });

  testWidgets(
    'tapping curated item applies category filter and keeps brand scope',
    (tester) async {
      final cubit = _TestSearchFilterCubit()
        ..seed(
          const SearchFilterState(
            status: SearchFilterStatus.loaded,
            categories: <CategoryModel>[
              _deliBallpointCategory,
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
        brandSlug: 'deli',
        categories: cubit.state.categories,
        selectedCategoryIds: cubit.state.query.categoryIds.toSet(),
        onSelectCategory: (item) => cubit.applyCuratedCategory(item.categoryId),
        onClearCategory: () => cubit.applyCuratedCategory(null),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('brand_scoped_category_menu_toggle_button'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('brand_scoped_category_item_deli_2_gel-ink-pens'),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.query.categoryIds, <int>[102]);
      expect(cubit.state.query.extraParams['brand_slug'], 'deli');
      expect(cubit.state.query.search, 'pen');
      expect(cubit.state.query.stockStatus, 'instock');
    },
  );

  testWidgets('missing category slugs are ignored safely', (tester) async {
    await pumpMenu(
      tester,
      brandSlug: 'deli',
      categories: const <CategoryModel>[_deliBallpointCategory],
      selectedCategoryIds: const <int>{},
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('brand_scoped_category_menu_toggle_button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('brand_scoped_category_item_deli_1_ballpoint-pens'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('brand_scoped_category_item_deli_2_gel-ink-pens'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clearing curated category returns to all products within the same brand',
    (tester) async {
      final cubit = _TestSearchFilterCubit()
        ..seed(
          const SearchFilterState(
            status: SearchFilterStatus.loaded,
            categories: <CategoryModel>[
              _deliBallpointCategory,
              _deliGelCategory,
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
        brandSlug: 'deli',
        categories: cubit.state.categories,
        selectedCategoryIds: cubit.state.query.categoryIds.toSet(),
        onSelectCategory: (item) => cubit.applyCuratedCategory(item.categoryId),
        onClearCategory: () => cubit.applyCuratedCategory(null),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('brand_scoped_category_menu_toggle_button'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('brand_scoped_category_clear_button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.query.categoryIds, isEmpty);
      expect(cubit.state.query.extraParams['brand_slug'], 'deli');
      expect(cubit.state.query.search, 'pen');
      expect(cubit.state.query.sortOption, ProductSortOption.priceHighToLow);
    },
  );

  testWidgets('renders duplicate resolved slugs without key collisions', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      brandSlug: 'deli',
      categories: const <CategoryModel>[_sharedResolvedCategory],
      selectedCategoryIds: const <int>{},
      menuSource: const _DuplicateSlugMenuSource(),
      onSelectCategory: (_) async {},
      onClearCategory: () async {},
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('brand_scoped_category_menu_toggle_button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_2_hole-punchers-staplers-binder-clips',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_scoped_category_item_deli_3_hole-punchers-staplers-binder-clips',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
