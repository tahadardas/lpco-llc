import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/utils/price_parser.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/shared/commerce/wholesale/product_units/wholesale_product_units_resolver.dart';

class OrderPriceConflict {
  final int productId;
  final String code;
  final String message;
  final String unitType;
  final int quantity;
  final num localUnitPrice;
  final num? serverUnitPrice;
  final bool blocking;

  const OrderPriceConflict({
    required this.productId,
    required this.code,
    required this.message,
    required this.unitType,
    required this.quantity,
    required this.localUnitPrice,
    required this.serverUnitPrice,
    required this.blocking,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product_id': productId,
      'code': code,
      'message': message,
      'unit_type': unitType,
      'quantity': quantity,
      'local_unit_price': localUnitPrice,
      'server_unit_price': serverUnitPrice,
      'blocking': blocking,
    };
  }
}

class OrderStalePriceValidationResult {
  final List<OrderPriceConflict> conflicts;

  const OrderStalePriceValidationResult({
    this.conflicts = const <OrderPriceConflict>[],
  });

  bool get isValid => conflicts.isEmpty;
  bool get hasBlockingConflicts =>
      conflicts.any((conflict) => conflict.blocking);
}

class OrderStalePriceValidator {
  final ProductRepository _productRepository;
  final Future<List<ProductModel>> Function(List<int> productIds)?
  _productFetcher;

  OrderStalePriceValidator({
    ProductRepository? productRepository,
    Future<List<ProductModel>> Function(List<int> productIds)? productFetcher,
  }) : _productRepository = productRepository ?? ProductRepository(),
       _productFetcher = productFetcher;

  Future<OrderStalePriceValidationResult> validateOrderPayload(
    Map<String, dynamic> orderPayload, {
    bool guest = false,
  }) async {
    final rawItems = orderPayload['line_items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return const OrderStalePriceValidationResult();
    }

    final itemMaps = rawItems
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    if (itemMaps.isEmpty) {
      return const OrderStalePriceValidationResult();
    }

    final ids = itemMaps
        .map((item) => _toInt(item['product_id']))
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return const OrderStalePriceValidationResult();
    }

    final products = _productFetcher != null
        ? await _productFetcher(ids)
        : await _productRepository.getProductsByIds(ids, guest: guest);
    final byId = <int, ProductModel>{for (final p in products) p.id: p};
    final snapshotByKey = _buildSnapshotPriceMap(
      orderPayload['price_snapshot'],
    );
    final currencyCode = AppCurrencies.normalizeCode(orderPayload['currency']);
    final userGroup = TextSanitizer.fix(
      orderPayload['user_group'] ?? orderPayload['group'],
    );
    final conflicts = <OrderPriceConflict>[];

    for (final item in itemMaps) {
      final productId = _toInt(item['product_id']);
      if (productId <= 0) {
        continue;
      }

      final quantity = _toInt(item['quantity'], fallback: 0);
      final unitType = TextSanitizer.fix(item['unit_type']).toLowerCase();
      var localUnitPrice = PriceParser.parse(item['unit_price'], fallback: 0);
      if (localUnitPrice <= 0) {
        localUnitPrice = _extractSnapshotPrice(
          snapshotByKey: snapshotByKey,
          productId: productId,
          variationId: _toInt(item['variation_id']),
          unitType: unitType,
        );
      }
      final product = byId[productId];

      if (quantity <= 0) {
        conflicts.add(
          OrderPriceConflict(
            productId: productId,
            code: 'invalid_quantity',
            message: 'الكمية غير صالحة للمنتج #$productId.',
            unitType: unitType,
            quantity: quantity,
            localUnitPrice: localUnitPrice,
            serverUnitPrice: null,
            blocking: true,
          ),
        );
        continue;
      }

      if (product == null) {
        conflicts.add(
          OrderPriceConflict(
            productId: productId,
            code: 'product_missing',
            message: 'المنتج #$productId غير متاح حالياً.',
            unitType: unitType,
            quantity: quantity,
            localUnitPrice: localUnitPrice,
            serverUnitPrice: null,
            blocking: true,
          ),
        );
        continue;
      }

      if (!product.inStock) {
        conflicts.add(
          OrderPriceConflict(
            productId: productId,
            code: 'out_of_stock',
            message: 'المنتج "${product.name}" غير متوفر حالياً.',
            unitType: unitType,
            quantity: quantity,
            localUnitPrice: localUnitPrice,
            serverUnitPrice: null,
            blocking: true,
          ),
        );
        continue;
      }

      final expectedPrice =
          WholesaleProductUnitsResolver.resolveExpectedUnitPrice(
            product: product,
            unitType: unitType,
            currencyCode: currencyCode,
            userGroup: userGroup,
          );
      if (expectedPrice == null || expectedPrice <= 0) {
        conflicts.add(
          OrderPriceConflict(
            productId: productId,
            code: 'unit_unavailable',
            message: 'الوحدة المختارة للمنتج "${product.name}" لم تعد متاحة.',
            unitType: unitType,
            quantity: quantity,
            localUnitPrice: localUnitPrice,
            serverUnitPrice: expectedPrice,
            blocking: true,
          ),
        );
        continue;
      }

      if (localUnitPrice > 0 &&
          (localUnitPrice - expectedPrice).abs() > 0.009) {
        conflicts.add(
          OrderPriceConflict(
            productId: productId,
            code: 'price_changed',
            message:
                'سعر المنتج "${product.name}" تغير منذ إنشاء الطلب المحلي.',
            unitType: unitType,
            quantity: quantity,
            localUnitPrice: localUnitPrice,
            serverUnitPrice: expectedPrice,
            blocking: true,
          ),
        );
      }
    }

    return OrderStalePriceValidationResult(conflicts: conflicts);
  }

  Map<String, num> _buildSnapshotPriceMap(dynamic rawSnapshot) {
    if (rawSnapshot is! List) {
      return const <String, num>{};
    }

    final map = <String, num>{};
    for (final raw in rawSnapshot.whereType<Map>()) {
      final entry = Map<String, dynamic>.from(raw);
      final productId = _toInt(entry['product_id']);
      if (productId <= 0) {
        continue;
      }
      final variationId = _toInt(entry['variation_id']);
      final unitType = TextSanitizer.fix(entry['unit_type']).toLowerCase();
      final price = PriceParser.parse(entry['unit_price'], fallback: 0);
      if (price <= 0) {
        continue;
      }
      map[_snapshotKey(productId, variationId, unitType)] = price;
    }
    return map;
  }

  num _extractSnapshotPrice({
    required Map<String, num> snapshotByKey,
    required int productId,
    required int variationId,
    required String unitType,
  }) {
    final direct =
        snapshotByKey[_snapshotKey(productId, variationId, unitType)];
    if (direct != null && direct > 0) {
      return direct;
    }
    final fallback = snapshotByKey[_snapshotKey(productId, 0, unitType)];
    if (fallback != null && fallback > 0) {
      return fallback;
    }
    return 0;
  }

  String _snapshotKey(int productId, int variationId, String unitType) {
    final normalizedUnit = unitType.trim().toLowerCase();
    return '$productId::$variationId::$normalizedUnit';
  }

  int _toInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse('${raw ?? ''}') ?? fallback;
  }
}
