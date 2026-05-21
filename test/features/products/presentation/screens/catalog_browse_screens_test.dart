import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/home_banner_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/screens/brands_screen.dart';
import 'package:lpco_llc/features/products/presentation/screens/categories_screen.dart';

class _BrowseCategoryRepository extends ProductRepository {
  static const categories = <CategoryModel>[
    CategoryModel(
      id: 1,
      name: 'Parent category',
      slug: 'parent-category',
      count: 3,
      imageUrl: '',
    ),
    CategoryModel(
      id: 2,
      name: 'Child category',
      slug: 'child-category',
      parentId: 1,
      count: 2,
      imageUrl: '',
    ),
  ];

  @override
  Future<List<CategoryModel>> getCachedCategories({bool guest = false}) async {
    return const <CategoryModel>[];
  }

  @override
  Future<List<CategoryModel>> getCategories({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    return categories;
  }
}

class _BrowseBrandsRepository extends ProductRepository {
  var brandsRequested = false;

  @override
  Future<bool> syncCatalogRevision({bool guest = false}) async => false;

  @override
  Future<List<ProductModel>> getCachedProducts({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? sortBy,
    bool guest = false,
  }) async {
    return const <ProductModel>[];
  }

  @override
  Future<List<CategoryModel>> getCachedCategories({bool guest = false}) async {
    return const <CategoryModel>[];
  }

  @override
  Future<List<BrandModel>> getCachedBrands({bool guest = false}) async {
    return const <BrandModel>[];
  }

  @override
  Future<HomeBannerData> getCachedHomeBannerData({bool guest = true}) async {
    return const HomeBannerData.empty();
  }

  @override
  Future<List<HomeBannerSlideData>> getCachedHomeBannersData({
    bool guest = true,
  }) async {
    return const <HomeBannerSlideData>[];
  }

  @override
  Future<CatalogProductsPage> getProductsPage({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    String? search,
    String? brandSlug,
    String stock = 'all',
    String? orderBy,
    String? order,
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    return const CatalogProductsPage(
      products: <ProductModel>[],
      meta: CatalogResponseMeta(page: 1, perPage: 20, count: 0),
    );
  }

  @override
  Future<List<CategoryModel>> getCategories({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    return const <CategoryModel>[
      CategoryModel(
        id: 10,
        name: 'Writing',
        slug: 'writing',
        count: 4,
        imageUrl: '',
      ),
    ];
  }

  @override
  Future<List<BrandModel>> getBrands({
    bool guest = false,
    bool forceRefresh = false,
  }) async {
    brandsRequested = true;
    return const <BrandModel>[
      BrandModel(
        id: 4,
        name: 'Loaded brand',
        slug: 'loaded-brand',
        count: 4,
        imageUrl: '',
      ),
    ];
  }

  @override
  Future<HomeBannerData> getHomeBannerData({
    bool guest = true,
    bool forceRefresh = false,
  }) async {
    return const HomeBannerData.empty();
  }

  @override
  Future<List<HomeBannerSlideData>> getHomeBannersData({
    bool guest = true,
    bool forceRefresh = false,
  }) async {
    return const <HomeBannerSlideData>[];
  }

  @override
  Set<int> getActiveCategoryIdsForBrand(String brandSlug, {String? scope}) {
    return const <int>{};
  }
}

void main() {
  testWidgets('CategoriesScreen expands children and opens child category id', (
    tester,
  ) async {
    final repository = _BrowseCategoryRepository();
    final router = GoRouter(
      initialLocation: AppRoutePaths.categories,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutePaths.categories,
          builder: (context, state) =>
              CategoriesScreen(repository: repository, isGuestOverride: true),
        ),
        GoRoute(
          path: AppRoutePaths.categoriesCatalog,
          builder: (context, state) => Scaffold(
            body: Text('category-id:${state.uri.queryParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Parent category'), findsOneWidget);
    expect(find.text('Child category'), findsNothing);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Child category'), findsOneWidget);

    await tester.tap(find.text('Child category'));
    await tester.pumpAndSettle();

    expect(find.text('category-id:2'), findsOneWidget);
  });

  testWidgets('BrandsScreen loads brands when ProductCubit starts empty', (
    tester,
  ) async {
    final repository = _BrowseBrandsRepository();
    final productCubit = ProductCubit(repository: repository);
    addTearDown(productCubit.close);

    await tester.pumpWidget(
      BlocProvider<ProductCubit>.value(
        value: productCubit,
        child: const MaterialApp(home: BrandsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.brandsRequested, isTrue);
    expect(find.text('Loaded brand'), findsWidgets);
  });
}
