import 'package:lpco_llc/core/storage/storage_service.dart';

class LocalSearchIndex {
  static final LocalSearchIndex _instance = LocalSearchIndex._internal();
  factory LocalSearchIndex() => _instance;
  LocalSearchIndex._internal();

  final StorageService _storage = StorageService();

  // Keys
  String _itemKey(String scope, int id) => 'idx_s::$scope::$id';
  String _allIdsKey(String scope) => 'idx_s_all::$scope';

  /// Incremental update: Adds or updates specific products in the search index
  Future<void> updateIncremental({
    required String scope,
    required List<Map<String, dynamic>> products,
  }) async {
    if (products.isEmpty) return;

    final batch = <String, dynamic>{};
    final allIds = _getIds(scope);

    for (final product in products) {
      final id = _parseProductId(product);
      if (id == null) continue;

      allIds.add(id);
      batch[_itemKey(scope, id)] = _buildDocument(product);
    }

    batch[_allIdsKey(scope)] = allIds.toList();
    await _storage.searchIndexBox.putAll(batch);
  }

  /// Full rebuild (Legacy support or force sync)
  Future<void> rebuildProductIndex({
    required String scope,
    required List<Map<String, dynamic>> products,
  }) async {
    final existingIds = _getIds(scope);
    if (existingIds.isNotEmpty) {
      final staleKeys = existingIds
          .map((id) => _itemKey(scope, id))
          .toList(growable: false);
      await _storage.searchIndexBox.deleteAll(staleKeys);
    }
    await _storage.searchIndexBox.delete(_allIdsKey(scope));
    await updateIncremental(scope: scope, products: products);
  }

  /// Efficient query without JSON full-scan
  List<int> queryProductIds({required String scope, required String query}) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return [];

    final terms = normalized
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    if (terms.isEmpty) return [];

    final allIds = _getIds(scope);
    final results = <int>[];

    for (final id in allIds) {
      final doc = _storage.searchIndexBox.get(_itemKey(scope, id));
      if (doc is String) {
        if (terms.every(doc.contains)) {
          results.add(id);
        }
      }
    }

    return results;
  }

  Set<int> _getIds(String scope) {
    final raw = _storage.searchIndexBox.get(_allIdsKey(scope));
    if (raw is List) return raw.cast<int>().toSet();
    return <int>{};
  }

  String _buildDocument(Map<String, dynamic> product) {
    final parts = <String>[
      product['name']?.toString() ?? '',
      product['sku']?.toString() ?? '',
      product['barcode']?.toString() ?? '',
      product['brand_slug']?.toString() ?? '',
    ];

    final cats = product['categories'];
    if (cats is List) {
      for (final c in cats.whereType<Map>()) {
        parts.add(c['name']?.toString() ?? '');
      }
    }

    return parts.map(_normalize).where((s) => s.isNotEmpty).join(' ');
  }

  int? _parseProductId(Map<String, dynamic> product) {
    final raw = product['id'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  String _normalize(String value) {
    if (value.isEmpty) return '';
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '') // Harakat
        .replaceAll('\u0623', '\u0627') // Alef Marda
        .replaceAll('\u0625', '\u0627') // Alef Kasra
        .replaceAll('\u0622', '\u0627') // Alef Madda
        .replaceAll('\u0649', '\u064A') // Alef Layena
        .replaceAll('\u0629', '\u0647') // Teh Marbouta
        .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
