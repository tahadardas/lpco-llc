import 'dart:convert';

import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

class OrderLocalStore {
  static final OrderLocalStore _instance = OrderLocalStore._internal();

  factory OrderLocalStore() => _instance;

  OrderLocalStore._internal();

  final StorageService _storage = StorageService();

  String _orderRecordKey(String scope, String stableKey) => 'o_rec::$scope::$stableKey';
  String _orderKeysListKey(String scope) => 'o_keys::$scope';
  String _legacyOrdersKey(String scope) => 'orders::$scope';

  List<Map<String, dynamic>> getOrders(String scope) {
    _migrateLegacyIfNecessary(scope);
    final keys = _getOrderKeys(scope);
    final orders = <Map<String, dynamic>>[];
    for (final key in keys) {
      final raw = _storage.ordersBox.get(_orderRecordKey(scope, key));
      if (raw is Map) {
        orders.add(Map<String, dynamic>.from(raw));
      }
    }
    // Sorting matches original behavior: newest first
    return orders..sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
  }

  Future<void> saveOrders(
    String scope,
    List<Map<String, dynamic>> orders,
  ) async {
    final keys = <String>[];
    final batch = <String, dynamic>{};

    for (final order in orders) {
      final key = _stableKey(order);
      keys.add(key);
      batch[_orderRecordKey(scope, key)] = order;
    }

    await _storage.ordersBox.putAll(batch);
    await _storage.ordersBox.put(_orderKeysListKey(scope), keys);
  }

  Future<void> mergeOrders(
    String scope,
    List<Map<String, dynamic>> incoming,
  ) async {
    final current = getOrders(scope).toList(growable: true);
    final all = <Map<String, dynamic>>[
      ...current.map(Map<String, dynamic>.from),
      ...incoming.map(Map<String, dynamic>.from),
    ];
    await saveOrders(scope, _mergeAndSortOrders(all));
  }

  Future<void> syncWithServerSnapshot(
    String scope,
    List<Map<String, dynamic>> serverOrders,
  ) async {
    final current = getOrders(scope);
    final preservedLocal = current
        .where(_shouldPreserveLocalOrder)
        .map(Map<String, dynamic>.from);

    final merged = <Map<String, dynamic>>[
      ...preservedLocal,
      ...serverOrders.map(Map<String, dynamic>.from),
    ];

    await saveOrders(scope, _mergeAndSortOrders(merged));
  }

  Future<void> upsertQueuedPendingOrder({
    required String scope,
    required String queueId,
    required String orderUuid,
    required String idempotencyKey,
    required Map<String, dynamic> summary,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final pendingOrder = <String, dynamic>{
      ...summary,
      'id': -(DateTime.now().millisecondsSinceEpoch % 2147483647),
      'status': 'pending_sync',
      'lifecycle_state': OrderLifecycleState.pendingSync.value,
      'is_pending_sync': true,
      'local_queue_id': queueId,
      'order_uuid': orderUuid,
      'idempotency_key': idempotencyKey,
      'date': now,
      'created_locally_at': now,
      'enqueued_at': now,
      'last_sync_attempt_at': '',
      'confirmed_at': '',
      'conflict_detected_at': '',
      'retry_count': 0,
      'sync_error': '',
    };

    final stableKey = _stableKey(pendingOrder);
    final existingRaw = _storage.ordersBox.get(_orderRecordKey(scope, stableKey));
    
    Map<String, dynamic> finalRecord;
    if (existingRaw is Map) {
      finalRecord = _mergeOrderRecords(
        Map<String, dynamic>.from(existingRaw),
        pendingOrder,
      );
    } else {
      finalRecord = pendingOrder;
    }

    final keys = _getOrderKeys(scope).toSet();
    keys.add(stableKey);

    await _storage.ordersBox.put(_orderRecordKey(scope, stableKey), finalRecord);
    await _storage.ordersBox.put(_orderKeysListKey(scope), keys.toList());
  }

  Future<void> markQueuedOrderSyncing({
    required String scope,
    required String queueId,
    required int retryCount,
  }) async {
    await _updateMatching(
      scope: scope,
      matcher: (order) => (order['local_queue_id'] ?? '').toString() == queueId,
      updater: (order) {
        final now = DateTime.now().toUtc().toIso8601String();
        return <String, dynamic>{
          ...order,
          'status': 'syncing',
          'lifecycle_state': OrderLifecycleState.syncing.value,
          'is_pending_sync': true,
          'last_sync_attempt_at': now,
          'retry_count': retryCount,
        };
      },
    );
  }

  Future<void> markQueuedOrderFailed({
    required String scope,
    required String queueId,
    required String errorMessage,
    required int retryCount,
    required bool terminal,
    bool staleConflict = false,
  }) async {
    await _updateMatching(
      scope: scope,
      matcher: (order) => (order['local_queue_id'] ?? '').toString() == queueId,
      updater: (order) {
        final now = DateTime.now().toUtc().toIso8601String();
        final lifecycle = staleConflict
            ? OrderLifecycleState.staleConflict
            : (terminal
                  ? OrderLifecycleState.failedTerminal
                  : OrderLifecycleState.failedRetryable);
        return <String, dynamic>{
          ...order,
          'status': lifecycle.value,
          'lifecycle_state': lifecycle.value,
          'is_pending_sync': !terminal && !staleConflict,
          'last_sync_attempt_at': now,
          'conflict_detected_at': staleConflict
              ? now
              : (order['conflict_detected_at'] ?? ''),
          'retry_count': retryCount,
          'sync_error': errorMessage,
        };
      },
    );
  }

  Future<void> markQueuedOrderPendingRetry({
    required String scope,
    required String queueId,
    bool resetRetryCount = false,
  }) async {
    await _updateMatching(
      scope: scope,
      matcher: (order) => (order['local_queue_id'] ?? '').toString() == queueId,
      updater: (order) {
        return <String, dynamic>{
          ...order,
          'status': OrderLifecycleState.pendingSync.value,
          'lifecycle_state': OrderLifecycleState.pendingSync.value,
          'is_pending_sync': true,
          'sync_error': '',
          if (resetRetryCount) 'retry_count': 0,
        };
      },
    );
  }

  Future<void> markQueuedOrderSynced({
    required String scope,
    required String queueId,
    required Map<String, dynamic> syncedOrder,
    bool reconciled = true,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    
    // Find existing to merge metadata
    Map<String, dynamic>? existing;
    final keys = _getOrderKeys(scope);
    String? matchedKey;
    for (final key in keys) {
      final raw = _storage.ordersBox.get(_orderRecordKey(scope, key));
      if (raw is Map && (raw['local_queue_id'] ?? '').toString() == queueId) {
        existing = Map<String, dynamic>.from(raw);
        matchedKey = key;
        break;
      }
    }

    final existingConfirmedAt = existing?['confirmed_at'];

    final normalizedSynced = <String, dynamic>{
      ...?existing,
      ...syncedOrder,
      'is_pending_sync': false,
      'local_queue_id': queueId,
      'lifecycle_state': reconciled
          ? OrderLifecycleState.reconciled.value
          : OrderLifecycleState.confirmed.value,
      'confirmed_at':
          TextSanitizer.fix(
            syncedOrder['confirmed_at'] ?? existingConfirmedAt,
          ).isNotEmpty
          ? syncedOrder['confirmed_at'] ?? existingConfirmedAt
          : now,
      'last_sync_attempt_at': now,
      'sync_error': '',
    };

    final newStableKey = _stableKey(normalizedSynced);
    
    // If the key changed (e.g. from queue ID to server ID), cleanup old
    if (matchedKey != null && matchedKey != newStableKey) {
      await _storage.ordersBox.delete(_orderRecordKey(scope, matchedKey));
    }

    await _storage.ordersBox.put(_orderRecordKey(scope, newStableKey), normalizedSynced);
    
    // Update keys list
    final keySet = _getOrderKeys(scope).toSet();
    if (matchedKey != null) keySet.remove(matchedKey);
    keySet.add(newStableKey);
    await _storage.ordersBox.put(_orderKeysListKey(scope), keySet.toList());
  }

  Map<String, dynamic>? findByQueueId(String scope, String queueId) {
    final normalized = queueId.trim();
    if (normalized.isEmpty) return null;
    
    final keys = _getOrderKeys(scope);
    for (final key in keys) {
      final raw = _storage.ordersBox.get(_orderRecordKey(scope, key));
      if (raw is Map && (raw['local_queue_id'] ?? '').toString() == normalized) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return null;
  }

  Map<String, dynamic>? findByOrderUuid(String scope, String orderUuid) {
    final normalized = orderUuid.trim();
    if (normalized.isEmpty) return null;

    final keys = _getOrderKeys(scope);
    for (final key in keys) {
      final raw = _storage.ordersBox.get(_orderRecordKey(scope, key));
      if (raw is Map) {
         if ((raw['order_uuid'] ?? '').toString().trim() == normalized ||
             (raw['idempotency_key'] ?? '').toString().trim() == normalized) {
           return Map<String, dynamic>.from(raw);
         }
      }
    }
    return null;
  }

  Future<void> _updateMatching({
    required String scope,
    required bool Function(Map<String, dynamic> order) matcher,
    required Map<String, dynamic> Function(Map<String, dynamic> order) updater,
  }) async {
    final keys = _getOrderKeys(scope);
    for (final key in keys) {
      final raw = _storage.ordersBox.get(_orderRecordKey(scope, key));
      if (raw is Map) {
        final order = Map<String, dynamic>.from(raw);
        if (matcher(order)) {
          final updated = updater(order);
          await _storage.ordersBox.put(_orderRecordKey(scope, key), updated);
          break;
        }
      }
    }
  }

  List<Map<String, dynamic>> _mergeAndSortOrders(
    Iterable<Map<String, dynamic>> orders,
  ) {
    final deduped = <String, Map<String, dynamic>>{};
    for (final order in orders) {
      final key = _stableKey(order);
      final existing = deduped[key];
      deduped[key] = existing == null
          ? order
          : _mergeOrderRecords(existing, order);
    }

    return deduped.values.toList(growable: false)
      ..sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
  }

  bool _shouldPreserveLocalOrder(Map<String, dynamic> order) {
    final model = OrderModel.fromJson(order);
    return !model.isConfirmedServerSide;
  }

  Map<String, dynamic> _mergeOrderRecords(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = <String, dynamic>{...existing, ...incoming};
    merged['order_number'] = _preferText(incoming['order_number'], existing['order_number']);
    merged['status'] = _preferText(incoming['status'], existing['status']);
    merged['total'] = _preferText(incoming['total'], existing['total']);
    merged['currency'] = _preferText(incoming['currency'], existing['currency']);
    merged['date'] = _preferText(incoming['date'], existing['date']);
    merged['payment_method'] = _preferText(incoming['payment_method'], existing['payment_method']);
    merged['invoice_url'] = _preferText(incoming['invoice_url'], existing['invoice_url']);
    merged['line_items'] = _preferNonEmptyList(incoming['line_items'], existing['line_items']);
    merged['billing'] = _preferNonEmptyMap(incoming['billing'], existing['billing']);
    merged['sham_cash'] = _preferNonEmptyMap(incoming['sham_cash'], existing['sham_cash']);
    merged['order_uuid'] = _preferText(incoming['order_uuid'], existing['order_uuid']);
    merged['idempotency_key'] = _preferText(incoming['idempotency_key'], existing['idempotency_key']);
    merged['local_queue_id'] = _preferText(incoming['local_queue_id'], existing['local_queue_id']);
    merged['retry_count'] = _maxInt(existing['retry_count'], incoming['retry_count']);
    merged['sync_error'] = _preferText(incoming['sync_error'], existing['sync_error']);
    return merged;
  }

  dynamic _preferNonEmptyList(dynamic primary, dynamic secondary) {
    if (primary is List && primary.isNotEmpty) return primary;
    if (secondary is List && secondary.isNotEmpty) return secondary;
    return primary is List ? primary : secondary;
  }

  dynamic _preferNonEmptyMap(dynamic primary, dynamic secondary) {
    if (primary is Map && primary.isNotEmpty) return primary;
    if (secondary is Map && secondary.isNotEmpty) return secondary;
    return primary is Map ? primary : secondary;
  }

  String _stableKey(Map<String, dynamic> order) {
    final uuid = TextSanitizer.fix(order['order_uuid'] ?? order['idempotency_key']);
    if (uuid.isNotEmpty) return uuid;

    final id = _toInt(order['id']);
    if (id != null && id > 0) return id.toString();

    final queueId = TextSanitizer.fix(order['local_queue_id']);
    if (queueId.isNotEmpty) return queueId;

    return 'h_${order.hashCode}';
  }

  String _preferText(dynamic primary, dynamic secondary) {
    final p = TextSanitizer.fix(primary);
    return p.isNotEmpty ? p : TextSanitizer.fix(secondary);
  }

  int _maxInt(dynamic a, dynamic b) {
    final first = _toInt(a) ?? 0;
    final second = _toInt(b) ?? 0;
    return first > second ? first : second;
  }

  int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  int _timestampOf(Map<String, dynamic> order) {
    final raw = (order['confirmed_at'] ?? order['date'] ?? order['date_created'] ?? order['created_locally_at'] ?? '').toString();
    return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
  }

  List<String> _getOrderKeys(String scope) {
    final raw = _storage.ordersBox.get(_orderKeysListKey(scope));
    if (raw is List) return raw.cast<String>();
    return <String>[];
  }

  Future<void> _migrateLegacyIfNecessary(String scope) async {
    final raw = _storage.ordersBox.get(_legacyOrdersKey(scope));
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final orders = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          if (orders.isNotEmpty) {
            await saveOrders(scope, orders);
          }
        }
      } catch (_) {}
      await _storage.ordersBox.delete(_legacyOrdersKey(scope));
    }
  }
}
