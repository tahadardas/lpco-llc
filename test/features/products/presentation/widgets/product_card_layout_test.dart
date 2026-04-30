import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/theme/app_theme.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card.dart';

void main() {
  ProductModel buildProduct() {
    return const ProductModel(
      id: 101,
      customOrder: 101,
      name: 'دفتر ملاحظات عربي طويل جدًا لاختبار سلوك الكارد ضمن مساحة ضيقة',
      slug: 'arabic-long-product',
      sku: 'SKU-AR-LONG-101',
      description: '',
      shortDescription: '',
      permalink: '',
      price: '12500',
      regularPrice: '14500',
      salePrice: '',
      stockStatus: 'instock',
      inStock: true,
      stockQuantity: 24,
      images: <ProductImage>[],
      variations: <ProductVariation>[],
      colorOptions: <ColorOption>[],
      attributes: <ProductAttribute>[],
      categories: <ProductCategoryRef>[],
      metaData: <ProductMetaEntry>[],
      unitOptions: <UnitOption>[],
      packSize: 1,
      pricePerPiece: 12500,
      pricePerPack: 12500,
      unitDisplayDefaultAr: 'قطعة',
    );
  }

  ProductModel buildMultiUnitProduct({
    required num piecePrice,
    required num packPrice,
  }) {
    return ProductModel(
      id: 102,
      customOrder: 102,
      name: 'منتج وحدات',
      slug: 'multi-unit-product',
      sku: 'SKU-UNIT-102',
      description: '',
      shortDescription: '',
      permalink: '',
      price: piecePrice.toString(),
      regularPrice: '',
      salePrice: '',
      stockStatus: 'instock',
      inStock: true,
      stockQuantity: 30,
      images: const <ProductImage>[],
      variations: const <ProductVariation>[],
      colorOptions: const <ColorOption>[],
      attributes: const <ProductAttribute>[],
      categories: const <ProductCategoryRef>[],
      metaData: const <ProductMetaEntry>[],
      unitOptions: <UnitOption>[
        UnitOption(
          type: 'piece',
          labelDisplayAr: 'قطعة',
          name: '',
          label: '',
          piecesCount: 1,
          sypPiece: piecePrice,
          usdPiece: 0,
          sypPack: 0,
          usdPack: 0,
          unitPrice: 0,
          genericPrice: 0,
        ),
        UnitOption(
          type: 'package',
          labelDisplayAr: 'طرد',
          name: '',
          label: '',
          piecesCount: 12,
          sypPiece: 0,
          usdPiece: 0,
          sypPack: packPrice,
          usdPack: 0,
          unitPrice: 0,
          genericPrice: 0,
        ),
      ],
      packSize: 12,
      pricePerPiece: piecePrice,
      pricePerPack: packPrice,
      unitDisplayDefaultAr: 'قطعة',
    );
  }

  Widget buildHarness({
    required Size size,
    ProductModel? product,
    ValueChanged<ProductCardUnit>? onAddToCart,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: ProductCard(
                  product: product ?? buildProduct(),
                  isGuest: false,
                  isSaved: false,
                  currencyCode: 'SYP',
                  userGroup: 'retail',
                  onTap: () {},
                  onToggleSave: () {},
                  onAddToCart: onAddToCart ?? (_) {},
                  onShare: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('grid product card stays stable in standard size', (
    tester,
  ) async {
    final oldOnError = FlutterError.onError;
    final reported = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      reported.add(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    await tester.pumpWidget(buildHarness(size: const Size(212, 420)));
    await tester.pumpAndSettle();

    final hasOverflow = reported.any(
      (e) => e.exceptionAsString().contains('A RenderFlex overflowed'),
    );
    expect(hasOverflow, isFalse);

    final hasInfiniteWidth = reported.any(
      (e) => e.exceptionAsString().contains(
        'BoxConstraints forces an infinite width',
      ),
    );
    expect(hasInfiniteWidth, isFalse);
  });

  testWidgets('requires explicit unit selection before adding from the card', (
    tester,
  ) async {
    ProductCardUnit? addedUnit;
    await tester.pumpWidget(
      buildHarness(
        size: const Size(212, 420),
        product: buildMultiUnitProduct(piecePrice: 100, packPrice: 1200),
        onAddToCart: (unit) => addedUnit = unit,
      ),
    );
    await tester.pumpAndSettle();

    final addButtonFinder = find.byKey(
      const ValueKey<String>('product_card_add_button'),
    );
    expect(addButtonFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(addButtonFinder).onPressed, isNull);

    expect(
      find.byKey(const ValueKey<String>('product_card_unit_piece')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('product_card_unit_package')),
      findsOneWidget,
    );

    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
    expect(addedUnit, isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('product_card_unit_piece')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(addButtonFinder).onPressed, isNotNull);

    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
    expect(addedUnit, isNotNull);
    expect(addedUnit!.type, 'piece');
  });

  testWidgets('keeps unit choices visible even when unit prices are equal', (
    tester,
  ) async {
    ProductCardUnit? addedUnit;
    await tester.pumpWidget(
      buildHarness(
        size: const Size(212, 420),
        product: buildMultiUnitProduct(piecePrice: 500, packPrice: 500),
        onAddToCart: (unit) => addedUnit = unit,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('product_card_unit_piece')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('product_card_unit_package')),
      findsOneWidget,
    );

    final addButtonFinder = find.byKey(
      const ValueKey<String>('product_card_add_button'),
    );
    expect(tester.widget<FilledButton>(addButtonFinder).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('product_card_unit_package')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(addButtonFinder).onPressed, isNotNull);

    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
    expect(addedUnit, isNotNull);
    expect(addedUnit!.type, 'package');
  });
}
