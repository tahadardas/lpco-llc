import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/features/products/presentation/cubit/search_filter_cubit.dart';

class _FakeProductRepository extends ProductRepository {
  final List<CategoryModel> categories;
  final List<ProductModel> products;

  _FakeProductRepository({
    required this.categories,
    required this.products,
  });

  @override
  Future<List<CategoryModel>> getCategories({bool guest = false}) async {
    return categories;
  }

  @override
  Future<List<ProductModel>> searchProductsWithFilters({
    required ProductSearchQuery query,
    bool guest = false,
  }) async {
    return products;
  }
}

ProductModel _buildProduct({
  required int id,
  required String name,
  required String brandSlug,
  required String brandName,
  required List<ProductCategoryRef> categories,
}) {
  return ProductModel(
    id: id,
    customOrder: id,
    name: name,
    slug: 'product-$id',
    sku: 'SKU-$id',
    description: '',
    shortDescription: '',
    permalink: '',
    price: '0',
    regularPrice: '0',
    salePrice: '',
    stockStatus: 'instock',
    inStock: true,
    stockQuantity: 10,
    images: const <ProductImage>[],
    variations: const <ProductVariation>[],
    colorOptions: const <ColorOption>[],
    attributes: const <ProductAttribute>[],
    categories: categories,
    brand: ProductBrandRef(
      id: id,
      name: brandName,
      slug: brandSlug,
      imageUrl: '',
    ),
    metaData: const <ProductMetaEntry>[],
    unitOptions: const <UnitOption>[],
    packSize: 1,
    pricePerPiece: 0,
    pricePerPack: 0,
    unitDisplayDefaultAr: 'قطعة',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('search_filter_cubit_test');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageService.recentSearchesBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test('initialize keeps brand scope even when API returns mixed brands', () async {
    const calculatorsCategory = CategoryModel(
      id: 170,
      name: 'آلات حاسبة',
      slug: 'calculators',
      count: 27,
      imageUrl: '',
    );

    final cubit = SearchFilterCubit(
      repository: _FakeProductRepository(
        categories: const <CategoryModel>[calculatorsCategory],
        products: <ProductModel>[
          _buildProduct(
            id: 1,
            name: 'آلة حاسبة ديلي',
            brandSlug: 'deli',
            brandName: 'ديلي',
            categories: const <ProductCategoryRef>[
              ProductCategoryRef(
                id: 170,
                name: 'آلات حاسبة',
                slug: 'calculators',
              ),
            ],
          ),
          _buildProduct(
            id: 2,
            name: 'آلة حاسبة أمير صغير',
            brandSlug: 'alameer-alsagheer',
            brandName: 'الأمير الصغير',
            categories: const <ProductCategoryRef>[
              ProductCategoryRef(
                id: 170,
                name: 'آلات حاسبة',
                slug: 'calculators',
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(cubit.close);

    await cubit.initialize(
      isGuest: true,
      extraParams: const <String, dynamic>{'brand_slug': 'deli'},
      initialCuratedCategorySlug: 'calculators',
    );

    expect(cubit.state.status, SearchFilterStatus.loaded);
    expect(cubit.state.query.categoryIds, <int>[170]);
    expect(cubit.state.products.map((product) => product.id), <int>[1]);
    expect(cubit.state.products.first.brand?.slug, 'deli');
  });

  test(
    'falls back to local category slug filtering when curated slug is unresolved',
    () async {
      final cubit = SearchFilterCubit(
        repository: _FakeProductRepository(
          categories: const <CategoryModel>[],
          products: <ProductModel>[
            _buildProduct(
              id: 11,
              name: 'زيرو قلم حبر جاف',
              brandSlug: 'zero-miss',
              brandName: 'زيرو مس',
              categories: const <ProductCategoryRef>[
                ProductCategoryRef(
                  id: 46,
                  name: 'أقلام حبر جاف',
                  slug: 'ballpoint-pens',
                ),
              ],
            ),
            _buildProduct(
              id: 12,
              name: 'زيرو قلم جل',
              brandSlug: 'zero-miss',
              brandName: 'زيرو مس',
              categories: const <ProductCategoryRef>[
                ProductCategoryRef(
                  id: 51,
                  name: 'أقلام حبر جل',
                  slug: 'gel-ink-pens',
                ),
              ],
            ),
            _buildProduct(
              id: 13,
              name: 'أمير صغير قلم حبر جاف',
              brandSlug: 'alameer-alsagheer',
              brandName: 'الأمير الصغير',
              categories: const <ProductCategoryRef>[
                ProductCategoryRef(
                  id: 46,
                  name: 'أقلام حبر جاف',
                  slug: 'ballpoint-pens',
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(cubit.close);

      await cubit.initialize(
        isGuest: true,
        extraParams: const <String, dynamic>{'brand_slug': 'zero-miss'},
        initialCuratedCategorySlug: 'ballpoint-pens',
      );

      expect(cubit.state.status, SearchFilterStatus.loaded);
      expect(cubit.state.query.categoryIds, isEmpty);
      expect(cubit.state.products.map((product) => product.id), <int>[11]);
      expect(cubit.state.products.first.brand?.slug, 'zero-miss');
      expect(
        cubit.state.products.first.categories.first.slug,
        'ballpoint-pens',
      );
    },
  );
}
