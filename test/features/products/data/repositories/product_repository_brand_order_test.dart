import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lpco_llc/core/local/catalog_local_store.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDioClient implements DioClient {
  @override
  late Dio dio;

  @override
  late CacheOptions cacheOptions;

  _FakeDioClient(this.dio);

  @override
  Options buildOptions({
    bool skipAuth = false,
    bool skipDeviceToken = false,
    bool includeDeviceToken = false,
    CachePolicy? cachePolicy,
    Duration? maxStale,
    Map<String, dynamic>? extra,
  }) {
    return Options(
      extra: <String, dynamic>{
        if (skipAuth) 'skipAuth': true,
        if (skipDeviceToken) 'skipDeviceToken': true,
        if (includeDeviceToken) 'includeDeviceToken': true,
        ...?extra,
      },
    );
  }

  @override
  Options buildNoCacheOptions({
    bool skipAuth = false,
    bool skipDeviceToken = false,
    bool includeDeviceToken = false,
    Map<String, dynamic>? extra,
  }) {
    return buildOptions(
      skipAuth: skipAuth,
      skipDeviceToken: skipDeviceToken,
      includeDeviceToken: includeDeviceToken,
      cachePolicy: CachePolicy.noCache,
      extra: extra,
    );
  }

  @override
  Future<void> clearHttpCache() async {}

  @override
  Future<void> init() async {}
}

class _ProductsPlusAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final payload = <String, dynamic>{
      'data': <Map<String, dynamic>>[
        _rawProduct(30, 'Deli third', customOrder: 300),
        _rawProduct(10, 'Deli first', customOrder: 100),
        _rawProduct(20, 'Deli second', customOrder: 200),
      ],
      'meta': <String, dynamic>{
        'page': 1,
        'per_page': 20,
        'count': 3,
        'total': 3,
        'total_pages': 1,
      },
    };
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BrandsAdapter implements HttpClientAdapter {
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    queries.add(Map<String, dynamic>.from(options.queryParameters));

    final payload = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'Deli',
        'slug': 'deli',
        'count': 3,
        'image_url': '',
      },
    ];
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CategoriesAdapter implements HttpClientAdapter {
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'name': 'Stationery',
          'slug': 'stationery',
          'parent': 0,
          'count': 3,
          'image_url': '',
          'show_in_app': true,
          'hidden': false,
        },
      ]),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = StorageService();
    storage.secureStorage = const FlutterSecureStorage();
    storage.sharedPreferences = await SharedPreferences.getInstance();

    hiveDir = await Directory.systemTemp.createTemp('brand_order_test');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageService.catalogBoxName);
    await Hive.openBox(StorageService.searchIndexBoxName);
    await Hive.openBox(StorageService.syncMetaBoxName);
  });

  tearDown(() async {
    await Hive.box(StorageService.catalogBoxName).clear();
    await Hive.box(StorageService.searchIndexBoxName).clear();
    await Hive.box(StorageService.syncMetaBoxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test(
    'brand default request preserves API order and omits local stock order',
    () async {
      final adapter = _ProductsPlusAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/wp-json'));
      dio.httpClientAdapter = adapter;
      final repository = ProductRepository(dioClient: _FakeDioClient(dio));

      final page = await repository.getProductsPage(
        brandSlug: 'deli',
        perPage: 20,
        guest: true,
      );

      expect(page.products.map((product) => product.id), <int>[30, 10, 20]);
      final query = adapter.lastRequest?.queryParameters ?? <String, dynamic>{};
      expect(query['brand_slug'], 'deli');
      expect(query['include_gallery'], 1);
      expect(query.containsKey('stock_order'), isFalse);
      expect(query.containsKey('orderby'), isFalse);
      expect(query.containsKey('order'), isFalse);
    },
  );

  test(
    'local brand cache returns stored response order for default brand pages',
    () async {
      final store = CatalogLocalStore();
      await store.cacheProducts(
        scope: 'guest',
        products: <Map<String, dynamic>>[
          _rawProduct(
            30,
            'Deli third',
            customOrder: 300,
            stockStatus: 'outofstock',
          ),
          _rawProduct(10, 'Deli first', customOrder: 1, stockStatus: 'instock'),
        ],
        orderedBrandSlug: 'deli',
        replaceOrderedBrandIndex: true,
      );
      await store.cacheProducts(
        scope: 'guest',
        products: <Map<String, dynamic>>[
          _rawProduct(
            20,
            'Deli second',
            customOrder: 2,
            stockStatus: 'instock',
          ),
        ],
        orderedBrandSlug: 'deli',
      );

      final products = store.getProducts(
        scope: 'guest',
        brandSlug: 'deli',
        sortBy: 'default',
        perPage: 20,
      );

      expect(products.map((product) => product['id']), <int>[30, 10, 20]);
    },
  );

  test('general product sync does not rewrite stored brand order', () async {
    final store = CatalogLocalStore();
    await store.cacheProducts(
      scope: 'guest',
      products: <Map<String, dynamic>>[
        _rawProduct(30, 'Deli third', customOrder: 300),
        _rawProduct(10, 'Deli first', customOrder: 100),
      ],
      orderedBrandSlug: 'deli',
      replaceOrderedBrandIndex: true,
    );
    await store.cacheProducts(
      scope: 'guest',
      products: <Map<String, dynamic>>[
        _rawProduct(20, 'Deli general sync item', customOrder: 1),
      ],
    );

    final products = store.getProducts(
      scope: 'guest',
      brandSlug: 'deli',
      sortBy: 'default',
      perPage: 20,
    );

    expect(products.map((product) => product['id']), <int>[30, 10]);
    expect(store.getCategoryIdsForBrand(scope: 'guest', brandSlug: 'deli'), {
      7,
    });
  });

  test('authenticated brand fetch uses auth brands endpoint first', () async {
    final adapter = _BrandsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/wp-json'));
    dio.httpClientAdapter = adapter;
    final repository = ProductRepository(dioClient: _FakeDioClient(dio));

    final brands = await repository.getBrands();

    expect(brands.map((brand) => brand.slug), <String>['deli']);
    expect(adapter.paths.first, '/dms/v1/brands');
    expect(adapter.queries.first['per_page'], 50);
  });

  test('guest category fetch uses guest categories endpoint first', () async {
    final adapter = _CategoriesAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/wp-json'));
    dio.httpClientAdapter = adapter;
    final repository = ProductRepository(dioClient: _FakeDioClient(dio));

    final categories = await repository.getCategories(guest: true);

    expect(categories.map((category) => category.slug), <String>['stationery']);
    expect(adapter.paths.first, '/dms/v1/categories-guest');
    expect(adapter.queries.first['guest'], 1);
  });

  test(
    'authenticated category fetch uses auth categories endpoint first',
    () async {
      final adapter = _CategoriesAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/wp-json'));
      dio.httpClientAdapter = adapter;
      final repository = ProductRepository(dioClient: _FakeDioClient(dio));

      final categories = await repository.getCategories();

      expect(categories.map((category) => category.slug), <String>[
        'stationery',
      ]);
      expect(adapter.paths.first, '/dms/v1/categories');
      expect(adapter.queries.first.containsKey('guest'), isFalse);
    },
  );

  test('cached brands exclude hidden and app-disabled entries', () async {
    await CatalogLocalStore().cacheBrands(
      scope: 'guest',
      brands: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Visible',
          'slug': 'visible',
          'count': 2,
          'image_url': '',
          'show_in_app': true,
          'hidden': false,
        },
        <String, dynamic>{
          'id': 2,
          'name': 'Hidden',
          'slug': 'hidden',
          'count': 2,
          'image_url': '',
          'hidden': true,
        },
        <String, dynamic>{
          'id': 3,
          'name': 'Disabled',
          'slug': 'disabled',
          'count': 2,
          'image_url': '',
          'show_in_app': false,
        },
      ],
    );

    final brands = await ProductRepository().getCachedBrands(guest: true);

    expect(brands.map((brand) => brand.slug), <String>['visible']);
  });

  test('catalog revision cache clear removes stale term counts', () async {
    final store = CatalogLocalStore();
    await store.cacheCategories(
      scope: 'guest',
      categories: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'name': 'Stationery',
          'slug': 'stationery',
          'parent': 0,
          'count': 1,
          'image_url': '',
          'menu_order': 0,
        },
      ],
    );
    await store.cacheBrands(
      scope: 'guest',
      brands: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Deli',
          'slug': 'deli',
          'count': 1,
          'image_url': '',
        },
      ],
    );

    expect(store.getCategories(scope: 'guest'), isNotEmpty);
    expect(store.getBrands(scope: 'guest'), isNotEmpty);

    await store.clearAllCatalogProducts();

    expect(store.getCategories(scope: 'guest'), isEmpty);
    expect(store.getBrands(scope: 'guest'), isEmpty);
  });

  test('getCachedBrands excludes hidden brands', () async {
    final store = CatalogLocalStore();
    await store.cacheBrands(
      scope: 'guest',
      brands: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Visible Brand',
          'slug': 'visible',
          'count': 5,
          'image_url': '',
          'show_in_app': true,
          'hidden': false,
        },
        <String, dynamic>{
          'id': 2,
          'name': 'Hidden Brand',
          'slug': 'hidden',
          'count': 3,
          'image_url': '',
          'show_in_app': false,
          'hidden': true,
        },
        <String, dynamic>{
          'id': 3,
          'name': 'App Disabled Brand',
          'slug': 'app-disabled',
          'count': 2,
          'image_url': '',
          'dms_hide_in_app': true,
        },
      ],
    );

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/wp-json'));
    final repo = ProductRepository(dioClient: _FakeDioClient(dio));
    final brands = await repo.getCachedBrands(guest: true);

    expect(brands.length, 1);
    expect(brands.first.slug, 'visible');
  });
}

Map<String, dynamic> _rawProduct(
  int id,
  String name, {
  required int customOrder,
  String stockStatus = 'instock',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'slug': 'product-$id',
    'sku': 'SKU-$id',
    'description': '',
    'short_description': '',
    'permalink': '',
    'price': '$id',
    'regular_price': '$id',
    'sale_price': '',
    'custom_order': customOrder,
    'stock_status': stockStatus,
    'in_stock': stockStatus == 'instock',
    'stock_quantity': stockStatus == 'instock' ? 10 : 0,
    'brand': <String, dynamic>{
      'id': 1,
      'name': 'Deli',
      'slug': 'deli',
      'image_url': '',
    },
    'brands': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'Deli',
        'slug': 'deli',
        'image_url': '',
      },
    ],
    'categories': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 7,
        'name': 'Arabic stationery',
        'slug': 'stationery',
      },
    ],
    'images': const <Map<String, dynamic>>[],
    'variations': const <Map<String, dynamic>>[],
    'color_options': const <Map<String, dynamic>>[],
    'attributes': const <Map<String, dynamic>>[],
    'meta_data': const <Map<String, dynamic>>[],
    'unit_options': const <Map<String, dynamic>>[],
    'unit_display_default_ar': 'قطعة',
  };
}
