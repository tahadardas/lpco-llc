import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/theme/app_theme.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/screens/product_details_screen.dart';

void main() {
  testWidgets('details quantity number opens editor dialog', (tester) async {
    await tester.pumpWidget(_buildHarness(product: _buildProduct()));
    await tester.pump();

    final quantityButton = find.byKey(
      const ValueKey<String>('product_details_quantity_button'),
    );
    await tester.scrollUntilVisible(
      quantityButton,
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(quantityButton, findsOneWidget);

    await tester.tap(quantityButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final quantityInput = find.byKey(
      const ValueKey<String>('product_details_quantity_input'),
    );
    expect(quantityInput, findsOneWidget);

    await tester.enterText(quantityInput, '24');
    await tester.tap(
      find.widgetWithText(FilledButton, '\u062a\u062d\u062f\u064a\u062b'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(of: quantityButton, matching: find.text('24')),
      findsOneWidget,
    );
  });
}

Widget _buildHarness({required ProductModel product}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>(create: (_) => _FakeAuthCubit()),
      BlocProvider<CartCubit>(create: (_) => _FakeCartCubit()),
      BlocProvider<ProductCubit>(create: (_) => _FakeProductCubit()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ProductDetailsScreen(product: product),
      ),
    ),
  );
}

ProductModel _buildProduct() {
  return const ProductModel(
    id: 201,
    customOrder: 201,
    name: '\u0645\u0646\u062a\u062c \u0627\u062e\u062a\u0628\u0627\u0631',
    slug: 'details-quantity-test',
    sku: 'DETAILS-QTY-201',
    description: '',
    shortDescription: '',
    permalink: '',
    price: '12500',
    regularPrice: '12500',
    salePrice: '',
    stockStatus: 'instock',
    inStock: true,
    stockQuantity: 24,
    images: <ProductImage>[
      ProductImage(id: 1, src: 'https://example.test/product-1.png'),
      ProductImage(id: 2, src: 'https://example.test/product-2.png'),
    ],
    variations: <ProductVariation>[],
    colorOptions: <ColorOption>[],
    attributes: <ProductAttribute>[],
    categories: <ProductCategoryRef>[],
    metaData: <ProductMetaEntry>[],
    unitOptions: <UnitOption>[],
    packSize: 1,
    pricePerPiece: 12500,
    pricePerPack: 12500,
    unitDisplayDefaultAr: '\u0642\u0637\u0639\u0629',
  );
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit() : super(GuestAuthenticated(UserModel.guest()));

  @override
  UserModel? get currentUser => UserModel.guest();

  @override
  bool get isGuest => true;

  @override
  bool get isLoggedIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCartCubit extends Cubit<CartState> implements CartCubit {
  _FakeCartCubit() : super(const CartLoaded(<CartItemModel>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProductCubit extends Cubit<ProductState> implements ProductCubit {
  _FakeProductCubit() : super(const ProductState());

  @override
  bool isSaved(int productId) => false;

  @override
  Future<void> toggleSaved(int productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
