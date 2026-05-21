import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';

void main() {
  test(
    'filters resolved brand categories by available product category ids',
    () {
      const resolver = BrandScopedCategoryResolver();
      const brand = BrandModel(
        id: 1,
        name: 'Deli',
        slug: 'deli',
        count: 10,
        imageUrl: '',
      );
      const available = CategoryModel(
        id: 10,
        name: 'Deli pens',
        slug: 'deli-pens',
        count: 4,
        imageUrl: '',
      );
      const unavailable = CategoryModel(
        id: 20,
        name: 'Deli binders',
        slug: 'deli-binders',
        count: 3,
        imageUrl: '',
      );

      final resolved = resolver.resolve(
        brand: brand,
        brandSlug: brand.slug,
        brandTitle: brand.name,
        categories: const <CategoryModel>[available, unavailable],
      );
      final filtered = resolver.filterByAvailableCategories(
        menu: resolved!,
        availableCategoryIds: <int>{available.id},
      );

      expect(filtered!.items.map((item) => item.categoryId), <int>[
        available.id,
      ]);
    },
  );
}
