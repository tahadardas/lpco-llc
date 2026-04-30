import 'dart:async';

import 'package:lpco_llc/core/network/network_cubit.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/sync/sync_exceptions.dart';
import 'package:lpco_llc/core/sync/sync_queue_item.dart';
import 'package:lpco_llc/core/sync/sync_queue_repository.dart';
import 'package:lpco_llc/features/orders/data/repositories/order_repository.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:synchronized/synchronized.dart';

class SyncCoordinator {
  static final SyncCoordinator _instance = SyncCoordinator._internal();

  factory SyncCoordinator() => _instance;

  SyncCoordinator._internal();

  final ReachabilityService _reachabilityService = ReachabilityService();
  final SyncQueueRepository _syncQueueRepository = SyncQueueRepository();
  final ProductRepository _productRepository = ProductRepository();
  final OrderRepository _orderRepository = OrderRepository();
  final StorageService _storage = StorageService();
  final Lock _syncLock = Lock();

  StreamSubscription<ReachabilitySnapshot>? _reachabilitySubscription;
  bool _started = false;
  NetworkCubit? _networkCubit;
  static const int _maxRetryAttempts = 8;

  Future<void> start({NetworkCubit? networkCubit}) async {
    _networkCubit = networkCubit;
    if (_started) {
      return;
    }

    _started = true;
    await _reachabilityService.initialize();
    _reachabilitySubscription = _reachabilityService.stream.listen((snapshot) {
      if (snapshot.isOnline) {
        triggerSync();
      }
    });

    if (_reachabilityService.current.isOnline) {
      await triggerSync();
    }
  }

  Future<void> dispose() async {
    await _reachabilitySubscription?.cancel();
    _started = false;
  }

  Future<void> triggerSync() async {
    await _syncLock.synchronized(() async {
      final reachability = await _reachabilityService.refresh();
      if (!reachability.isOnline) {
        return;
      }

      _networkCubit?.setSyncing(true);

      try {
        await _runOutboundSync();
        await _runInboundSync();
        await _orderRepository.reconcileOutstandingQueuedOrders();
        await _syncQueueRepository.compact();
        await _storage.saveSyncMeta('last_sync', <String, dynamic>{
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        });
      } finally {
        _networkCubit?.setSyncing(false);
      }
    });
  }

  Future<void> _runInboundSync() async {
    final user = await _storage.getUser();
    final guest = user == null || user.isGuest;

    await _productRepository.syncCatalogSnapshot(guest: guest);

    if (!guest && user.id != null) {
      try {
        await _orderRepository.getOrders(preferLocal: false);
      } catch (_) {
        // Inbound order sync should not block other synchronization tracks.
      }
    }
  }

  Future<void> _runOutboundSync() async {
    final pending = _syncQueueRepository.listRunnablePending();
    for (final item in pending) {
      await _orderRepository.onQueueSyncStart(item);
      await _syncQueueRepository.markProcessing(item.id);
      try {
        await _process(item);
        await _syncQueueRepository.markCompleted(item.id);
        await _orderRepository.onQueueSyncCompleted(item);
      } on SyncTerminalException catch (error) {
        await _syncQueueRepository.markFailedTerminal(item.id, error.message);
        await _orderRepository.onQueueTerminalFailure(
          item,
          message: error.message,
          code: error.code,
          retryCount: item.attemptCount + 1,
        );
      } catch (error) {
        final nextAttempt = item.attemptCount + 1;
        if (nextAttempt >= _maxRetryAttempts) {
          final message = 'تعذر مزامنة العملية بعد عدة محاولات.';
          await _syncQueueRepository.markFailedTerminal(item.id, message);
          await _orderRepository.onQueueTerminalFailure(
            item,
            message: message,
            code: 'max_retries_exceeded',
            retryCount: nextAttempt,
          );
          continue;
        }
        await _syncQueueRepository.markFailed(item.id, error.toString());
        await _orderRepository.onQueueRetryableFailure(
          item,
          message: error.toString(),
          retryCount: nextAttempt,
        );
      }
    }
  }

  Future<void> _process(SyncQueueItem item) async {
    switch (item.operationType) {
      case SyncQueueOperationType.createOrder:
        await _orderRepository.processQueuedCreateOrder(item);
        return;
      case SyncQueueOperationType.confirmShamCash:
        await _orderRepository.processQueuedShamCashConfirmation(item);
        return;
      default:
        throw Exception('Unsupported sync operation: ${item.operationType}');
    }
  }
}
