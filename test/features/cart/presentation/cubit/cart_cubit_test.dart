import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('cart_cubit_test');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageService.cartBoxName);
    await Hive.openBox(StorageService.catalogBoxName);
  });

  tearDown(() async {
    await Hive.box(StorageService.cartBoxName).clear();
    await Hive.box(StorageService.catalogBoxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test('moves guest items into an empty user cart scope', () async {
    final storage = StorageService();
    final guestItem = CartItemModel(
      productId: 7,
      name: 'Guest item',
      price: '1200',
      image: '',
      selectedVariants: const <String, dynamic>{},
    );
    final rawGuest = jsonEncode(<Map<String, dynamic>>[guestItem.toJson()]);
    await storage.cartBox.put(storage.cartScopeKey('guest'), rawGuest);
    await storage.cartBox.put('local_cart', rawGuest);

    final cubit = CartCubit(storageService: storage);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.setScope('user_10');

    final state = cubit.state as CartLoaded;
    expect(cubit.currentScope, 'user_10');
    expect(state.items.map((item) => item.productId), <int>[7]);
    expect(storage.cartBox.get(storage.cartScopeKey('guest')), '[]');
    expect(storage.cartBox.get('local_cart'), '[]');
  });
}
