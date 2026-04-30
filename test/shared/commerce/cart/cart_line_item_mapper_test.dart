import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/shared/commerce/cart/cart_line_item_mapper.dart';

void main() {
  group('mapCartItemsToLineItems', () {
    test(
      'maps wholesale unit, price, currency-related fields and metadata',
      () {
        final items = <CartItemModel>[
          CartItemModel(
            productId: 42,
            name: 'منتج',
            price: '24.5',
            image: '',
            quantity: 3,
            unitType: 'pack',
            unitLabel: 'كرتونة',
            piecesCount: 12,
            variationId: 77,
            colorSlug: 'red',
            colorName: 'أحمر',
            selectedVariants: <String, dynamic>{
              'size': 'xl',
              'material': 'cotton',
            },
          ),
        ];

        final payload = mapCartItemsToLineItems(items);

        expect(payload, hasLength(1));
        final first = payload.first;
        expect(first['product_id'], 42);
        expect(first['variation_id'], 77);
        expect(first['quantity'], 3);
        expect(first['unit_type'], 'pack');
        expect(first['unit_name'], 'كرتونة');
        expect(first['unit_multiplier_pieces'], 12);
        expect(first['unit_price'], 24.5);
        expect(first['color_slug'], 'red');
        expect(first['color_name'], 'أحمر');
        expect(first['attributes'], <String, dynamic>{
          'size': 'xl',
          'material': 'cotton',
        });

        final metaData = (first['meta_data'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          metaData,
          containsAll(<Map<String, dynamic>>[
            <String, dynamic>{'key': 'unit_type', 'value': 'pack'},
            <String, dynamic>{'key': 'unit_name', 'value': 'كرتونة'},
            <String, dynamic>{'key': 'unit_multiplier_pieces', 'value': 12},
            <String, dynamic>{'key': 'unit_price', 'value': 24.5},
            <String, dynamic>{'key': 'variation_id', 'value': 77},
            <String, dynamic>{'key': 'color_slug', 'value': 'red'},
            <String, dynamic>{'key': 'color_name', 'value': 'أحمر'},
            <String, dynamic>{'key': 'attribute_size', 'value': 'xl'},
            <String, dynamic>{'key': 'attribute_material', 'value': 'cotton'},
          ]),
        );
      },
    );

    test('defaults pieces count to one and omits null optional metadata', () {
      final items = <CartItemModel>[
        CartItemModel(
          productId: 9,
          name: 'منتج بدون خيارات',
          price: '7',
          image: '',
          selectedVariants: const <String, dynamic>{},
          unitType: 'piece',
          unitLabel: 'قطعة',
        ),
      ];

      final payload = mapCartItemsToLineItems(items);
      final first = payload.first;
      expect(first['unit_multiplier_pieces'], 1);
      expect(first['variation_id'], isNull);
      expect(first['color_slug'], isNull);
      expect(first['color_name'], isNull);

      final metaData = (first['meta_data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(metaData.any((entry) => entry['key'] == 'variation_id'), isFalse);
      expect(metaData.any((entry) => entry['key'] == 'color_slug'), isFalse);
      expect(metaData.any((entry) => entry['key'] == 'color_name'), isFalse);
    });
  });
}
