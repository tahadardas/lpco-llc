import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_empty_state.dart';

void main() {
  testWidgets('renders safely inside positioned fill when scoped results are empty', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                const SizedBox(height: 120),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: CatalogEmptyState(
                          isIdleSearch: false,
                          hasSearch: false,
                          hasFilters: true,
                          isScopedListing: true,
                          scopedEmptyMessage: 'لا توجد منتجات متاحة',
                          scopedNoResultsMessage: 'لا توجد نتائج مطابقة',
                          onFocusSearch: () {},
                          onClearSearch: () {},
                          onClearFilters: () {},
                          onEditFilters: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
