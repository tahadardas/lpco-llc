import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/domain/brand_category_linker.dart';

const _linker = BrandCategoryLinker();
const _deli = BrandModel(
  id: 1,
  name: 'Deli',
  slug: 'deli',
  count: 1,
  imageUrl: '',
);

CategoryModel _category({
  required int id,
  required String name,
  required String slug,
  int parentId = 0,
  int menuOrder = 0,
  int count = 1,
}) {
  return CategoryModel(
    id: id,
    name: name,
    slug: slug,
    parentId: parentId,
    count: count,
    imageUrl: '',
    menuOrder: menuOrder,
  );
}

void main() {
  group('BrandCategoryLinker', () {
    test('links exact brand slug as root category', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 10, name: 'Deli', slug: 'deli'),
          _category(id: 20, name: 'Games', slug: 'games'),
        ],
      );

      expect(result.map((category) => category.id), <int>[10]);
    });

    test('links direct children of exact brand root category', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 10, name: 'Deli', slug: 'deli'),
          _category(
            id: 11,
            name: 'Calculators',
            slug: 'calculators',
            parentId: 10,
          ),
          _category(id: 20, name: 'Games', slug: 'games'),
        ],
      );

      expect(result.map((category) => category.id), <int>[10, 11]);
    });

    test('links deli categories using safe slug tokens', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Calculators', slug: 'deli-calculators'),
          _category(id: 2, name: 'Supplies', slug: 'deli-school-supplies'),
          _category(id: 3, name: 'Markers', slug: 'deli-marker-pens'),
          _category(
            id: 4,
            name: 'Laminating',
            slug: 'thermal-laminating-machinesd-deli',
          ),
          _category(id: 5, name: 'Stationery', slug: 'my-deli-category'),
          _category(id: 6, name: 'Games', slug: 'games'),
        ],
      );

      expect(result.map((category) => category.slug), <String>[
        'deli-calculators',
        'thermal-laminating-machinesd-deli',
        'deli-marker-pens',
        'my-deli-category',
        'deli-school-supplies',
      ]);
    });

    test('does not match unsafe brand substrings', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Modeline', slug: 'modeline'),
          _category(id: 2, name: 'Deli Category', slug: 'deli-category'),
        ],
      );

      expect(result.map((category) => category.id), <int>[2]);
    });

    test('does not link by category name without a slug token', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Deli calculators', slug: 'calculators'),
          _category(id: 2, name: 'School supplies Deli', slug: 'supplies'),
          _category(id: 3, name: 'Deliware', slug: 'deliware'),
        ],
      );

      expect(result, isEmpty);
    });

    test('includes product-derived categories and deduplicates', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Deli', slug: 'deli'),
          _category(id: 2, name: 'Generic', slug: 'generic'),
        ],
        productDerivedCategoryIds: <int>{1, 2, 999},
      );

      expect(result.map((category) => category.id), <int>[1, 2]);
    });

    test(
      'sorts root, direct children, then slug matches by category order',
      () {
        final result = _linker.findLinkedCategoriesForBrand(
          brand: _deli,
          categories: <CategoryModel>[
            _category(id: 30, name: 'B category', slug: 'deli-b', menuOrder: 2),
            _category(id: 10, name: 'Deli', slug: 'deli', menuOrder: 99),
            _category(
              id: 11,
              name: 'Direct child',
              slug: 'calculators',
              parentId: 10,
              menuOrder: 9,
            ),
            _category(id: 20, name: 'A category', slug: 'deli-a', menuOrder: 2),
            _category(id: 40, name: 'Z category', slug: 'deli-z', menuOrder: 1),
          ],
        );

        expect(result.map((category) => category.id), <int>[
          10,
          11,
          40,
          20,
          30,
        ]);
      },
    );

    test('keeps explicit backend links and still adds slug token matches', () {
      final brand = BrandModel.fromJson(<String, dynamic>{
        'id': 99,
        'name': 'Deli',
        'slug': 'deli',
        'linked_category_ids': <int>[50],
        'linked_category_slugs': <String>['backend-slug'],
      });

      final result = _linker.findLinkedCategoriesForBrand(
        brand: brand,
        categories: <CategoryModel>[
          _category(id: 10, name: 'Deli', slug: 'deli'),
          _category(id: 50, name: 'By ID', slug: 'by-id', menuOrder: 2),
          _category(
            id: 60,
            name: 'By Slug',
            slug: 'backend-slug',
            menuOrder: 1,
          ),
          _category(
            id: 70,
            name: 'Deli markers',
            slug: 'deli-marker-pens',
            menuOrder: 3,
          ),
        ],
      );

      expect(result.map((category) => category.id), <int>[10, 60, 50, 70]);
    });

    test('links zero categories using slug tokens', () {
      const zero = BrandModel(
        id: 3,
        name: 'Zero',
        slug: 'zero',
        count: 1,
        imageUrl: '',
      );

      final result = _linker.findLinkedCategoriesForBrand(
        brand: zero,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Rubber bands', slug: 'zero-rubber-bands'),
          _category(id: 2, name: 'Highlighters', slug: 'zero-highlighters'),
          _category(id: 3, name: 'Markers', slug: 'deli-marker-pens'),
        ],
      );

      expect(result.map((category) => category.slug), <String>[
        'zero-highlighters',
        'zero-rubber-bands',
      ]);
    });

    test('links zidny categories only when slug has a zidny token', () {
      const zidny = BrandModel(
        id: 4,
        name: 'Zidny',
        slug: 'zidny',
        count: 1,
        imageUrl: '',
      );

      final result = _linker.findLinkedCategoriesForBrand(
        brand: zidny,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Pens', slug: 'zidny-pens'),
          _category(id: 2, name: 'Notebooks', slug: 'notebooks-zidny'),
          _category(id: 3, name: 'Markers', slug: 'school-zidny-markers'),
          _category(id: 4, name: 'Unsafe', slug: 'superzidny'),
        ],
      );

      expect(result.map((category) => category.slug), <String>[
        'school-zidny-markers',
        'notebooks-zidny',
        'zidny-pens',
      ]);
    });

    test('supports hyphenated brand slugs', () {
      const brand = BrandModel(
        id: 5,
        name: 'Alameer Alsagheer',
        slug: 'alameer-alsagheer',
        count: 1,
        imageUrl: '',
      );

      final result = _linker.findLinkedCategoriesForBrand(
        brand: brand,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Root', slug: 'alameer-alsagheer'),
          _category(id: 2, name: 'Toys', slug: 'toys-alameer-alsagheer'),
        ],
      );

      expect(result.map((category) => category.id), <int>[1, 2]);
    });

    test('hides empty non-root categories under a brand', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(
            id: 1,
            name: 'Empty calculators',
            slug: 'deli-calculators',
            count: 0,
          ),
          _category(id: 2, name: 'Markers', slug: 'deli-marker-pens'),
        ],
      );

      expect(result.map((category) => category.id), <int>[2]);
    });

    test('keeps empty brand root when it owns visible children', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 10, name: 'Deli', slug: 'deli', count: 0),
          _category(
            id: 11,
            name: 'Calculators',
            slug: 'calculators',
            parentId: 10,
          ),
        ],
      );

      expect(result.map((category) => category.id), <int>[10, 11]);
    });

    test('product-derived ids link generic categories', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 42, name: 'Pencils', slug: 'pencils'),
          _category(id: 99, name: 'Games', slug: 'games'),
        ],
        productDerivedCategoryIds: <int>{42},
      );

      expect(result.map((category) => category.id), <int>[42]);
    });
  });
}
