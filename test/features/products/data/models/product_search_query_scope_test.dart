import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/data/models/product_search_query.dart';

void main() {
  test('keeps search, brand, and category in one request', () {
    const query = ProductSearchQuery(
      search: 'حقيبة',
      categoryIds: <int>[42],
      extraParams: <String, dynamic>{'brand_slug': 'lexi'},
    );

    final params = query.toQueryParameters();

    expect(params['search'], 'حقيبة');
    expect(params['category'], '42');
    expect(params['brand_slug'], 'lexi');
  });
}
