import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_config.dart';
import 'package:lpco_llc/features/products/presentation/widgets/brand_quick_categories_tile.dart';

const _config = BrandScopedCategoryItemConfig(
  brandId: 'deli',
  brandAliases: <String>['deli'],
  brandLabelAr: 'Deli',
  labelAr: 'Calculators',
  categorySlug: 'calculators',
  sectionTitleAr: 'Quick Categories',
  orderIndex: 1,
);

const _duplicateSlugConfig = BrandScopedCategoryItemConfig(
  brandId: 'deli',
  brandAliases: <String>['deli'],
  brandLabelAr: 'Deli',
  labelAr: 'Hole Punchers',
  categorySlug: 'hole-punchers-staplers-binder-clips',
  sectionTitleAr: 'Quick Categories',
  orderIndex: 2,
);

const _duplicateSlugConfigTwo = BrandScopedCategoryItemConfig(
  brandId: 'deli',
  brandAliases: <String>['deli'],
  brandLabelAr: 'Deli',
  labelAr: 'Binder Clips',
  categorySlug: 'hole-punchers-staplers-binder-clips',
  sectionTitleAr: 'Quick Categories',
  orderIndex: 3,
);

const _menu = BrandScopedCategoryMenuConfig(
  brandId: 'deli',
  brandLabelAr: 'Deli',
  brandAliases: <String>['deli'],
  sections: <BrandScopedCategoryConfigSection>[
    BrandScopedCategoryConfigSection(
      titleAr: 'Quick Categories',
      items: <BrandScopedCategoryItemConfig>[_config],
    ),
  ],
);

const _duplicateMenu = BrandScopedCategoryMenuConfig(
  brandId: 'deli',
  brandLabelAr: 'Deli',
  brandAliases: <String>['deli'],
  sections: <BrandScopedCategoryConfigSection>[
    BrandScopedCategoryConfigSection(
      titleAr: 'Quick Categories',
      items: <BrandScopedCategoryItemConfig>[
        _duplicateSlugConfig,
        _duplicateSlugConfigTwo,
      ],
    ),
  ],
);

void main() {
  testWidgets('shows expand arrow only for curated brands', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                BrandQuickCategoriesTile(
                  brandSlug: 'deli',
                  title: 'Deli',
                  subtitle: '15 products',
                  imageUrl: '',
                  curatedMenu: _menu,
                  onTapBrand: () {},
                  onTapCuratedCategory: (_) {},
                ),
                BrandQuickCategoriesTile(
                  brandSlug: 'other',
                  title: 'Other',
                  subtitle: '10 products',
                  imageUrl: '',
                  onTapBrand: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('brand_quick_categories_expand_deli')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brand_quick_categories_expand_other')),
      findsNothing,
    );
  });

  testWidgets('expand arrow does not trigger brand navigation', (tester) async {
    var brandTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BrandQuickCategoriesTile(
              brandSlug: 'deli',
              title: 'Deli',
              subtitle: '15 products',
              imageUrl: '',
              curatedMenu: _menu,
              onTapBrand: () => brandTapCount++,
              onTapCuratedCategory: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brand_quick_categories_expand_deli')),
    );
    await tester.pumpAndSettle();

    expect(brandTapCount, 0);
    expect(
      find.byKey(
        const ValueKey<String>('brand_quick_category_deli_1_calculators'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('expands and emits curated category tap', (tester) async {
    BrandScopedCategoryItemConfig? tappedItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BrandQuickCategoriesTile(
              brandSlug: 'deli',
              title: 'Deli',
              subtitle: '15 products',
              imageUrl: '',
              curatedMenu: _menu,
              onTapBrand: () {},
              onTapCuratedCategory: (item) => tappedItem = item,
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brand_quick_categories_expand_deli')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('brand_quick_category_deli_1_calculators'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tappedItem?.categorySlug, 'calculators');
    expect(tappedItem?.labelAr, 'Calculators');
  });

  testWidgets('renders duplicate resolved slugs without key collisions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BrandQuickCategoriesTile(
              brandSlug: 'deli',
              title: 'Deli',
              subtitle: '15 products',
              imageUrl: '',
              curatedMenu: _duplicateMenu,
              onTapBrand: () {},
              onTapCuratedCategory: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brand_quick_categories_expand_deli')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_quick_category_deli_2_hole-punchers-staplers-binder-clips',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'brand_quick_category_deli_3_hole-punchers-staplers-binder-clips',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand area tap still opens the brand directly', (tester) async {
    var brandTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BrandQuickCategoriesTile(
              brandSlug: 'deli',
              title: 'Deli',
              subtitle: '15 products',
              imageUrl: '',
              curatedMenu: _menu,
              onTapBrand: () => brandTapCount++,
              onTapCuratedCategory: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('brand_quick_categories_brand_tap_deli'),
      ),
    );
    await tester.pumpAndSettle();

    expect(brandTapCount, 1);
  });
}
