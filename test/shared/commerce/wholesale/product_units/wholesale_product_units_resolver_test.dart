import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/shared/commerce/wholesale/product_units/wholesale_product_units_resolver.dart';

void main() {
  ProductModel makeProduct({
    required List<UnitOption> unitOptions,
    required List<ProductMetaEntry> metaData,
    num piecePrice = 0,
    num packPrice = 0,
  }) {
    return ProductModel(
      id: 1,
      customOrder: 1,
      name: 'Wholesale Product',
      slug: 'wholesale-product',
      sku: 'W-1',
      description: '',
      shortDescription: '',
      permalink: '',
      price: piecePrice.toString(),
      regularPrice: piecePrice.toString(),
      salePrice: '',
      stockStatus: 'instock',
      inStock: true,
      stockQuantity: 50,
      images: const <ProductImage>[],
      variations: const <ProductVariation>[],
      colorOptions: const <ColorOption>[],
      attributes: const <ProductAttribute>[],
      categories: const <ProductCategoryRef>[],
      metaData: metaData,
      unitOptions: unitOptions,
      packSize: 10,
      pricePerPiece: piecePrice,
      pricePerPack: packPrice,
      unitDisplayDefaultAr: '',
    );
  }

  UnitOption unit({
    required String type,
    num sypPiece = 0,
    num sypPack = 0,
    String labelDisplayAr = '',
    String name = '',
    int? piecesCount,
  }) {
    return UnitOption(
      type: type,
      labelDisplayAr: labelDisplayAr,
      name: name.isEmpty ? type : name,
      label: type,
      piecesCount: piecesCount,
      sypPiece: sypPiece,
      usdPiece: 0,
      sypPack: sypPack,
      usdPack: 0,
      unitPrice: 0,
      genericPrice: 0,
    );
  }

  group('WholesaleProductUnitsResolver', () {
    test('resolves pack option price from scoped matrix', () {
      final product = makeProduct(
        unitOptions: <UnitOption>[unit(type: 'pack')],
        metaData: const <ProductMetaEntry>[
          ProductMetaEntry(
            key: '_dms_prices',
            value: <String, dynamic>{
              'vip': <String, dynamic>{
                'syp_piece': 100,
                'syp_pack': 900,
                'package_pieces_count': 9,
              },
            },
          ),
        ],
      );

      final units = WholesaleProductUnitsResolver.resolve(
        product: product,
        currencyCode: 'syp',
        userGroup: 'vip',
      );

      final packUnit = units.firstWhere((u) => u.type == 'pack');
      expect(packUnit.price, 900);
    });

    test('matches package request against pack option type aliases', () {
      final product = makeProduct(
        unitOptions: <UnitOption>[unit(type: 'pack')],
        metaData: const <ProductMetaEntry>[
          ProductMetaEntry(
            key: '_dms_prices',
            value: <String, dynamic>{
              'vip': <String, dynamic>{'syp_pack': 1200},
            },
          ),
        ],
      );

      final expected = WholesaleProductUnitsResolver.resolveExpectedUnitPrice(
        product: product,
        unitType: 'package',
        currencyCode: 'syp',
        userGroup: 'vip',
      );

      expect(expected, 1200);
    });

    test(
      'uses wordpress dashboard unit labels from _dms_prices when unit_options is empty',
      () {
        final product = makeProduct(
          unitOptions: const <UnitOption>[],
          metaData: const <ProductMetaEntry>[
            ProductMetaEntry(
              key: '_dms_prices',
              value: <String, dynamic>{
                'A+_\$': <String, dynamic>{
                  'syp_piece': 310.5,
                  'box_unit_name': 'علبة 50 قلم',
                  'box_pieces_count': 1,
                  'package_unit_name': 'طرد 40 علبة',
                  'package_pieces_count': 40,
                },
              },
            ),
          ],
        );

        final units = WholesaleProductUnitsResolver.resolve(
          product: product,
          currencyCode: 'syp',
          userGroup: 'A+_\$',
        );

        expect(units.length, 2);
        expect(units[0].type, 'piece');
        expect(units[0].label, 'علبة 50 قلم');
        expect(units[0].piecesCount, 1);
        expect(units[1].type, 'package');
        expect(units[1].label, 'طرد 40 علبة');
        expect(units[1].piecesCount, 40);
      },
    );

    test('hides wordpress units when current currency price is zero', () {
      final product = makeProduct(
        unitOptions: const <UnitOption>[],
        metaData: const <ProductMetaEntry>[
          ProductMetaEntry(
            key: '_dms_prices',
            value: <String, dynamic>{
              'A+_\$': <String, dynamic>{
                'syp_piece': 0,
                'usd_piece': 2.3,
                'box_unit_name': 'علبة 50 قلم',
                'box_pieces_count': 1,
                'package_unit_name': 'طرد 40 علبة',
                'package_pieces_count': 40,
              },
            },
          ),
        ],
      );

      final units = WholesaleProductUnitsResolver.resolve(
        product: product,
        currencyCode: 'syp',
        userGroup: 'A+_\$',
      );

      expect(units, isEmpty);
    });

    test('hides package option when its price matches piece price', () {
      final product = makeProduct(
        unitOptions: <UnitOption>[
          unit(type: 'piece', sypPiece: 500, piecesCount: 1),
          unit(type: 'package', sypPack: 500, piecesCount: 12),
        ],
        metaData: const <ProductMetaEntry>[],
        piecePrice: 500,
        packPrice: 500,
      );

      final units = WholesaleProductUnitsResolver.resolve(
        product: product,
        currencyCode: 'syp',
        userGroup: 'vip',
      );

      expect(units.length, 1);
      expect(units.first.type, 'piece');
      expect(units.any((unit) => unit.type == 'package'), isFalse);
    });

    test('hides zero-price package option', () {
      final product = makeProduct(
        unitOptions: <UnitOption>[
          unit(type: 'piece', sypPiece: 500, piecesCount: 1),
          unit(type: 'package', sypPack: 0, piecesCount: 12),
        ],
        metaData: const <ProductMetaEntry>[],
        piecePrice: 500,
      );

      final units = WholesaleProductUnitsResolver.resolve(
        product: product,
        currencyCode: 'syp',
        userGroup: 'vip',
      );

      expect(units.length, 1);
      expect(units.first.type, 'piece');
      expect(units.any((unit) => unit.type == 'package'), isFalse);
    });

    test(
      'trusts API unit_options when provided without inventing replacements',
      () {
        final product = makeProduct(
          unitOptions: <UnitOption>[
            unit(
              type: 'piece',
              labelDisplayAr: 'علبة أصلية',
              name: 'علبة أصلية',
              piecesCount: 1,
              sypPiece: 123,
            ),
          ],
          metaData: const <ProductMetaEntry>[
            ProductMetaEntry(
              key: '_dms_prices',
              value: <String, dynamic>{
                'vip': <String, dynamic>{
                  'syp_piece': 77,
                  'box_unit_name': 'قطعة افتراضية',
                },
              },
            ),
          ],
        );

        final units = WholesaleProductUnitsResolver.resolve(
          product: product,
          currencyCode: 'syp',
          userGroup: 'vip',
        );

        expect(units.length, 1);
        expect(units.first.label, 'علبة أصلية');
      },
    );

    test(
      'completes missing package from _dms_prices when unit_options has only piece',
      () {
        final product = makeProduct(
          unitOptions: <UnitOption>[
            unit(
              type: 'piece',
              labelDisplayAr: 'Primary Box Label',
              name: 'Primary Box Label',
              piecesCount: 1,
              sypPiece: 310.5,
            ),
          ],
          metaData: const <ProductMetaEntry>[
            ProductMetaEntry(
              key: '_dms_prices',
              value: <String, dynamic>{
                'A+_\$': <String, dynamic>{
                  'syp_piece': 310.5,
                  'box_unit_name': 'Box 50 pens',
                  'box_pieces_count': 1,
                  'package_unit_name': 'Package 40 boxes',
                  'package_pieces_count': 40,
                },
              },
            ),
          ],
        );

        final units = WholesaleProductUnitsResolver.resolve(
          product: product,
          currencyCode: 'syp',
          userGroup: 'A+_\$',
        );

        expect(units.length, 2);
        expect(units.first.label, 'Primary Box Label');
        expect(units.any((u) => u.type == 'package'), isTrue);
        expect(
          units.firstWhere((u) => u.type == 'package').label,
          'Package 40 boxes',
        );
        expect(units.firstWhere((u) => u.type == 'package').piecesCount, 40);
      },
    );
  });
}
