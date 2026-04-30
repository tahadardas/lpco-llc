import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/core/sync/sync_queue_item.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

class OrderReconciliationService {
  String extractOrderUuidFromQueueItem(SyncQueueItem item) {
    final fromPayload = extractOrderUuidFromQueuePayload(item.payload);
    if (fromPayload.isNotEmpty) {
      return fromPayload;
    }
    return item.idempotencyKey.trim();
  }

  String extractOrderUuidFromQueuePayload(Map<String, dynamic> payload) {
    final direct = TextSanitizer.fix(
      payload['order_uuid'] ?? payload['idempotency_key'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }

    final orderPayload = payload['order_payload'];
    if (orderPayload is Map) {
      return extractOrderUuidFromOrderMap(
        Map<String, dynamic>.from(orderPayload),
      );
    }
    return '';
  }

  String extractOrderUuidFromOrderMap(Map<String, dynamic> order) {
    final direct = TextSanitizer.fix(
      order['order_uuid'] ?? order['idempotency_key'] ?? order['order_uid'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }

    final rawMeta = order['meta_data'] ?? order['meta'];
    if (rawMeta is List) {
      for (final entry in rawMeta.whereType<Map>()) {
        final key = TextSanitizer.fix(entry['key']).toLowerCase();
        if (key == 'order_uuid' ||
            key == 'idempotency_key' ||
            key == 'order_uid') {
          final value = TextSanitizer.fix(entry['value']);
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }

    if (rawMeta is Map) {
      final meta = Map<String, dynamic>.from(rawMeta);
      final value = TextSanitizer.fix(
        meta['order_uuid'] ?? meta['idempotency_key'] ?? meta['order_uid'],
      );
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  Map<String, dynamic>? findMatchingServerOrder({
    required SyncQueueItem queueItem,
    required List<Map<String, dynamic>> serverOrders,
  }) {
    final orderUuid = extractOrderUuidFromQueueItem(queueItem);
    if (orderUuid.isEmpty) {
      return null;
    }

    for (final serverOrder in serverOrders) {
      final candidate = extractOrderUuidFromOrderMap(serverOrder);
      if (candidate.isNotEmpty && candidate == orderUuid) {
        return Map<String, dynamic>.from(serverOrder);
      }
    }
    return null;
  }

  Map<String, dynamic> buildReconciledOrder({
    required SyncQueueItem queueItem,
    required Map<String, dynamic> serverOrder,
    required DateTime nowUtc,
    bool recoveredFromAmbiguousOutcome = false,
  }) {
    final orderUuid = extractOrderUuidFromQueueItem(queueItem);
    final lifecycle = recoveredFromAmbiguousOutcome
        ? OrderLifecycleState.reconciled
        : OrderLifecycleState.confirmed;

    return <String, dynamic>{
      ...serverOrder,
      'order_uuid': orderUuid,
      'idempotency_key': orderUuid,
      'local_queue_id': queueItem.id,
      'is_pending_sync': false,
      'lifecycle_state': lifecycle.value,
      'last_sync_attempt_at': nowUtc.toIso8601String(),
      'confirmed_at': TextSanitizer.fix(serverOrder['confirmed_at']).isNotEmpty
          ? serverOrder['confirmed_at']
          : nowUtc.toIso8601String(),
      'retry_count': queueItem.attemptCount,
      'sync_error': '',
    };
  }
}
