import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';

void main() {
  test('parses direct barcode fields and barcode meta values', () {
    final product = ProductModel.fromJson(<String, dynamic>{
      'id': 24186,
      'name': 'سبورة',
      'slug': 'lp-6232',
      'sku': 'LP.6232',
      'barcode_1': '123456789',
      'barcode_2': '987654321',
      'barcodes': <String>['123456789', '555555555'],
      'meta_data': <Map<String, dynamic>>[
        <String, dynamic>{'key': '_barcode_3', 'value': '333333333'},
      ],
    });

    expect(product.barcode1, '123456789');
    expect(product.barcode2, '987654321');
    expect(
      product.barcodes,
      containsAll(<String>['123456789', '987654321', '555555555', '333333333']),
    );
  });
}
