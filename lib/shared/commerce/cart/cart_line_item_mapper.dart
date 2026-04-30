import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';

List<Map<String, dynamic>> mapCartItemsToLineItems(
  Iterable<CartItemModel> items,
) {
  return items.map(_mapSingleCartItem).toList(growable: false);
}

Map<String, dynamic> _mapSingleCartItem(CartItemModel item) {
  return <String, dynamic>{
    'product_id': item.productId,
    'variation_id': item.variationId,
    'quantity': item.quantity,
    'unit_type': item.unitType,
    'unit_name': item.unitLabel,
    'unit_multiplier_pieces': item.piecesCount ?? 1,
    'unit_price': item.unitPrice,
    'color_slug': item.colorSlug,
    'color_name': item.colorName,
    'attributes': item.selectedVariants,
    'meta_data': _buildMetaData(item),
  };
}

List<Map<String, dynamic>> _buildMetaData(CartItemModel item) {
  return <Map<String, dynamic>>[
    <String, dynamic>{'key': 'unit_type', 'value': item.unitType},
    <String, dynamic>{'key': 'unit_name', 'value': item.unitLabel},
    <String, dynamic>{
      'key': 'unit_multiplier_pieces',
      'value': item.piecesCount ?? 1,
    },
    <String, dynamic>{'key': 'unit_price', 'value': item.unitPrice},
    if (item.variationId != null)
      <String, dynamic>{'key': 'variation_id', 'value': item.variationId},
    if (item.colorSlug != null)
      <String, dynamic>{'key': 'color_slug', 'value': item.colorSlug},
    if (item.colorName != null)
      <String, dynamic>{'key': 'color_name', 'value': item.colorName},
    ...item.selectedVariants.entries.map(
      (entry) => <String, dynamic>{
        'key': 'attribute_${entry.key}',
        'value': entry.value,
      },
    ),
  ];
}
