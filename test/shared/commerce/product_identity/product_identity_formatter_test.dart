import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/shared/commerce/product_identity/product_identity_formatter.dart';

void main() {
  test('formats piece units in Arabic', () {
    expect(ProductIdentityFormatter.formatUnitLabel(unitType: 'piece'), 'قطعة');
    expect(
      ProductIdentityFormatter.formatQuantityLabel(
        quantity: 3,
        unitType: 'piece',
      ),
      '3 قطعة',
    );
  });

  test('formats package units with piece count', () {
    expect(
      ProductIdentityFormatter.formatUnitLabel(
        unitType: 'package',
        piecesCount: 12,
      ),
      'طرد (12 قطعة)',
    );
    expect(
      ProductIdentityFormatter.formatUnitAndQuantity(
        quantity: 2,
        unitType: 'package',
        piecesCount: 12,
      ),
      'الوحدة: طرد (12 قطعة) | الكمية: 2',
    );
  });

  test('falls back to بدون وحدة when no unit exists', () {
    expect(ProductIdentityFormatter.formatUnitLabel(), 'بدون وحدة');
    expect(ProductIdentityFormatter.formatQuantityLabel(quantity: 4), '4');
  });
}
