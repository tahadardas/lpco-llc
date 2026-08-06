import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/utils/phone_number.dart';

void main() {
  group('PhoneNumber', () {
    test(
      'accepts an empty optional phone without inventing a country code',
      () {
        expect(
          PhoneNumber.combine(countryCode: '+963', subscriberNumber: ''),
          isEmpty,
        );
        expect(PhoneNumber.validateOptional(''), isNull);
        expect(PhoneNumber.validateOptional(null), isNull);
      },
    );

    test('normalizes Arabic digits and common separators', () {
      expect(PhoneNumber.normalize('+٩٦٣ ٩٤٤-٦١١-٣٠٣'), '+963944611303');
    });

    test('validates format only when a value is supplied', () {
      expect(PhoneNumber.validateOptional('+963 944 611 303'), isNull);
      expect(PhoneNumber.validateOptional('+963-abc'), isNotNull);
      expect(PhoneNumber.validateOptional('123'), isNotNull);
    });
  });
}
