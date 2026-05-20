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
  final List<ProductModel> cachedProducts;
  final Map<int, List<ProductModel>> pagedProducts;
  final Duration remoteDelay;
  final List<ProductSearchQuery> queries = <ProductSearchQuery>[];

  _FakeProductRepository({
    required this.categories,
    required this.products,
    this.cachedProducts = const <ProductModel>[],
    this.pagedProducts = const <int, List<ProductModel>>{},
    this.remoteDelay = Duration.zero,
  });

  @override
  Future<List<CategoryModel>> getCategories({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    return categories;
  }

  @override
  Future<List<ProductModel>> searchProductsWithFilters({
    required ProductSearchQuery query,
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    return products;
  }

  @override
  Future<CatalogProductsPage> searchProductsWithFiltersPage({
    required ProductSearchQuery query,
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    queries.add(query);
    if (remoteDelay > Duration.zero) {
      await Future<void>.delayed(remoteDelay);
    }
    final pageProducts = pagedProducts.isEmpty
        ? products
        : pagedProducts[query.page] ?? const <ProductModel>[];
    final totalPages = pagedProducts.isEmpty
        ? 1
        : pagedProducts.keys.fold<int>(
            0,
            (max, page) => page > max ? page : max,
          );
    final total = pagedProducts.isEmpty
        ? products.length
        : pagedProducts.values.fold<int>(
            0,
            (count, page) => count + page.length,
          );
    return CatalogProductsPage(
      products: pageProducts,
      meta: CatalogResponseMeta(
        page: query.page,
        perPage: query.perPage,
        count: pageProducts.length,
        total: total,
        totalPages: totalPages <= 0 ? 1 : totalPages,
      ),
    );
  }

  @override
  Future<List<ProductModel>> getCachedProducts({
    int page = 1,
    int perPage = 12,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? sortBy,
    bool guest = false,
  }) async {
    return cachedProducts;
  }

  @override
  Future<bool> syncCatalogRevision({bool guest = false}) async {
    return false;
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

  test(
    'initialize keeps brand scope even when API returns mixed brands',
    () async {
      const calculatorsCategory = CategoryModel(
        id: 170,
        name: 'آلات حاسبة',
        slug: 'calculators',
        count: 27,
        imageUrl: '',
      );

      final repository = _FakeProductRepository(
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
      );
      final cubit = SearchFilterCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.initialize(
        isGuest: true,
        extraParams: const <String, dynamic>{'brand_slug': 'deli'},
        initialCuratedCategorySlug: 'calculators',
      );

      expect(cubit.state.status, SearchFilterStatus.loaded);
      expect(cubit.state.query.categoryIds, <int>[170]);
      expect(repository.queries.first.categoryIds, <int>[170]);
      expect(cubit.state.products.map((product) => product.id), <int>[1]);
      expect(cubit.state.products.first.brand?.slug, 'deli');
    },
  );

  test(
    'scoped listings keep loading instead of showing partial cached products',
    () async {
      final remoteProducts = <ProductModel>[
        _buildProduct(
          id: 101,
          name: 'Deli cached item',
          brandSlug: 'deli',
          brandName: 'Deli',
          categories: const <ProductCategoryRef>[],
        ),
        _buildProduct(
          id: 102,
          name: 'Deli remote item 2',
          brandSlug: 'deli',
          brandName: 'Deli',
          categories: const <ProductCategoryRef>[],
        ),
        _buildProduct(
          id: 103,
          name: 'Deli remote item 3',
          brandSlug: 'deli',
          brandName: 'Deli',
          categories: const <ProductCategoryRef>[],
        ),
      ];
      final cubit = SearchFilterCubit(
        repository: _FakeProductRepository(
          categories: const <CategoryModel>[],
          products: remoteProducts,
          cachedProducts: <ProductModel>[remoteProducts.first],
          remoteDelay: const Duration(milliseconds: 80),
        ),
      );
      addTearDown(cubit.close);

      final initializeFuture = cubit.initialize(
        isGuest: true,
        extraParams: const <String, dynamic>{'brand_slug': 'deli'},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.status, SearchFilterStatus.loading);
      expect(cubit.state.products, isEmpty);

      await initializeFuture;

      expect(cubit.state.status, SearchFilterStatus.loaded);
      expect(cubit.state.products.map((product) => product.id), <int>[
        101,
        102,
        103,
      ]);
    },
  );

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

  test(
    'scans later pages for brand scoped curated category on initial load',
    () async {
      final cubit = SearchFilterCubit(
        repository: _FakeProductRepository(
          categories: const <CategoryModel>[],
          products: const <ProductModel>[],
          pagedProducts: <int, List<ProductModel>>{
            1: <ProductModel>[
              _buildProduct(
                id: 21,
                name: 'Zero gel pen',
                brandSlug: 'zero-miss',
                brandName: 'Zero Miss',
                categories: const <ProductCategoryRef>[
                  ProductCategoryRef(
                    id: 51,
                    name: 'Gel pens',
                    slug: 'gel-ink-pens',
                  ),
                ],
              ),
            ],
            2: <ProductModel>[
              _buildProduct(
                id: 22,
                name: 'Zero ballpoint pen',
                brandSlug: 'zero-miss',
                brandName: 'Zero Miss',
                categories: const <ProductCategoryRef>[
                  ProductCategoryRef(
                    id: 46,
                    name: 'Ballpoint pens',
                    slug: 'ballpoint-pens',
                  ),
                ],
              ),
            ],
          },
        ),
      );
      addTearDown(cubit.close);

      await cubit.initialize(
        isGuest: true,
        extraParams: const <String, dynamic>{'brand_slug': 'zero-miss'},
        initialCuratedCategorySlug: 'ballpoint-pens',
      );

      expect(cubit.state.status, SearchFilterStatus.loaded);
      expect(cubit.state.products.map((product) => product.id), <int>[22]);
      expect(cubit.state.query.page, 2);
    },
  );

  test('loadMore skips non matching brand scoped pages', () async {
    final cubit = SearchFilterCubit(
      repository: _FakeProductRepository(
        categories: const <CategoryModel>[],
        products: const <ProductModel>[],
        pagedProducts: <int, List<ProductModel>>{
          1: <ProductModel>[
            _buildProduct(
              id: 31,
              name: 'Zero ballpoint pen 1',
              brandSlug: 'zero-miss',
              brandName: 'Zero Miss',
              categories: const <ProductCategoryRef>[
                ProductCategoryRef(
                  id: 46,
                  name: 'Ballpoint pens',
                  slug: 'ballpoint-pens',
                ),
              ],
            ),
          ],
          2: <ProductModel>[
            _buildProduct(
              id: 32,
              name: 'Zero gel pen',
              brandSlug: 'zero-miss',
              brandName: 'Zero Miss',
              categories: const <ProductCategoryRef>[
                ProductCategoryRef(
                  id: 51,
                  name: 'Gel pens',
                  slug: 'gel-ink-pens',
                ),
              ],
            ),
          ],
          3: <ProductModel>[
            _buildProduct(
              id: 33,
              name: 'Zero ballpoint pen 2',
              brandSlug: 'zero-miss',
              brandName: 'Zero Miss',
              categories: const <ProductCategoryRef>[
                ProductCategoryRef(
                  id: 46,
                  name: 'Ballpoint pens',
                  slug: 'ballpoint-pens',
                ),
              ],
            ),
          ],
        },
      ),
    );
    addTearDown(cubit.close);

    await cubit.initialize(
      isGuest: true,
      extraParams: const <String, dynamic>{'brand_slug': 'zero-miss'},
      initialCuratedCategorySlug: 'ballpoint-pens',
    );
    await cubit.loadMore();

    expect(cubit.state.status, SearchFilterStatus.loaded);
    expect(cubit.state.products.map((product) => product.id), <int>[31, 33]);
    expect(cubit.state.query.page, 3);
    expect(cubit.state.hasMore, isFalse);
  });
}
