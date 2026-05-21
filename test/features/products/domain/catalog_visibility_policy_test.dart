import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/domain/catalog_visibility_policy.dart';

void main() {
  group('CatalogVisibilityPolicy', () {
    test('hides brand with zero products', () {
      expect(CatalogVisibilityPolicy.isVisibleBrand(_brand(count: 0)), isFalse);
    });

    test('hides hidden brand', () {
      expect(
        CatalogVisibilityPolicy.isVisibleBrand(_brand(hidden: true)),
        isFalse,
      );
    });

    test('hides leaf category with zero products', () {
      expect(
        CatalogVisibilityPolicy.isVisibleLeafCategory(
          _category(id: 2, count: 0),
        ),
        isFalse,
      );
    });

    test('shows zero-count parent with a visible child', () {
      final parent = _category(id: 1, count: 0);
      final children = CatalogVisibilityPolicy.visibleCategoryChildren(
        parent,
        <CategoryModel>[parent, _category(id: 2, parentId: 1, count: 3)],
      );

      expect(
        CatalogVisibilityPolicy.isVisibleParentCategory(parent, children),
        isTrue,
      );
    });

    test('hides zero-count parent without a visible child', () {
      final parent = _category(id: 1, count: 0);
      final children = CatalogVisibilityPolicy.visibleCategoryChildren(
        parent,
        <CategoryModel>[parent, _category(id: 2, parentId: 1, count: 0)],
      );

      expect(
        CatalogVisibilityPolicy.isVisibleParentCategory(parent, children),
        isFalse,
      );
    });
  });
}

BrandModel _brand({int count = 1, bool hidden = false}) {
  return BrandModel(
    id: 1,
    name: 'Visible brand',
    slug: 'visible-brand',
    count: count,
    imageUrl: '',
    hidden: hidden,
  );
}

CategoryModel _category({
  required int id,
  required int count,
  int parentId = 0,
}) {
  return CategoryModel(
    id: id,
    name: 'Category $id',
    slug: 'category-$id',
    parentId: parentId,
    count: count,
    imageUrl: '',
  );
}
