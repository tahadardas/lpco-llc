import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/sync/sync_queue_item.dart';
import 'package:lpco_llc/core/sync/sync_queue_repository.dart';

class InMemorySyncQueueStore implements SyncQueueStore {
  String? payload;
  final Map<String, SyncQueueItem> _items = {};

  @override
  String? read() => payload;

  @override
  Future<void> write(String value) async {
    payload = value;
  }

  @override
  List<SyncQueueItem> getAll() => _items.values.toList();

  @override
  Future<void> upsert(SyncQueueItem item) async {
    _items[item.id] = item;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}

void main() {
  group('SyncQueueRepository', () {
    test('deduplicates by operation type + idempotency key', () async {
      final store = InMemorySyncQueueStore();
      final repo = SyncQueueRepository(store: store);

      final first = await repo.enqueue(
        operationType: SyncQueueOperationType.createOrder,
        idempotencyKey: 'idem-1',
        userScope: 'user_1',
        payload: <String, dynamic>{
          'order_payload': <String, dynamic>{'x': 1},
        },
      );

      final second = await repo.enqueue(
        operationType: SyncQueueOperationType.createOrder,
        idempotencyKey: 'idem-1',
        userScope: 'user_1',
        payload: <String, dynamic>{
          'order_payload': <String, dynamic>{'x': 1},
        },
      );

      expect(first.id, equals(second.id));
      expect(repo.getAllItems().length, equals(1));
    });

    test('marks failures with backoff and keeps runnable semantics', () async {
      final store = InMemorySyncQueueStore();
      final repo = SyncQueueRepository(store: store);

      final item = await repo.enqueue(
        operationType: SyncQueueOperationType.createOrder,
        idempotencyKey: 'idem-2',
        userScope: 'user_2',
        payload: <String, dynamic>{
          'order_payload': <String, dynamic>{'x': 1},
        },
      );

      await repo.markFailed(item.id, 'network timeout');
      final updated = repo.getAllItems().single;

      expect(updated.status, equals(SyncQueueStatus.failed));
      expect(updated.attemptCount, equals(1));
      expect(updated.nextRetryAt, isNotNull);

      final runnable = repo.listRunnablePending();
      expect(runnable, isEmpty);
    });

    test('persists queue payload across repository instances', () async {
      final store = InMemorySyncQueueStore();
      final repoA = SyncQueueRepository(store: store);

      final item = await repoA.enqueue(
        operationType: SyncQueueOperationType.confirmShamCash,
        idempotencyKey: 'idem-3',
        userScope: 'user_3',
        payload: <String, dynamic>{'order_id': 10},
      );

      await repoA.markProcessing(item.id);

      final repoB = SyncQueueRepository(store: store);
      final restored = repoB.getAllItems().single;

      expect(restored.id, equals(item.id));
      expect(restored.status, equals(SyncQueueStatus.processing));
      expect(
        restored.operationType,
        equals(SyncQueueOperationType.confirmShamCash),
      );
    });

    test('deduplicates by correlation id for the same logical order', () async {
      final store = InMemorySyncQueueStore();
      final repo = SyncQueueRepository(store: store);

      final first = await repo.enqueue(
        operationType: SyncQueueOperationType.createOrder,
        idempotencyKey: 'idem-a',
        correlationId: 'order-uuid-1',
        userScope: 'user_4',
        payload: <String, dynamic>{
          'order_payload': <String, dynamic>{'x': 1},
        },
      );

      final second = await repo.enqueue(
        operationType: SyncQueueOperationType.createOrder,
        idempotencyKey: 'idem-b',
        correlationId: 'order-uuid-1',
        userScope: 'user_4',
        payload: <String, dynamic>{
          'order_payload': <String, dynamic>{'x': 2},
        },
      );

      expect(first.id, equals(second.id));
      expect(repo.getAllItems().length, equals(1));
    });

    test(
      'terminal failures are excluded from runnable queue after restart',
      () async {
        final store = InMemorySyncQueueStore();
        final repoA = SyncQueueRepository(store: store);

        final item = await repoA.enqueue(
          operationType: SyncQueueOperationType.createOrder,
          idempotencyKey: 'idem-terminal',
          userScope: 'user_5',
          payload: <String, dynamic>{
            'order_payload': <String, dynamic>{'x': 3},
          },
        );

        await repoA.markFailedTerminal(item.id, 'stale conflict');

        final repoB = SyncQueueRepository(store: store);
        final restored = repoB.getAllItems().single;
        final runnable = repoB.listRunnablePending();

        expect(restored.status, equals(SyncQueueStatus.failedTerminal));
        expect(restored.shouldRun(DateTime.now().toUtc()), isFalse);
        expect(runnable, isEmpty);
      },
    );
  });

  group('SyncQueueItem backoff', () {
    test('caps exponential backoff to maximum threshold', () {
      expect(SyncQueueItem.backoffForAttempt(1), const Duration(seconds: 5));
      expect(SyncQueueItem.backoffForAttempt(2), const Duration(seconds: 10));
      expect(SyncQueueItem.backoffForAttempt(8), const Duration(seconds: 300));
      expect(SyncQueueItem.backoffForAttempt(20), const Duration(seconds: 300));
    });
  });
}
