import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_content_management_screens.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class _FakeAdminRepository extends AdminRepository {
  late AdminOrderingConfigModel current;
  int saveCount = 0;

  _FakeAdminRepository() : super(dio: Dio()) {
    final products = List<AdminProductOrderOptionModel>.generate(
      20,
      (index) => AdminProductOrderOptionModel(
        id: index + 1,
        name: 'Product ${index + 1}',
        imageUrl: '',
      ),
    );
    current = AdminOrderingConfigModel(
      categories: const <int>[],
      brands: const <int>[],
      hiddenCategories: const <int>[],
      hiddenBrands: const <int>[],
      featuredProducts: const <int>[],
      sliderProducts: const <int>[],
      latestProducts: const <int>[],
      latestMode: 'manual',
      updatedAt: '',
      availableCategories: const <AdminTermModel>[],
      availableBrands: const <AdminTermModel>[],
      availableFeaturedProducts: products,
    );
  }

  @override
  Future<AdminOrderingConfigModel> fetchOrderingConfig() async => current;

  @override
  Future<AdminOrderingConfigModel> updateOrderingConfig(
    AdminOrderingConfigModel config,
  ) async {
    saveCount++;
    current = config;
    return current;
  }
}

void main() {
  testWidgets('admin can search and add a slider product then persist it', (
    tester,
  ) async {
    final repository = _FakeAdminRepository();

    await tester.pumpWidget(
      MaterialApp(home: AdminOrderingScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('منتجات السلايدر'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    final sliderCard = find.ancestor(
      of: find.text('منتجات السلايدر'),
      matching: find.byType(AdminSectionCard),
    );
    expect(find.text('منتجات السلايدر'), findsOneWidget);

    final searchFields = find.descendant(
      of: sliderCard,
      matching: find.byType(TextField),
    );
    await tester.enterText(searchFields.first, 'Product 20');
    await tester.pumpAndSettle();

    final addButton = find.descendant(
      of: sliderCard,
      matching: find.byTooltip('إضافة'),
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('1 مختار'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('حفظ ونشر لجميع الأعضاء'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('حفظ ونشر لجميع الأعضاء'));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.current.sliderProducts, <int>[20]);
  });
}
