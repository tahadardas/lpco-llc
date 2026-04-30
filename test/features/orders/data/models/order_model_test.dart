import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

void main() {
  group('OrderModel lifecycle mapping', () {
    test('maps pending_sync to pending lifecycle and pending flag', () {
      final order = OrderModel.fromJson(<String, dynamic>{
        'id': -1,
        'order_number': 'PENDING-1',
        'status': 'pending_sync',
        'is_pending_sync': true,
      });

      expect(order.lifecycleState, OrderLifecycleState.pendingSync);
      expect(order.isPendingSync, isTrue);
      expect(order.isConfirmedServerSide, isFalse);
    });

    test('maps stale_conflict state and exposes conflict getter', () {
      final order = OrderModel.fromJson(<String, dynamic>{
        'id': -2,
        'order_number': 'PENDING-2',
        'status': 'stale_conflict',
        'lifecycle_state': 'stale_conflict',
        'sync_error': 'price changed',
      });

      expect(order.lifecycleState, OrderLifecycleState.staleConflict);
      expect(order.hasSyncConflict, isTrue);
      expect(order.isPendingSync, isFalse);
    });

    test('treats server order with id as confirmed when lifecycle absent', () {
      final order = OrderModel.fromJson(<String, dynamic>{
        'id': 19,
        'order_number': '19',
        'status': 'processing',
        'is_pending_sync': false,
      });

      expect(order.lifecycleState, OrderLifecycleState.confirmed);
      expect(order.isConfirmedServerSide, isTrue);
    });

    test('maps failed_retryable and failed_terminal states explicitly', () {
      final retryable = OrderModel.fromJson(<String, dynamic>{
        'id': -11,
        'status': 'failed_retryable',
        'lifecycle_state': 'failed_retryable',
      });

      final terminal = OrderModel.fromJson(<String, dynamic>{
        'id': -12,
        'status': 'failed_terminal',
        'lifecycle_state': 'failed_terminal',
      });

      expect(retryable.hasRetryableFailure, isTrue);
      expect(terminal.hasTerminalFailure, isTrue);
    });

    test(
      'prefers normalized top-level fields when nested order map also exists',
      () {
        final order = OrderModel.fromJson(<String, dynamic>{
          'id': 501,
          'order_number': '501',
          'status': 'processing',
          'lifecycle_state': 'confirmed',
          'line_items': [
            <String, dynamic>{
              'product_id': 77,
              'product_name': 'Filter',
              'quantity': 2,
              'total': '10000',
            },
          ],
          'order': <String, dynamic>{
            'id': 501,
            'order_number': '501',
            'status': 'processing',
            'line_items': <dynamic>[],
          },
        });

        expect(order.lineItems, hasLength(1));
        expect(order.lineItems.first.productId, 77);
      },
    );
  });
}
