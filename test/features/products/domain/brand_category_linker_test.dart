import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/domain/brand_category_linker.dart';

const _linker = BrandCategoryLinker();

CategoryModel _category({
  required int id,
  required String name,
  required String slug,
  int parentId = 0,
  int menuOrder = 0,
  int count = 1,
  bool hidden = false,
  bool showInApp = true,
}) {
  return CategoryModel(
    id: id,
    name: name,
    slug: slug,
    parentId: parentId,
    count: count,
    imageUrl: '',
    menuOrder: menuOrder,
    hidden: hidden,
    showInApp: showInApp,
  );
}

void main() {
  group('BrandCategoryLinker', () {
    test('uses explicit backend categories from the brand payload', () {
      final calculators = _category(
        id: 11,
        name: 'Calculators',
        slug: 'calculators',
        menuOrder: 2,
      );
      final pens = _category(id: 12, name: 'Pens', slug: 'pens', menuOrder: 1);

      final result = _linker.findLinkedCategoriesForBrand(
        brand: BrandModel(
          id: 1,
          name: 'Deli',
          slug: 'deli',
          count: 10,
          imageUrl: '',
          linkedCategories: <CategoryModel>[calculators, pens],
        ),
        categories: <CategoryModel>[calculators, pens],
      );

      expect(result.map((category) => category.id), <int>[12, 11]);
    });

    test('uses explicit backend ids and slugs without adding slug guesses', () {
      final linkedById = _category(id: 20, name: 'Paper', slug: 'paper');
      final linkedBySlug = _category(id: 30, name: 'Pens', slug: 'pens');
      final slugOnlyGuess = _category(
        id: 40,
        name: 'Deli Guess',
        slug: 'deli-guessed-category',
      );

      final result = _linker.findLinkedCategoriesForBrand(
        brand: const BrandModel(
          id: 1,
          name: 'Deli',
          slug: 'deli',
          count: 10,
          imageUrl: '',
          linkedCategoryIds: <int>[20],
          linkedCategorySlugs: <String>['pens'],
        ),
        categories: <CategoryModel>[linkedById, linkedBySlug, slugOnlyGuess],
      );

      expect(result.map((category) => category.id), <int>[20, 30]);
    });

    test(
      'uses product-derived ids as an offline product relation fallback',
      () {
        final root = _category(id: 10, name: 'Deli', slug: 'deli', count: 3);
        final child = _category(
          id: 11,
          name: 'Calculators',
          slug: 'calculators',
          parentId: 10,
          count: 2,
        );
        final unrelated = _category(id: 99, name: 'Games', slug: 'games');

        final result = _linker.findLinkedCategoriesForBrand(
          brand: const BrandModel(
            id: 1,
            name: 'Deli',
            slug: 'deli',
            count: 10,
            imageUrl: '',
          ),
          categories: <CategoryModel>[root, child, unrelated],
          productDerivedCategoryIds: <int>{10, 11},
        );

        expect(result.map((category) => category.id), <int>[11]);
      },
    );

    test('does not link categories by brand slug tokens alone', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: const BrandModel(
          id: 1,
          name: 'Deli',
          slug: 'deli',
          count: 10,
          imageUrl: '',
        ),
        categories: <CategoryModel>[
          _category(id: 1, name: 'Deli Calculators', slug: 'deli-calculators'),
          _category(id: 2, name: 'Deli Pens', slug: 'pens-deli'),
        ],
      );

      expect(result, isEmpty);
    });

    test('excludes hidden, disabled, empty, and zero-count categories', () {
      final visible = _category(id: 1, name: 'Visible', slug: 'visible');
      final result = _linker.findLinkedCategoriesForBrand(
        brand: BrandModel(
          id: 1,
          name: 'Deli',
          slug: 'deli',
          count: 10,
          imageUrl: '',
          linkedCategories: <CategoryModel>[
            visible,
            _category(id: 2, name: 'Hidden', slug: 'hidden', hidden: true),
            _category(
              id: 3,
              name: 'Disabled',
              slug: 'disabled',
              showInApp: false,
            ),
            _category(id: 4, name: '', slug: 'empty-name'),
            _category(id: 5, name: 'Empty', slug: 'empty', count: 0),
          ],
        ),
        categories: <CategoryModel>[visible],
      );

      expect(result.map((category) => category.id), <int>[1]);
    });
  });
}
