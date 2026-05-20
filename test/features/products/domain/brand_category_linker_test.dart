import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/domain/brand_category_linker.dart';

const _linker = BrandCategoryLinker();
const _deli = BrandModel(
  id: 1,
  name: '\u062F\u0644\u064A',
  slug: 'deli',
  count: 0,
  imageUrl: '',
);

CategoryModel _category({
  required int id,
  required String name,
  required String slug,
  int parentId = 0,
  int menuOrder = 0,
}) {
  return CategoryModel(
    id: id,
    name: name,
    slug: slug,
    parentId: parentId,
    count: 0,
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

    test('links safe slug token matches', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Calculators', slug: 'deli-calculators'),
          _category(id: 2, name: 'Supplies', slug: 'deli-school-supplies'),
          _category(
            id: 3,
            name: 'Laminating',
            slug: 'thermal-laminating-machinesd-deli',
          ),
          _category(id: 4, name: 'Stationery', slug: 'my-deli-category'),
          _category(id: 5, name: 'Games', slug: 'games'),
        ],
      );

      expect(result.map((category) => category.id), <int>[1, 3, 4, 2]);
    });

    test('does not match unsafe substrings', () {
      const del = BrandModel(
        id: 2,
        name: 'Del',
        slug: 'del',
        count: 0,
        imageUrl: '',
      );

      final result = _linker.findLinkedCategoriesForBrand(
        brand: del,
        categories: <CategoryModel>[
          _category(id: 1, name: 'Deli Calculators', slug: 'deli-calculators'),
          _category(id: 2, name: 'Del Category', slug: 'del-category'),
        ],
      );

      expect(result.map((category) => category.id), <int>[2]);
    });

    test('links normalized category names as a secondary rule', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(
            id: 1,
            name:
                '\u0622\u0644\u0627\u062A \u062D\u0627\u0633\u0628\u0629 \u062F\u0644\u064A',
            slug: 'calculators',
          ),
          _category(id: 2, name: 'School Supplies Deli', slug: 'supplies'),
          _category(id: 3, name: 'Deliware', slug: 'deliware'),
        ],
      );

      expect(
        result.map((category) => category.id),
        unorderedEquals(<int>[1, 2]),
      );
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

    test('sorts root first then menu order then normalized name', () {
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 30, name: 'B category', slug: 'deli-b', menuOrder: 2),
          _category(id: 10, name: 'Deli', slug: 'deli', menuOrder: 99),
          _category(id: 20, name: 'A category', slug: 'deli-a', menuOrder: 2),
          _category(id: 40, name: 'Z category', slug: 'deli-z', menuOrder: 1),
        ],
      );

      expect(result.map((category) => category.id), <int>[10, 40, 20, 30]);
    });

    test('uses backend linked ids and slugs when provided', () {
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
        ],
      );

      expect(result.map((category) => category.id), <int>[60, 50]);
    });

    test('supports hyphenated brand slugs', () {
      const brand = BrandModel(
        id: 3,
        name: 'Alameer Alsagheer',
        slug: 'alameer-alsagheer',
        count: 0,
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
    test('does not link generic slug without brand token', () {
      // 'pencils' should NOT match 'deli' by slug — it has no 'deli' token.
      // It can only match via product-derived or explicit backend linking.
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 1, name: 'أقلام رصاص', slug: 'pencils'),
          _category(id: 2, name: 'دفاتر', slug: 'notebooks'),
          _category(id: 3, name: 'آلات حاسبة', slug: 'calculators'),
        ],
      );

      // None of these generic slugs contain a 'deli' token
      expect(result, isEmpty);
    });

    test('Arabic name normalization handles hamza and taa marbuta', () {
      // 'آلات حاسبة ديلي' with آ → ا normalization should match brand 'دلي'
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(
            id: 1,
            name: '\u0622\u0644\u0627\u062A \u062D\u0627\u0633\u0628\u0629 \u062F\u0644\u064A',
            slug: 'generic-calculators',
          ),
          _category(id: 2, name: 'ألعاب', slug: 'games'),
        ],
      );

      expect(result.map((c) => c.id), <int>[1]);
    });

    test('product-derived IDs link categories without slug/name match', () {
      // 'pencils' has no brand token but IS in productDerivedCategoryIds
      final result = _linker.findLinkedCategoriesForBrand(
        brand: _deli,
        categories: <CategoryModel>[
          _category(id: 42, name: 'أقلام رصاص', slug: 'pencils'),
          _category(id: 99, name: 'Games', slug: 'games'),
        ],
        productDerivedCategoryIds: <int>{42},
      );

      expect(result.map((c) => c.id), <int>[42]);
    });
  });
}
