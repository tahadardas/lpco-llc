import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/products/presentation/screens/product_image_viewer_screen.dart';

void main() {
  testWidgets('shows an Arabic empty state for an empty image list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProductImageViewerScreen(
          imageUrls: <String>[],
          initialIndex: 0,
          productName: 'منتج بلا صور',
        ),
      ),
    );

    expect(find.text('لا توجد صور متاحة'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
