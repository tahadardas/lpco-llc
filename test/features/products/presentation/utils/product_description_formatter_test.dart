import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_description_formatter.dart';

void main() {
  group('ProductDescriptionFormatter', () {
    test('preserves WordPress paragraphs, breaks, lists, and Arabic text', () {
      const html =
          '<p>القياس : 17 إنش<br>نوع القماش : جلد صناعي</p>'
          '<ul><li>عدد السحابات : 6</li><li>عدد الطبقات : 2</li></ul>';

      expect(
        ProductDescriptionFormatter.toPlainText(html),
        'القياس : 17 إنش\nنوع القماش : جلد صناعي\n\n'
        '• عدد السحابات : 6\n• عدد الطبقات : 2',
      );
    });

    test('decodes entities without collapsing meaningful newlines', () {
      const html = 'مقاوم&nbsp;للماء &amp; الغبار\n\nالسعة : 20 لتر';

      expect(
        ProductDescriptionFormatter.toPlainText(html),
        'مقاوم للماء & الغبار\n\nالسعة : 20 لتر',
      );
    });
  });
}
