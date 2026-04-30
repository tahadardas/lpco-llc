import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/presentation/widgets/catalog_results_summary.dart';

void main() {
  testWidgets('shows loading summary while first page is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogResultsSummary(
            summary: 'منتجات القسم',
            count: 0,
            isLoading: true,
            hasFilters: false,
            onClearFilters: () {},
          ),
        ),
      ),
    );

    expect(find.text('منتجات القسم • جاري التحميل...'), findsOneWidget);
  });

  testWidgets('shows count after loading completes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogResultsSummary(
            summary: 'منتجات القسم',
            count: 12,
            isLoading: false,
            hasFilters: false,
            onClearFilters: () {},
          ),
        ),
      ),
    );

    expect(find.text('منتجات القسم • 12 منتج'), findsOneWidget);
  });
}
