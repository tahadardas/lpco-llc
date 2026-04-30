import 'dart:convert';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/sync/sync_queue_item.dart';

abstract class SyncQueueStore {
  String? read();
  Future<void> write(String value);
  List<SyncQueueItem> getAll();
  Future<void> upsert(SyncQueueItem item);
  Future<void> delete(String id);
  Future<void> clear();
}

class HiveSyncQueueStore implements SyncQueueStore {
  final StorageService _storage;
  HiveSyncQueueStore({StorageService? storage})
      : _storage = storage ?? StorageService();

  static const String _allIdsKey = 'sq_idx_all';
  String _itemKey(String id) => 'sq_item::$id';

  @override
  List<SyncQueueItem> getAll() {
    final ids = _getIds();
    final items = <SyncQueueItem>[];
    for (final id in ids) {
      final raw = _storage.syncQueueBox.get(_itemKey(id));
      if (raw is String) {
        try {
          items.add(SyncQueueItem.fromJson(jsonDecode(raw)));
        } catch (_) {}
      }
    }
    return items;
  }

  @override
  Future<void> upsert(SyncQueueItem item) async {
    final ids = _getIds();
    ids.add(item.id);
    
    await _storage.syncQueueBox.putAll({
      _allIdsKey: ids.toList(),
      _itemKey(item.id): jsonEncode(item.toJson()),
    });
  }

  @override
  Future<void> delete(String id) async {
    final ids = _getIds();
    if (ids.remove(id)) {
      await _storage.syncQueueBox.put(_allIdsKey, ids.toList());
    }
    await _storage.syncQueueBox.delete(_itemKey(id));
  }

  @override
  Future<void> clear() async {
    await _storage.syncQueueBox.clear();
  }

  @override
  String? read() => null;

  @override
  Future<void> write(String value) async {}

  bool _isMigrating = false;
  void migrateLegacyIfNecessary() {
    if (_isMigrating) return;
    final legacyRaw = _storage.syncQueueBox.get('queue_items');
    if (legacyRaw is String && legacyRaw.isNotEmpty) {
      _isMigrating = true;
      try {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is List) {
          for (final entry in decoded.whereType<Map>()) {
            final item = SyncQueueItem.fromJson(Map<String, dynamic>.from(entry));
            upsert(item);
          }
        }
        _storage.syncQueueBox.delete('queue_items');
      } catch (_) {}
      _isMigrating = false;
    }
  }

  Set<String> _getIds() {
    final raw = _storage.syncQueueBox.get(_allIdsKey);
    if (raw is List) return raw.cast<String>().toSet();
    return <String>{};
  }
}

class SyncQueueRepository {
  final SyncQueueStore _store;

  SyncQueueRepository({SyncQueueStore? store})
      : _store = store ?? HiveSyncQueueStore();

  List<SyncQueueItem> getAllItems() {
    final store = _store;
    if (store is HiveSyncQueueStore) {
      store.migrateLegacyIfNecessary();
    }
    return _store.getAll();
  }

  Future<SyncQueueItem> enqueue({
    required String operationType,
    required String idempotencyKey,
    String correlationId = '',
    required String userScope,
    required Map<String, dynamic> payload,
  }) async {
    final items = getAllItems();
    
    // Check for duplicates
    for (final item in items) {
      if (item.userScope == userScope &&
          item.operationType == operationType &&
          item.idempotencyKey == idempotencyKey &&
          !_isTerminal(item.status)) {
        return item;
      }
      if (correlationId.isNotEmpty &&
          item.correlationId == correlationId &&
          !_isTerminal(item.status)) {
        return item;
      }
    }

    final created = SyncQueueItem.create(
      operationType: operationType,
      idempotencyKey: idempotencyKey,
      correlationId: correlationId.trim(),
      userScope: userScope,
      payload: payload,
    );

    await _store.upsert(created);
    return created;
  }

  List<SyncQueueItem> listRunnablePending() {
    final now = DateTime.now().toUtc();
    final items = getAllItems().where((item) {
      return !_isTerminal(item.status) && item.shouldRun(now);
    }).toList();

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> markProcessing(String itemId) async => _update(itemId, (i) => i.markProcessing());
  Future<void> markCompleted(String itemId) async => _update(itemId, (i) => i.markCompleted());
  Future<void> markFailed(String itemId, String error) async => _update(itemId, (i) => i.markFailed(error));
  Future<void> markFailedTerminal(String itemId, String error) async => _update(itemId, (i) => i.markFailed(error, terminal: true));
  Future<void> markPending(String itemId, {bool resetAttempts = false}) async => 
      _update(itemId, (i) => i.markPendingRetry(resetAttempts: resetAttempts));

  Future<void> removeItem(String itemId) async => _store.delete(itemId);

  Future<void> compact({Duration keepCompletedFor = const Duration(days: 7)}) async {
    final now = DateTime.now().toUtc();
    final items = _store.getAll();
    for (final item in items) {
      if (item.status == SyncQueueStatus.completed) {
        if (now.difference(item.updatedAt) > keepCompletedFor) {
          await _store.delete(item.id);
        }
      }
    }
  }

  // --- Private ---

  Future<void> _update(String id, SyncQueueItem Function(SyncQueueItem) updater) async {
    final items = _store.getAll();
    final item = items.cast<SyncQueueItem?>().firstWhere((i) => i?.id == id, orElse: () => null);
    if (item != null) {
      await _store.upsert(updater(item));
    }
  }

  bool _isTerminal(SyncQueueStatus status) => 
      status == SyncQueueStatus.completed || status == SyncQueueStatus.failedTerminal;

}
