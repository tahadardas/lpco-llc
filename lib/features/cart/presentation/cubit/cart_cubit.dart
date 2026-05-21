import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/local/catalog_local_store.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/shared/commerce/cart/cart_line_item_mapper.dart';

abstract class CartState {
  const CartState();
}

class CartLoading extends CartState {
  const CartLoading();
}

class CartLoaded extends CartState {
  final List<CartItemModel> items;

  const CartLoaded(this.items);

  num get subtotal => items.fold<num>(0, (sum, item) => sum + item.totalPrice);

  int get totalCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  String get currency {
    if (items.isEmpty) {
      return 'syp';
    }
    return items.first.currency;
  }
}

class CartCurrencyConflict extends CartLoaded {
  final CartItemModel pendingItem;
  final String currentCurrency;
  final String newCurrency;

  CartCurrencyConflict({
    required List<CartItemModel> items,
    required this.pendingItem,
    required this.currentCurrency,
    required this.newCurrency,
  }) : super(items);
}

class CartCubit extends Cubit<CartState> {
  final StorageService _storageService;
  final CatalogLocalStore _catalogLocalStore;

  String _scope = 'guest';

  CartCubit({StorageService? storageService})
    : _storageService = storageService ?? StorageService(),
      _catalogLocalStore = CatalogLocalStore(),
      super(const CartLoading()) {
    loadCart();
  }

  String get currentScope => _scope;

  Future<void> setScope(String userScope) async {
    final normalized = userScope.trim().isEmpty ? 'guest' : userScope.trim();
    if (normalized == _scope) {
      return;
    }

    if (_scope == 'guest' && normalized != 'guest') {
      await _moveGuestCartIntoEmptyScope(normalized);
    }

    _scope = normalized;
    await loadCart();
  }

  Future<void> loadCart() async {
    try {
      final cartBox = _storageService.cartBox;
      final scopedKey = _storageService.cartScopeKey(_scope);
      final String? rawScoped = cartBox.get(scopedKey) as String?;
      final String? rawLegacy = cartBox.get('local_cart') as String?;
      final raw = (rawScoped != null && rawScoped.isNotEmpty)
          ? rawScoped
          : rawLegacy;

      if (raw == null || raw.isEmpty) {
        emit(const CartLoaded(<CartItemModel>[]));
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        emit(const CartLoaded(<CartItemModel>[]));
        return;
      }

      final items = decoded
          .whereType<Map>()
          .map(
            (entry) => CartItemModel.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: true);

      final hydrated = _hydrateLegacyItems(items);
      if (_didHydrateItems(items, hydrated)) {
        final encoded = jsonEncode(
          hydrated.map((item) => item.toJson()).toList(growable: false),
        );
        await cartBox.put(scopedKey, encoded);
        if (_scope == 'guest') {
          await cartBox.put('local_cart', encoded);
        }
      }

      emit(CartLoaded(hydrated));
    } catch (_) {
      emit(const CartLoaded(<CartItemModel>[]));
    }
  }

  Future<void> _save(List<CartItemModel> items) async {
    final cartBox = _storageService.cartBox;
    final encoded = jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
    await cartBox.put(_storageService.cartScopeKey(_scope), encoded);
    if (_scope == 'guest') {
      await cartBox.put('local_cart', encoded);
    }
    emit(CartLoaded(_cloneItems(items)));
  }

  Future<void> _moveGuestCartIntoEmptyScope(String targetScope) async {
    final current = state;
    final guestItems = current is CartLoaded
        ? _cloneItems(current.items)
        : _readItemsForScope('guest', includeLegacyFallback: true);
    if (guestItems.isEmpty) {
      return;
    }

    final targetItems = _readItemsForScope(targetScope);
    if (targetItems.isNotEmpty) {
      // A non-empty user cart stays authoritative until merge UX is explicit.
      return;
    }

    await _writeItemsForScope(targetScope, guestItems);
    await _writeItemsForScope('guest', const <CartItemModel>[]);
  }

  List<CartItemModel> _readItemsForScope(
    String scope, {
    bool includeLegacyFallback = false,
  }) {
    try {
      final cartBox = _storageService.cartBox;
      final rawScoped = cartBox.get(_storageService.cartScopeKey(scope));
      final rawLegacy = includeLegacyFallback
          ? cartBox.get('local_cart')
          : null;
      final raw = rawScoped is String && rawScoped.isNotEmpty
          ? rawScoped
          : rawLegacy is String
          ? rawLegacy
          : null;
      if (raw == null || raw.isEmpty) {
        return <CartItemModel>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <CartItemModel>[];
      }

      return decoded
          .whereType<Map>()
          .map(
            (entry) => CartItemModel.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: true);
    } catch (_) {
      return <CartItemModel>[];
    }
  }

  Future<void> _writeItemsForScope(
    String scope,
    List<CartItemModel> items,
  ) async {
    final encoded = jsonEncode(
      _cloneItems(items).map((item) => item.toJson()).toList(growable: false),
    );
    final cartBox = _storageService.cartBox;
    await cartBox.put(_storageService.cartScopeKey(scope), encoded);
    if (scope == 'guest') {
      await cartBox.put('local_cart', encoded);
    }
  }

  Future<void> addToCart(CartItemModel item) async {
    final current = state;
    if (current is! CartLoaded) {
      return;
    }

    final normalizedItem = _normalizeItem(item);
    final items = _cloneItems(current.items);

    if (items.isNotEmpty && items.first.currency != normalizedItem.currency) {
      emit(
        CartCurrencyConflict(
          items: items,
          pendingItem: normalizedItem,
          currentCurrency: items.first.currency,
          newCurrency: normalizedItem.currency,
        ),
      );
      return;
    }

    final index = items.indexWhere(
      (entry) => entry.itemKey == normalizedItem.itemKey,
    );

    if (index >= 0) {
      items[index].quantity += normalizedItem.quantity;
    } else {
      items.add(normalizedItem);
    }

    await _save(items);
  }

  Future<void> incrementItem(String itemKey) async {
    final current = state;
    if (current is! CartLoaded) {
      return;
    }

    final items = List<CartItemModel>.from(current.items);
    final index = items.indexWhere((entry) => entry.itemKey == itemKey);
    if (index < 0) {
      return;
    }

    items[index].quantity += 1;
    await _save(items);
  }

  Future<void> decrementItem(String itemKey) async {
    final current = state;
    if (current is! CartLoaded) {
      return;
    }

    final items = List<CartItemModel>.from(current.items);
    final index = items.indexWhere((entry) => entry.itemKey == itemKey);
    if (index < 0) {
      return;
    }

    if (items[index].quantity <= 1) {
      items.removeAt(index);
    } else {
      items[index].quantity -= 1;
    }

    await _save(items);
  }

  Future<void> updateQuantity(String itemKey, int quantity) async {
    final current = state;
    if (current is! CartLoaded) {
      return;
    }

    final items = List<CartItemModel>.from(current.items);
    final index = items.indexWhere((entry) => entry.itemKey == itemKey);
    if (index < 0) {
      return;
    }

    final normalized = quantity <= 0 ? 1 : quantity;
    items[index].quantity = normalized;
    await _save(items);
  }

  Future<void> removeByKey(String itemKey) async {
    final current = state;
    if (current is! CartLoaded) {
      return;
    }

    final items = List<CartItemModel>.from(current.items)
      ..removeWhere((item) => item.itemKey == itemKey);
    await _save(items);
  }

  Future<void> clear() async {
    await _save(<CartItemModel>[]);
  }

  Future<void> confirmCurrencySwitch() async {
    final current = state;
    if (current is! CartCurrencyConflict) {
      return;
    }

    await _save(<CartItemModel>[current.pendingItem]);
  }

  Future<void> cancelCurrencySwitch() async {
    final current = state;
    if (current is! CartCurrencyConflict) {
      return;
    }

    emit(CartLoaded(_cloneItems(current.items)));
  }

  int getItemQuantity({
    required int productId,
    required Map<String, dynamic> selectedVariants,
    required String unitType,
    int? variationId,
    String? colorSlug,
    String? colorName,
  }) {
    final current = state;
    if (current is! CartLoaded) {
      return 0;
    }

    final probe = CartItemModel(
      productId: productId,
      name: '',
      price: '0',
      image: '',
      selectedVariants: selectedVariants,
      unitType: unitType,
      quantity: 1,
      variationId: variationId,
      colorSlug: colorSlug,
      colorName: colorName,
    );

    final item = current.items.where((entry) => entry.itemKey == probe.itemKey);
    if (item.isEmpty) {
      return 0;
    }
    return item.first.quantity;
  }

  List<Map<String, dynamic>> getLineItems() {
    final current = state;
    if (current is! CartLoaded) {
      return <Map<String, dynamic>>[];
    }

    return mapCartItemsToLineItems(current.items);
  }

  CartItemModel _normalizeItem(CartItemModel item) {
    return CartItemModel(
      productId: item.productId,
      name: item.displayName,
      price: item.price,
      image: item.image,
      selectedVariants: Map<String, dynamic>.from(item.selectedVariants),
      quantity: item.quantity,
      unitType: item.unitType,
      unitLabel: item.unitLabel,
      currency: AppCurrencies.normalizeCode(item.currency),
      piecesCount: item.piecesCount,
      variationId: item.variationId,
      colorSlug: item.colorSlug,
      colorName: item.colorName,
    );
  }

  List<CartItemModel> _cloneItems(List<CartItemModel> items) {
    return items.map(_normalizeItem).toList(growable: true);
  }

  List<CartItemModel> _hydrateLegacyItems(List<CartItemModel> items) {
    return items
        .map((item) {
          final localProduct = _catalogLocalStore.getProductById(
            scope: _scope,
            productId: item.productId,
          );
          final guestProduct = _scope == 'guest'
              ? null
              : _catalogLocalStore.getProductById(
                  scope: 'guest',
                  productId: item.productId,
                );
          final resolvedProduct = localProduct ?? guestProduct;
          final resolvedImages = resolvedProduct?['images'];
          final firstImage = resolvedImages is List && resolvedImages.isNotEmpty
              ? Map<String, dynamic>.from(
                  (resolvedImages.first as Map?) ?? const <String, dynamic>{},
                )['src']
              : null;

          final fallbackName =
              '${resolvedProduct?['name'] ?? resolvedProduct?['product_name'] ?? ''}'
                  .trim();
          final fallbackImage =
              '${resolvedProduct?['image'] ?? resolvedProduct?['image_url'] ?? firstImage ?? ''}'
                  .trim();

          return CartItemModel(
            productId: item.productId,
            name: item.name.trim().isNotEmpty
                ? item.name.trim()
                : (fallbackName.isNotEmpty ? fallbackName : item.displayName),
            price: item.price,
            image: item.image.trim().isNotEmpty ? item.image : fallbackImage,
            selectedVariants: Map<String, dynamic>.from(item.selectedVariants),
            quantity: item.quantity,
            unitType: item.unitType,
            unitLabel: item.unitLabel,
            currency: item.currency,
            piecesCount: item.piecesCount,
            variationId: item.variationId,
            colorSlug: item.colorSlug,
            colorName: item.colorName,
          );
        })
        .toList(growable: true);
  }

  bool _didHydrateItems(
    List<CartItemModel> original,
    List<CartItemModel> next,
  ) {
    if (original.length != next.length) {
      return true;
    }

    for (var i = 0; i < original.length; i++) {
      if (original[i].displayName != next[i].displayName ||
          original[i].image != next[i].image) {
        return true;
      }
    }
    return false;
  }
}
