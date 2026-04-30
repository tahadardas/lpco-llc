import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lpco_llc/features/products/presentation/widgets/catalog_search_bar.dart';

void main() {
  testWidgets('uses scoped hint and hides barcode action when disabled', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogSearchBar(
            controller: controller,
            focusNode: focusNode,
            topPadding: 0,
            activeFilters: 0,
            hintText: 'ابحث داخل هذا القسم',
            showBarcodeAction: false,
            onClearSearch: () {},
            onOpenBarcodeScanner: () {},
            onOpenFilter: () {},
            onChanged: (_) {},
            onSubmitted: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('ابحث داخل هذا القسم'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
  });
}
