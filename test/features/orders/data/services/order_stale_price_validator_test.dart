import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/orders/data/services/order_stale_price_validator.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';

void main() {
  ProductModel makeProduct({
    required int id,
    required bool inStock,
    required num piecePrice,
    required num packPrice,
    List<UnitOption> unitOptions = const <UnitOption>[],
    List<ProductMetaEntry> metaData = const <ProductMetaEntry>[],
  }) {
    return ProductModel(
      id: id,
      customOrder: id,
      name: 'Product $id',
      slug: 'product-$id',
      sku: 'SKU-$id',
      description: '',
      shortDescription: '',
      permalink: '',
      price: piecePrice.toString(),
      regularPrice: piecePrice.toString(),
      salePrice: '',
      stockStatus: inStock ? 'instock' : 'outofstock',
      inStock: inStock,
      stockQuantity: inStock ? 100 : 0,
      images: const <ProductImage>[],
      variations: const <ProductVariation>[],
      colorOptions: const <ColorOption>[],
      attributes: const <ProductAttribute>[],
      categories: const <ProductCategoryRef>[],
      metaData: metaData,
      unitOptions: unitOptions,
      packSize: 1,
      pricePerPiece: piecePrice,
      pricePerPack: packPrice,
      unitDisplayDefaultAr: '',
    );
  }

  UnitOption unit({required String type, required num unitPrice}) {
    return UnitOption(
      type: type,
      labelDisplayAr: '',
      name: type,
      label: type,
      piecesCount: null,
      sypPiece: 0,
      usdPiece: 0,
      sypPack: 0,
      usdPack: 0,
      unitPrice: unitPrice,
      genericPrice: unitPrice,
    );
  }

  group('OrderStalePriceValidator', () {
    test(
      'returns no conflicts when payload matches current server prices',
      () async {
        final validator = OrderStalePriceValidator(
          productFetcher: (ids) async => <ProductModel>[
            makeProduct(
              id: 10,
              inStock: true,
              piecePrice: 10,
              packPrice: 90,
              unitOptions: <UnitOption>[unit(type: 'piece', unitPrice: 10)],
            ),
          ],
        );

        final result = await validator.validateOrderPayload(<String, dynamic>{
          'line_items': <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 10,
              'quantity': 2,
              'unit_type': 'piece',
              'unit_price': 10,
            },
          ],
        });

        expect(result.hasBlockingConflicts, isFalse);
        expect(result.conflicts, isEmpty);
      },
    );

    test('detects price_changed conflict', () async {
      final validator = OrderStalePriceValidator(
        productFetcher: (ids) async => <ProductModel>[
          makeProduct(
            id: 10,
            inStock: true,
            piecePrice: 12,
            packPrice: 100,
            unitOptions: <UnitOption>[unit(type: 'piece', unitPrice: 12)],
          ),
        ],
      );

      final result = await validator.validateOrderPayload(<String, dynamic>{
        'line_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 10,
            'quantity': 2,
            'unit_type': 'piece',
            'unit_price': 10,
          },
        ],
      });

      expect(result.hasBlockingConflicts, isTrue);
      expect(result.conflicts.first.code, 'price_changed');
    });

    test('detects out_of_stock conflict', () async {
      final validator = OrderStalePriceValidator(
        productFetcher: (ids) async => <ProductModel>[
          makeProduct(id: 33, inStock: false, piecePrice: 8, packPrice: 70),
        ],
      );

      final result = await validator.validateOrderPayload(<String, dynamic>{
        'line_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 33,
            'quantity': 1,
            'unit_type': 'piece',
            'unit_price': 8,
          },
        ],
      });

      expect(result.hasBlockingConflicts, isTrue);
      expect(result.conflicts.first.code, 'out_of_stock');
    });

    test(
      'uses price_snapshot when unit_price missing in queued payload',
      () async {
        final validator = OrderStalePriceValidator(
          productFetcher: (ids) async => <ProductModel>[
            makeProduct(
              id: 44,
              inStock: true,
              piecePrice: 15,
              packPrice: 120,
              unitOptions: <UnitOption>[unit(type: 'piece', unitPrice: 15)],
            ),
          ],
        );

        final result = await validator.validateOrderPayload(<String, dynamic>{
          'line_items': <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 44,
              'variation_id': 0,
              'quantity': 3,
              'unit_type': 'piece',
            },
          ],
          'price_snapshot': <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 44,
              'variation_id': 0,
              'quantity': 3,
              'unit_type': 'piece',
              'unit_price': 14,
            },
          ],
        });

        expect(result.hasBlockingConflicts, isTrue);
        expect(result.conflicts.first.code, 'price_changed');
        expect(result.conflicts.first.localUnitPrice, 14);
        expect(result.conflicts.first.serverUnitPrice, 15);
      },
    );

    test(
      'uses group + currency scoped matrix for pack alias unit type',
      () async {
        final validator = OrderStalePriceValidator(
          productFetcher: (ids) async => <ProductModel>[
            makeProduct(
              id: 55,
              inStock: true,
              piecePrice: 0,
              packPrice: 0,
              unitOptions: <UnitOption>[unit(type: 'pack', unitPrice: 0)],
              metaData: const <ProductMetaEntry>[
                ProductMetaEntry(
                  key: '_dms_prices',
                  value: <String, dynamic>{
                    'vip': <String, dynamic>{
                      'syp_piece': 120,
                      'syp_pack': 1000,
                      'usd_piece': 1,
                      'usd_pack': 8,
                      'package_pieces_count': 10,
                    },
                  },
                ),
              ],
            ),
          ],
        );

        final result = await validator.validateOrderPayload(<String, dynamic>{
          'currency': 'syp',
          'user_group': 'vip',
          'line_items': <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 55,
              'quantity': 1,
              'unit_type': 'pack',
              'unit_price': 1000,
            },
          ],
        });

        expect(result.hasBlockingConflicts, isFalse);
        expect(result.conflicts, isEmpty);
      },
    );

    test('detects price_changed against scoped matrix package price', () async {
      final validator = OrderStalePriceValidator(
        productFetcher: (ids) async => <ProductModel>[
          makeProduct(
            id: 56,
            inStock: true,
            piecePrice: 0,
            packPrice: 0,
            unitOptions: <UnitOption>[unit(type: 'pack', unitPrice: 0)],
            metaData: const <ProductMetaEntry>[
              ProductMetaEntry(
                key: '_dms_prices',
                value: <String, dynamic>{
                  'vip': <String, dynamic>{'syp_piece': 120, 'syp_pack': 1000},
                },
              ),
            ],
          ),
        ],
      );

      final result = await validator.validateOrderPayload(<String, dynamic>{
        'currency': 'syp',
        'user_group': 'vip',
        'line_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 56,
            'quantity': 1,
            'unit_type': 'package',
            'unit_price': 900,
          },
        ],
      });

      expect(result.hasBlockingConflicts, isTrue);
      expect(result.conflicts.first.code, 'price_changed');
      expect(result.conflicts.first.serverUnitPrice, 1000);
    });
  });
}
