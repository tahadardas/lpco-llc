import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/config/app_config.dart';
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

  test('normalizes product image urls and keeps optimized card source', () {
    final product = ProductModel.fromJson(<String, dynamic>{
      'id': 11,
      'name': 'دفتر عربي',
      'slug': 'arabic-notebook',
      'image_url': r'https:\/\/example.test\/uploads\/product image.jpg',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '9',
          'src': r'https:\/\/example.test\/uploads\/product image.jpg',
          'thumbnail_src': '/wp-content/uploads/product-thumb image.jpg',
        },
        <String, dynamic>{
          'id': 9,
          'src': 'https://example.test/uploads/product%20image.jpg',
        },
      ],
    });

    expect(product.images, hasLength(1));
    expect(
      product.images.first.src,
      'https://example.test/uploads/product%20image.jpg',
    );
    expect(
      product.images.first.cardSrc,
      '${AppConfig.baseUrl}/wp-content/uploads/product-thumb%20image.jpg',
    );
  });
}
