import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/utils/price_parser.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class CartItemModel {
  final int productId;
  final String name;
  final String price;
  final String image;
  final Map<String, dynamic> selectedVariants;
  final String unitType;
  final String unitLabel;
  final String currency;
  final int? piecesCount;
  final int? variationId;
  final String? colorSlug;
  final String? colorName;
  int quantity;

  CartItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.selectedVariants,
    this.quantity = 1,
    this.unitType = 'piece',
    this.unitLabel = 'قطعة',
    this.currency = 'syp',
    this.piecesCount,
    this.variationId,
    this.colorSlug,
    this.colorName,
  });

  String get itemKey {
    final attrs =
        selectedVariants.entries.map((e) => '${e.key}:${e.value}').toList()
          ..sort();

    return [
      'product:$productId',
      'variation:${variationId ?? 'none'}',
      'color:${colorSlug ?? colorName ?? 'none'}',
      'unit:$unitType',
      'attrs:${attrs.join('|')}',
    ].join('|');
  }

  String get displayName {
    final normalized = name.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return productId > 0 ? 'منتج #$productId' : 'منتج';
  }

  num get unitPrice => PriceParser.parse(price);
  num get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'image': image,
      'selected_variants': selectedVariants,
      'quantity': quantity,
      'unit_type': unitType,
      'unit_label': unitLabel,
      'currency': currency,
      'pieces_count': piecesCount,
      'variation_id': variationId,
      'color_slug': colorSlug,
      'color_name': colorName,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse('${json['product_id'] ?? ''}') ?? 0,
      name: TextSanitizer.fix(
        json['name'] ??
            json['product_name'] ??
            json['title'] ??
            json['product_title'],
      ),
      price: PriceParser.parse(json['price']).toString(),
      image: TextSanitizer.fix(
        json['image'] ?? json['image_url'] ?? json['thumbnail'],
      ),
      selectedVariants: Map<String, dynamic>.from(
        (json['selected_variants'] ?? {}) as Map,
      ),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse('${json['quantity'] ?? '1'}') ?? 1,
      unitType: TextSanitizer.fix(json['unit_type'] ?? 'piece'),
      unitLabel: TextSanitizer.fix(json['unit_label'] ?? 'قطعة'),
      currency: AppCurrencies.normalizeCode(json['currency'] ?? 'syp'),
      piecesCount: json['pieces_count'] is int
          ? json['pieces_count'] as int
          : int.tryParse('${json['pieces_count'] ?? ''}'),
      variationId: json['variation_id'] is int
          ? json['variation_id'] as int
          : int.tryParse('${json['variation_id'] ?? ''}'),
      colorSlug: TextSanitizer.fix(json['color_slug']).isEmpty
          ? null
          : TextSanitizer.fix(json['color_slug']),
      colorName: TextSanitizer.fix(json['color_name']).isEmpty
          ? null
          : TextSanitizer.fix(json['color_name']),
    );
  }

  bool isSameVariant(CartItemModel other) {
    return itemKey == other.itemKey;
  }
}
