import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/sync/sync_queue_item.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/data/services/order_reconciliation_service.dart';

void main() {
  group('OrderReconciliationService', () {
    final service = OrderReconciliationService();

    SyncQueueItem makeQueueItem({required String orderUuid}) {
      return SyncQueueItem.create(
        operationType: SyncQueueOperationType.createOrder,
        idempotencyKey: orderUuid,
        correlationId: orderUuid,
        userScope: 'user_9',
        payload: <String, dynamic>{
          'order_uuid': orderUuid,
          'order_payload': <String, dynamic>{'order_uuid': orderUuid},
        },
      );
    }

    test('matches server order by stable order_uuid', () {
      final queueItem = makeQueueItem(orderUuid: 'uuid-xyz');
      final serverOrders = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'order_number': '1',
          'meta_data': [
            <String, dynamic>{'key': 'order_uuid', 'value': 'uuid-abc'},
          ],
        },
        <String, dynamic>{
          'id': 2,
          'order_number': '2',
          'meta_data': [
            <String, dynamic>{'key': 'order_uuid', 'value': 'uuid-xyz'},
          ],
        },
      ];

      final matched = service.findMatchingServerOrder(
        queueItem: queueItem,
        serverOrders: serverOrders,
      );

      expect(matched, isNotNull);
      expect(matched!['id'], 2);
    });

    test(
      'builds reconciled order payload with deterministic queue correlation',
      () {
        final queueItem = makeQueueItem(orderUuid: 'uuid-r1');
        final now = DateTime.utc(2026, 3, 10, 10, 30);

        final reconciled = service.buildReconciledOrder(
          queueItem: queueItem,
          serverOrder: <String, dynamic>{
            'id': 55,
            'order_number': '55',
            'status': 'processing',
            'currency': 'syp',
          },
          nowUtc: now,
          recoveredFromAmbiguousOutcome: true,
        );

        expect(reconciled['id'], 55);
        expect(reconciled['order_uuid'], 'uuid-r1');
        expect(reconciled['idempotency_key'], 'uuid-r1');
        expect(reconciled['local_queue_id'], queueItem.id);
        expect(reconciled['is_pending_sync'], isFalse);
        expect(
          reconciled['lifecycle_state'],
          OrderLifecycleState.reconciled.value,
        );
        expect(reconciled['confirmed_at'], now.toIso8601String());
      },
    );
  });
}
