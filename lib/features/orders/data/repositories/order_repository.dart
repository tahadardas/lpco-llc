import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/local/order_local_store.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/sync/sync_exceptions.dart';
import 'package:lpco_llc/core/sync/sync_queue_item.dart';
import 'package:lpco_llc/core/sync/sync_queue_repository.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/data/services/order_reconciliation_service.dart';
import 'package:lpco_llc/features/orders/data/services/order_response_normalizer.dart';
import 'package:lpco_llc/features/orders/data/services/order_stale_price_validator.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

class OrderCreateResult {
  final OrderModel order;
  final bool reusedExisting;
  final String message;

  const OrderCreateResult({
    required this.order,
    required this.reusedExisting,
    required this.message,
  });
}

class OrderRepository {
  final Dio _dio;
  final StorageService _storageService;
  final ReachabilityService _reachabilityService;
  final SyncQueueRepository _syncQueueRepository;
  final OrderLocalStore _orderLocalStore;
  final ProductRepository _productRepository;
  final OrderResponseNormalizer _normalizer;
  final OrderReconciliationService _reconciliationService;
  final String Function() _uuidGenerator;
  final DateTime Function() _nowUtc;
  late final OrderStalePriceValidator _stalePriceValidator;

  OrderRepository({
    Dio? dio,
    StorageService? storageService,
    ReachabilityService? reachabilityService,
    SyncQueueRepository? syncQueueRepository,
    OrderLocalStore? orderLocalStore,
    ProductRepository? productRepository,
    OrderResponseNormalizer? normalizer,
    OrderReconciliationService? reconciliationService,
    OrderStalePriceValidator? stalePriceValidator,
    String Function()? uuidGenerator,
    DateTime Function()? nowUtc,
  }) : _dio = dio ?? DioClient().dio,
       _storageService = storageService ?? StorageService(),
       _reachabilityService = reachabilityService ?? ReachabilityService(),
       _syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(),
       _orderLocalStore = orderLocalStore ?? OrderLocalStore(),
       _productRepository = productRepository ?? ProductRepository(),
       _normalizer = normalizer ?? OrderResponseNormalizer(),
       _reconciliationService =
           reconciliationService ?? OrderReconciliationService(),
       _uuidGenerator = uuidGenerator ?? _defaultUuidLike,
       _nowUtc = nowUtc ?? _defaultNowUtc {
    _stalePriceValidator =
        stalePriceValidator ??
        OrderStalePriceValidator(productRepository: _productRepository);
  }

  Future<List<OrderModel>> getCachedOrders() async {
    final userId = await _storageService.getUserId();
    if (userId == null || userId.isEmpty) return <OrderModel>[];

    final scope = await _resolveUserScope(userId);
    final local = _orderLocalStore.getOrders(scope);
    return local.map(OrderModel.fromJson).toList(growable: false);
  }

  Future<List<OrderModel>> getOrders({bool preferLocal = true}) async {
    final userId = await _storageService.getUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please login to view your orders');
    }

    final scope = await _resolveUserScope(userId);
    final localOrders = _orderLocalStore.getOrders(scope);
    final reachability = _reachabilityService.current;

    if (preferLocal &&
        localOrders.isNotEmpty &&
        reachability.status == ReachabilityStatus.offline) {
      return localOrders.map(OrderModel.fromJson).toList(growable: false);
    }

    if (reachability.status == ReachabilityStatus.offline) {
      if (localOrders.isNotEmpty) {
        return localOrders.map(OrderModel.fromJson).toList(growable: false);
      }
      throw Exception('No internet connection and no cached orders yet');
    }

    final fallbackCurrency =
        (await _storageService.getUser())?.currency ?? 'syp';

    try {
      final normalized = await _fetchAllRemoteOrdersNormalized(
        userId: userId,
        fallbackCurrency: fallbackCurrency,
        fresh: true,
      );
      await _orderLocalStore.syncWithServerSnapshot(scope, normalized);
      final merged = _orderLocalStore.getOrders(scope);
      return merged.map(OrderModel.fromJson).toList(growable: false);
    } on DioException catch (e) {
      if (localOrders.isNotEmpty) {
        return localOrders.map(OrderModel.fromJson).toList(growable: false);
      }
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    } on ApiContractException catch (e) {
      if (localOrders.isNotEmpty) {
        return localOrders.map(OrderModel.fromJson).toList(growable: false);
      }
      throw Exception(e.failure.message);
    }
  }

  Future<OrderModel> getOrderDetails({required OrderModel seedOrder}) async {
    final userId = await _storageService.getUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('يرجى تسجيل الدخول لعرض تفاصيل الطلب');
    }

    final scope = await _resolveUserScope(userId);
    final reachability = _reachabilityService.current;

    // Try to get from local store first
    final local =
        _orderLocalStore.findByOrderUuid(scope, seedOrder.idempotencyKey) ??
        _orderLocalStore.findByQueueId(scope, seedOrder.localQueueId);

    // If we have local data and we are offline, return it
    if (reachability.status == ReachabilityStatus.offline && local != null) {
      return OrderModel.fromJson(local);
    }

    if (reachability.status == ReachabilityStatus.offline && local == null) {
      throw Exception(
        'لا يوجد اتصال بالإنترنت. تفاصيل الطلب غير متوفرة محلياً.',
      );
    }

    final fallbackCurrency =
        (await _storageService.getUser())?.currency ??
        _fallbackCurrencyFor(seedOrder);

    try {
      final remoteOrder = await _fetchRemoteOrderDetailsNormalized(
        userId: userId,
        seedOrder: seedOrder,
        fallbackCurrency: fallbackCurrency,
      );

      if (remoteOrder == null) {
        // If remote fails but we have local, fallback to local
        if (local != null) return OrderModel.fromJson(local);
        throw Exception('تعذر العثور على هذا الطلب في الخادم.');
      }

      return OrderModel.fromJson(remoteOrder);
    } on DioException catch (e) {
      if (local != null) return OrderModel.fromJson(local);
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    } on ApiContractException catch (e) {
      if (local != null) return OrderModel.fromJson(local);
      throw Exception(e.failure.message);
    }
  }

  Future<OrderModel> createOrder({
    required int customerId,
    required String currency,
    required String userGroup,
    required String contactName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String email,
    required String paymentMethod,
    required String paymentMethodTitle,
    required List<Map<String, dynamic>> lineItems,
    String orderComments = '',
    String company = '',
    String postcode = '00000',
    String country = 'SY',
  }) async {
    final result = await createOrderResult(
      customerId: customerId,
      currency: currency,
      userGroup: userGroup,
      contactName: contactName,
      phone: phone,
      address: address,
      city: city,
      state: state,
      email: email,
      paymentMethod: paymentMethod,
      paymentMethodTitle: paymentMethodTitle,
      lineItems: lineItems,
      orderComments: orderComments,
      company: company,
      postcode: postcode,
      country: country,
    );
    return result.order;
  }

  Future<OrderCreateResult> createOrderResult({
    required int customerId,
    required String currency,
    required String userGroup,
    required String contactName,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String email,
    required String paymentMethod,
    required String paymentMethodTitle,
    required List<Map<String, dynamic>> lineItems,
    String orderComments = '',
    String company = '',
    String postcode = '00000',
    String country = 'SY',
  }) async {
    final orderUuid = _uuidGenerator();

    final payload = <String, dynamic>{
      'order_uuid': orderUuid,
      'customer_id': customerId,
      'currency': currency,
      'payment_method': paymentMethod,
      'payment_method_title': paymentMethodTitle,
      'set_paid': false,
      'billing': <String, dynamic>{
        'first_name': contactName,
        'last_name': contactName,
        'phone': phone,
        'company': company,
        'address_1': address,
        'address_2': '',
        'city': city,
        'state': state,
        'postcode': postcode,
        'country': country,
        'email': email,
      },
      'shipping': <String, dynamic>{
        'first_name': contactName,
        'last_name': contactName,
        'address_1': address,
        'address_2': '',
        'city': city,
        'state': state,
        'postcode': postcode,
        'country': country,
        'phone': phone,
      },
      'line_items': lineItems,
      'customer_note': orderComments,
      'meta_data': <Map<String, dynamic>>[
        {'key': 'order_uuid', 'value': orderUuid},
        {'key': 'dms_price_group', 'value': userGroup},
        {'key': 'dms_currency', 'value': currency},
        {'key': 'order_contact_name', 'value': contactName},
        {'key': 'order_phone', 'value': phone},
        {'key': 'order_address', 'value': address},
        {'key': 'order_city', 'value': city},
        {'key': 'order_state', 'value': state},
      ],
    };

    final scope = await _resolveUserScope(customerId.toString());
    final reachability = _reachabilityService.current;

    if (_shouldQueueCreateOrder(reachability)) {
      return _queueOrder(
        scope: scope,
        payload: payload,
        idempotencyKey: orderUuid,
        customerId: customerId,
        currency: currency,
      );
    }

    final staleValidation = await _stalePriceValidator.validateOrderPayload(
      payload,
      guest: false,
    );
    if (staleValidation.hasBlockingConflicts) {
      throw Exception(_buildStaleConflictMessage(staleValidation.conflicts));
    }

    try {
      final response = await _dio.post(
        '/dms/v1/orders',
        data: payload,
        options: _orderRequestOptions(orderUuid),
      );
      final normalized = _normalizer.normalizeCreateOrderResponse(
        response.data,
        fallbackCurrency: currency,
        fallbackOrderUuid: orderUuid,
      );

      await _orderLocalStore.mergeOrders(scope, <Map<String, dynamic>>[
        normalized,
      ]);
      final mergedOrder =
          _findMatchingLocalOrderByIdentifiers(
            scope: scope,
            id: normalized['id'] as int? ?? 0,
            orderNumber: '${normalized['order_number'] ?? ''}',
            orderUuid: TextSanitizer.fix(normalized['order_uuid']),
            localQueueId: '',
          ) ??
          OrderModel.fromJson(normalized);

      final message = TextSanitizer.fix(normalized['message']);
      final reusedExisting = _isDuplicateProtectedResponse(normalized);
      return OrderCreateResult(
        order: mergedOrder,
        reusedExisting: reusedExisting,
        message: message,
      );
    } on ApiContractException catch (e) {
      throw Exception(_mapOrderContractFailure(e.failure));
    } on DioException catch (e) {
      if (_isConnectivityError(e)) {
        final latestReachability = await _reachabilityService.refresh();
        if (_shouldQueueCreateOrder(latestReachability)) {
          return _queueOrder(
            scope: scope,
            payload: payload,
            idempotencyKey: orderUuid,
            customerId: customerId,
            currency: currency,
          );
        }
        final recovered = await _recoverCreatedServerOrder(
          orderUuid: orderUuid,
          createPayload: payload,
        );
        if (recovered != null) {
          await _orderLocalStore.mergeOrders(scope, <Map<String, dynamic>>[
            recovered,
          ]);
          final recoveredOrder =
              _findMatchingLocalOrderByIdentifiers(
                scope: scope,
                id: recovered['id'] as int? ?? 0,
                orderNumber: '${recovered['order_number'] ?? ''}',
                orderUuid: TextSanitizer.fix(recovered['order_uuid']),
                localQueueId: '',
              ) ??
              OrderModel.fromJson(recovered);

          final recoveredMessage = TextSanitizer.fix(recovered['message']);
          return OrderCreateResult(
            order: recoveredOrder,
            reusedExisting: false,
            message: recoveredMessage.isEmpty
                ? 'تم تأكيد الطلب من الخادم بعد إعادة التحقق.'
                : recoveredMessage,
          );
        }
      }
      if (kIsWeb && _isConnectivityError(e) && e.response == null) {
        throw Exception(_buildWebBlockedRequestMessage());
      }
      if (_isStalePriceResponse(e)) {
        throw Exception(
          'تعذر تأكيد الطلب لأن الأسعار/التوفر تغيرت. يرجى مراجعة السلة.',
        );
      }
      throw Exception(_mapOrderDioError(e));
    }
  }

  Future<void> reconcileOutstandingQueuedOrders() async {
    final userId = await _storageService.getUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final reachability = _reachabilityService.current;
    if (!reachability.isOnline) {
      return;
    }

    final scope = await _resolveUserScope(userId);
    final fallbackCurrency =
        (await _storageService.getUser())?.currency ?? 'syp';
    final serverOrders = await _fetchRemoteOrdersNormalized(
      userId: userId,
      fallbackCurrency: fallbackCurrency,
    );

    await _orderLocalStore.mergeOrders(scope, serverOrders);
    await _reconcileQueuedWithServerList(
      scope: scope,
      serverOrders: serverOrders,
    );
  }

  Future<void> confirmShamCashTransfer({
    required int orderId,
    String transactionId = '',
    String proofImageUrl = '',
  }) async {
    final payload = <String, dynamic>{
      if (transactionId.trim().isNotEmpty)
        'transaction_id': transactionId.trim(),
      if (proofImageUrl.trim().isNotEmpty)
        'proof_image_url': proofImageUrl.trim(),
    };

    final scope = await _resolveUserScope(
      await _storageService.getUserId() ?? 'guest',
    );
    final reachability = _reachabilityService.current;
    final idempotency = _shamCashIdempotency(orderId, transactionId);

    if (!reachability.isOnline) {
      final queueItem = await _syncQueueRepository.enqueue(
        operationType: SyncQueueOperationType.confirmShamCash,
        idempotencyKey: idempotency,
        correlationId: 'sham_confirm::$orderId',
        userScope: scope,
        payload: <String, dynamic>{'order_id': orderId, 'payload': payload},
      );

      await _storageService.saveSyncMeta(
        'pending_sham_confirm::${queueItem.id}',
        <String, dynamic>{'created_at': _nowUtc().toIso8601String()},
      );
      return;
    }

    try {
      await _dio.post(
        '/dms/v1/orders/$orderId/sham-cash-confirm',
        data: payload,
      );
    } on DioException catch (e) {
      if (_isConnectivityError(e)) {
        await _syncQueueRepository.enqueue(
          operationType: SyncQueueOperationType.confirmShamCash,
          idempotencyKey: idempotency,
          correlationId: 'sham_confirm::$orderId',
          userScope: scope,
          payload: <String, dynamic>{'order_id': orderId, 'payload': payload},
        );
        return;
      }
      throw Exception(_mapOrderDioError(e, forShamCashConfirm: true));
    }
  }

  Future<void> processQueuedCreateOrder(SyncQueueItem item) async {
    final payload = item.payload['order_payload'];
    if (payload is! Map) {
      throw const SyncTerminalException(
        'Invalid queued create_order payload',
        code: 'invalid_payload',
      );
    }

    final orderPayload = Map<String, dynamic>.from(payload);
    final orderUuid = _reconciliationService.extractOrderUuidFromQueueItem(
      item,
    );
    if (orderUuid.isEmpty) {
      throw const SyncTerminalException(
        'Missing order UUID for queued order',
        code: 'missing_order_uuid',
      );
    }

    await _orderLocalStore.markQueuedOrderSyncing(
      scope: item.userScope,
      queueId: item.id,
      retryCount: item.attemptCount + 1,
    );

    final staleValidation = await _stalePriceValidator.validateOrderPayload(
      orderPayload,
      guest: false,
    );
    if (staleValidation.hasBlockingConflicts) {
      throw SyncConflictException(
        _buildStaleConflictMessage(staleValidation.conflicts),
        conflicts: staleValidation.conflicts
            .map((e) => e.toJson())
            .toList(growable: false),
      );
    }

    try {
      final response = await _dio.post(
        '/dms/v1/orders',
        data: orderPayload,
        options: _orderRequestOptions(orderUuid),
      );

      final fallbackCurrency = (item.payload['currency'] ?? 'syp').toString();
      Map<String, dynamic> normalized;
      try {
        normalized = _normalizer.normalizeCreateOrderResponse(
          response.data,
          fallbackCurrency: fallbackCurrency,
          fallbackOrderUuid: orderUuid,
        );
      } on ApiContractException catch (error) {
        throw SyncTerminalException(
          error.failure.message,
          code: 'malformed_create_response',
        );
      }

      final reconciled = _reconciliationService.buildReconciledOrder(
        queueItem: item,
        serverOrder: normalized,
        nowUtc: _nowUtc(),
      );

      await _orderLocalStore.markQueuedOrderSynced(
        scope: item.userScope,
        queueId: item.id,
        syncedOrder: reconciled,
        reconciled: true,
      );
    } on DioException catch (e) {
      if (_isConnectivityError(e)) {
        final recovered = await _recoverCreatedServerOrder(
          orderUuid: orderUuid,
          createPayload: orderPayload,
        );
        if (recovered != null) {
          final reconciled = _reconciliationService.buildReconciledOrder(
            queueItem: item,
            serverOrder: recovered,
            nowUtc: _nowUtc(),
            recoveredFromAmbiguousOutcome: true,
          );
          await _orderLocalStore.markQueuedOrderSynced(
            scope: item.userScope,
            queueId: item.id,
            syncedOrder: reconciled,
            reconciled: true,
          );
          return;
        }

        throw const SyncRetryableException(
          'تعذر تأكيد استلام الخادم للطلب، ستتم إعادة المحاولة تلقائياً.',
        );
      }

      if (_isStalePriceResponse(e)) {
        throw SyncConflictException(
          ApiContract.extractErrorMessage(e.response?.data),
        );
      }

      if (_isTerminalOrderError(e)) {
        throw SyncTerminalException(
          ApiContract.extractErrorMessage(e.response?.data),
          code: 'server_rejected_order',
        );
      }

      throw SyncRetryableException(
        ApiContract.extractErrorMessage(e.response?.data),
      );
    }
  }

  Future<void> processQueuedShamCashConfirmation(SyncQueueItem item) async {
    final orderId = item.payload['order_id'];
    final payload = item.payload['payload'];
    final normalizedOrderId = orderId is int
        ? orderId
        : int.tryParse('${orderId ?? ''}');

    if (normalizedOrderId == null) {
      throw const SyncTerminalException(
        'Invalid queued sham-cash confirmation payload',
        code: 'invalid_payload',
      );
    }

    try {
      await _dio.post(
        '/dms/v1/orders/$normalizedOrderId/sham-cash-confirm',
        data: payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{},
      );
    } on DioException catch (e) {
      if (_isConnectivityError(e)) {
        throw SyncRetryableException(
          ApiContract.extractErrorMessage(e.response?.data),
        );
      }
      if (_isTerminalOrderError(e)) {
        throw SyncTerminalException(
          ApiContract.extractErrorMessage(e.response?.data),
          code: 'sham_cash_terminal',
        );
      }
      throw SyncRetryableException(
        ApiContract.extractErrorMessage(e.response?.data),
      );
    }
  }

  Future<void> onQueueSyncStart(SyncQueueItem item) async {
    if (item.operationType != SyncQueueOperationType.createOrder) {
      return;
    }
    await _orderLocalStore.markQueuedOrderSyncing(
      scope: item.userScope,
      queueId: item.id,
      retryCount: item.attemptCount + 1,
    );
  }

  Future<void> onQueueRetryableFailure(
    SyncQueueItem item, {
    required String message,
    required int retryCount,
  }) async {
    if (item.operationType != SyncQueueOperationType.createOrder) {
      return;
    }
    await _orderLocalStore.markQueuedOrderFailed(
      scope: item.userScope,
      queueId: item.id,
      errorMessage: _normalizeError(message),
      retryCount: retryCount,
      terminal: false,
    );
  }

  Future<void> onQueueTerminalFailure(
    SyncQueueItem item, {
    required String message,
    required String code,
    required int retryCount,
  }) async {
    if (item.operationType != SyncQueueOperationType.createOrder) {
      return;
    }

    final staleConflict = code == 'stale_conflict';
    await _orderLocalStore.markQueuedOrderFailed(
      scope: item.userScope,
      queueId: item.id,
      errorMessage: _normalizeError(message),
      retryCount: retryCount,
      terminal: true,
      staleConflict: staleConflict,
    );

    if (staleConflict) {
      await _storageService
          .saveSyncMeta('order_conflict::${item.id}', <String, dynamic>{
            'detected_at': _nowUtc().toIso8601String(),
            'message': _normalizeError(message),
          });
    }
  }

  Future<void> onQueueSyncCompleted(SyncQueueItem item) async {
    if (item.operationType != SyncQueueOperationType.createOrder) {
      return;
    }
    await _storageService
        .saveSyncMeta('order_synced::${item.id}', <String, dynamic>{
          'synced_at': _nowUtc().toIso8601String(),
          'order_uuid': _reconciliationService.extractOrderUuidFromQueueItem(
            item,
          ),
        });
  }

  Future<void> retryFailedOrder(OrderModel order) async {
    if (order.hasSyncConflict) {
      throw Exception(
        'لا يمكن إعادة إرسال هذا الطلب بسبب تعارض أسعار/توفر. يرجى مراجعة السلة أولاً.',
      );
    }

    final queueId = order.localQueueId.trim();
    if (queueId.isEmpty) {
      throw Exception('لا يتوفر معرّف مزامنة محلي لهذا الطلب.');
    }

    SyncQueueItem? queueItem;
    for (final item in _syncQueueRepository.getAllItems()) {
      if (item.id == queueId) {
        queueItem = item;
        break;
      }
    }

    if (queueItem == null) {
      throw Exception('تعذر العثور على مهمة المزامنة الخاصة بهذا الطلب.');
    }

    if (queueItem.operationType != SyncQueueOperationType.createOrder) {
      throw Exception('نوع مهمة المزامنة غير مدعوم لإعادة الإرسال اليدوي.');
    }

    if (queueItem.status == SyncQueueStatus.completed) {
      throw Exception('تم إرسال هذا الطلب بالفعل.');
    }

    if (queueItem.status == SyncQueueStatus.processing) {
      throw Exception('الطلب قيد الإرسال حالياً.');
    }

    await _syncQueueRepository.markPending(queueItem.id, resetAttempts: true);
    await _orderLocalStore.markQueuedOrderPendingRetry(
      scope: queueItem.userScope,
      queueId: queueItem.id,
      resetRetryCount: true,
    );
  }

  String buildFallbackInvoiceUrl(OrderModel order) {
    return '${AppConfig.baseUrl}/?download_invoice=1&order_id=${order.id}';
  }

  Future<OrderCreateResult> _queueOrder({
    required String scope,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    required int customerId,
    required String currency,
  }) async {
    final queueItem = await _syncQueueRepository.enqueue(
      operationType: SyncQueueOperationType.createOrder,
      idempotencyKey: idempotencyKey,
      correlationId: idempotencyKey,
      userScope: scope,
      payload: <String, dynamic>{
        'order_uuid': idempotencyKey,
        'order_payload': payload,
        'customer_id': customerId,
        'currency': currency,
        'created_locally_at': _nowUtc().toIso8601String(),
        'price_snapshot': _buildPriceSnapshot(payload['line_items']),
      },
    );

    await _orderLocalStore.upsertQueuedPendingOrder(
      scope: scope,
      queueId: queueItem.id,
      orderUuid: idempotencyKey,
      idempotencyKey: idempotencyKey,
      summary: <String, dynamic>{
        'order_number': 'PENDING-${queueItem.id.substring(3, 11)}',
        'currency': currency,
        'total': _sumLineItems(payload['line_items']),
        'payment_method': payload['payment_method'],
        'line_items': payload['line_items'] ?? const <dynamic>[],
        'billing': payload['billing'] ?? const <String, dynamic>{},
      },
    );

    final pending = _orderLocalStore.findByQueueId(scope, queueItem.id);
    final pendingOrder = OrderModel.fromJson(
      pending ??
          <String, dynamic>{
            'id': -DateTime.now().millisecondsSinceEpoch,
            'order_number': 'PENDING',
            'status': OrderLifecycleState.pendingSync.value,
            'lifecycle_state': OrderLifecycleState.pendingSync.value,
            'total': _sumLineItems(payload['line_items']),
            'currency': currency,
            'date': _nowUtc().toIso8601String(),
            'payment_method': payload['payment_method'],
            'invoice_url': '',
            'line_items': payload['line_items'] ?? const <dynamic>[],
            'is_pending_sync': true,
            'local_queue_id': queueItem.id,
            'order_uuid': idempotencyKey,
            'idempotency_key': idempotencyKey,
            'created_locally_at': _nowUtc().toIso8601String(),
            'enqueued_at': _nowUtc().toIso8601String(),
          },
    );

    return OrderCreateResult(
      order: pendingOrder,
      reusedExisting: false,
      message: 'تم حفظ الطلب محلياً وسيتم إرساله تلقائياً عند عودة الاتصال.',
    );
  }

  Future<void> _reconcileQueuedWithServerList({
    required String scope,
    required List<Map<String, dynamic>> serverOrders,
  }) async {
    final queueItems = _syncQueueRepository
        .getAllItems()
        .where((item) {
          if (item.userScope != scope) {
            return false;
          }
          if (item.operationType != SyncQueueOperationType.createOrder) {
            return false;
          }
          return item.status != SyncQueueStatus.completed &&
              item.status != SyncQueueStatus.failedTerminal;
        })
        .toList(growable: false);

    for (final item in queueItems) {
      final matched = _reconciliationService.findMatchingServerOrder(
        queueItem: item,
        serverOrders: serverOrders,
      );
      if (matched == null) {
        continue;
      }

      final reconciled = _reconciliationService.buildReconciledOrder(
        queueItem: item,
        serverOrder: matched,
        nowUtc: _nowUtc(),
        recoveredFromAmbiguousOutcome: true,
      );

      await _orderLocalStore.markQueuedOrderSynced(
        scope: scope,
        queueId: item.id,
        syncedOrder: reconciled,
        reconciled: true,
      );
      await _syncQueueRepository.markCompleted(item.id);
    }
  }

  Future<Map<String, dynamic>?> _recoverCreatedServerOrder({
    required String orderUuid,
    Map<String, dynamic>? createPayload,
  }) async {
    final normalizedUuid = orderUuid.trim();
    if (normalizedUuid.isEmpty && createPayload == null) {
      return null;
    }

    final userId = await _storageService.getUserId();
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }

    final fallbackCurrency =
        (await _storageService.getUser())?.currency ?? 'syp';
    final retryDelays = <Duration>[
      Duration.zero,
      const Duration(milliseconds: 700),
      const Duration(seconds: 2),
    ];

    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final serverOrders = await _fetchRemoteOrdersNormalized(
        userId: userId,
        fallbackCurrency: fallbackCurrency,
        page: 1,
        perPage: 50,
        fresh: true,
      );

      for (final serverOrder in serverOrders) {
        final candidate = _reconciliationService.extractOrderUuidFromOrderMap(
          serverOrder,
        );
        if (normalizedUuid.isNotEmpty && candidate == normalizedUuid) {
          return serverOrder;
        }
      }

      if (createPayload != null && _canUseHeuristicRecovery(normalizedUuid)) {
        final matched = _findMatchingServerOrderForCreatePayload(
          serverOrders,
          createPayload,
        );
        if (matched != null) {
          return matched;
        }
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchAllRemoteOrdersNormalized({
    required String userId,
    required String fallbackCurrency,
    int perPage = 50,
    int maxPages = 20,
    bool fresh = false,
  }) async {
    final all = <Map<String, dynamic>>[];

    for (var page = 1; page <= maxPages; page++) {
      final batch = await _fetchRemoteOrdersNormalized(
        userId: userId,
        fallbackCurrency: fallbackCurrency,
        page: page,
        perPage: perPage,
        fresh: fresh,
      );

      if (batch.isEmpty) {
        break;
      }

      all.addAll(batch);
      if (batch.length < perPage) {
        break;
      }
    }

    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteOrdersNormalized({
    required String userId,
    required String fallbackCurrency,
    int page = 1,
    int perPage = 20,
    bool fresh = false,
  }) async {
    final response = await _dio.get(
      '/dms/v1/user/$userId/orders',
      queryParameters: <String, dynamic>{
        'include': 'details',
        'rev': '20260310',
        'page': page,
        'per_page': perPage,
        if (fresh) '_ts': _nowUtc().millisecondsSinceEpoch,
      },
      options: fresh ? _freshReadOptions() : null,
    );

    return _normalizer.normalizeOrderListResponse(
      response.data,
      endpoint: '/dms/v1/user/$userId/orders',
      fallbackCurrency: fallbackCurrency,
    );
  }

  Future<Map<String, dynamic>?> _fetchRemoteOrderDetailsNormalized({
    required String userId,
    required OrderModel seedOrder,
    required String fallbackCurrency,
  }) async {
    const int perPage = 50;
    const int maxPages = 40;
    for (var page = 1; page <= maxPages; page++) {
      final orders = await _fetchRemoteOrdersNormalized(
        userId: userId,
        fallbackCurrency: fallbackCurrency,
        page: page,
        perPage: perPage,
        fresh: true,
      );
      if (orders.isEmpty) {
        break;
      }

      final matched = _findMatchingOrderMap(orders, seedOrder);
      if (matched != null) {
        return matched;
      }

      if (orders.length < perPage) {
        break;
      }
    }
    return null;
  }

  OrderModel? _findMatchingLocalOrderByIdentifiers({
    required String scope,
    required int id,
    required String orderNumber,
    required String orderUuid,
    required String localQueueId,
  }) {
    final uuid = orderUuid.trim();
    final queueId = localQueueId.trim();
    final number = orderNumber.trim();

    for (final raw in _orderLocalStore.getOrders(scope)) {
      if (_matchesOrderRecord(
        raw,
        id: id,
        orderNumber: number,
        orderUuid: uuid,
        localQueueId: queueId,
      )) {
        return OrderModel.fromJson(raw);
      }
    }

    return null;
  }

  Map<String, dynamic>? _findMatchingOrderMap(
    Iterable<Map<String, dynamic>> orders,
    OrderModel seedOrder,
  ) {
    for (final order in orders) {
      if (_matchesOrderRecord(
        order,
        id: seedOrder.id,
        orderNumber: seedOrder.orderNumber,
        orderUuid: seedOrder.idempotencyKey,
        localQueueId: seedOrder.localQueueId,
      )) {
        return order;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findMatchingServerOrderForCreatePayload(
    Iterable<Map<String, dynamic>> orders,
    Map<String, dynamic> createPayload,
  ) {
    for (final order in orders) {
      if (_matchesServerOrderToCreatePayload(order, createPayload)) {
        return order;
      }
    }
    return null;
  }

  bool _matchesOrderRecord(
    Map<String, dynamic> raw, {
    required int id,
    required String orderNumber,
    required String orderUuid,
    required String localQueueId,
  }) {
    final candidateId = raw['id'] is int
        ? raw['id'] as int
        : int.tryParse('${raw['id'] ?? ''}') ?? 0;
    if (id > 0 && candidateId == id) {
      return true;
    }

    final candidateOrderNumber = TextSanitizer.fix(
      raw['order_number'] ?? raw['number'],
    );
    if (orderNumber.trim().isNotEmpty &&
        candidateOrderNumber == orderNumber.trim()) {
      return true;
    }

    final requestedToken = _orderNumberToken(orderNumber);
    final candidateToken = _orderNumberToken(candidateOrderNumber);
    if (requestedToken.isNotEmpty && candidateToken == requestedToken) {
      return true;
    }

    final requestedDigits = _orderNumberDigits(orderNumber);
    final parsedRequestedId = int.tryParse(requestedDigits);
    if (parsedRequestedId != null &&
        parsedRequestedId > 0 &&
        candidateId == parsedRequestedId) {
      return true;
    }

    final candidateUuid = _normalizer.extractOrderUuidFromOrder(raw).trim();
    if (orderUuid.trim().isNotEmpty && candidateUuid == orderUuid.trim()) {
      return true;
    }

    final candidateQueueId = TextSanitizer.fix(raw['local_queue_id']);
    return localQueueId.trim().isNotEmpty &&
        candidateQueueId == localQueueId.trim();
  }

  bool _matchesServerOrderToCreatePayload(
    Map<String, dynamic> serverOrder,
    Map<String, dynamic> createPayload,
  ) {
    if (!_isRecentServerOrder(serverOrder)) {
      return false;
    }

    final payloadItems = _compactPayloadItems(createPayload['line_items']);
    final serverItems = _compactServerItems(serverOrder['line_items']);
    if (payloadItems.isEmpty ||
        serverItems.isEmpty ||
        payloadItems.length != serverItems.length) {
      return false;
    }

    final remainingServerItems = List<Map<String, int>>.from(serverItems);
    for (final payloadItem in payloadItems) {
      final matchIndex = remainingServerItems.indexWhere(
        (serverItem) =>
            serverItem['product_id'] == payloadItem['product_id'] &&
            serverItem['variation_id'] == payloadItem['variation_id'] &&
            serverItem['quantity'] == payloadItem['quantity'],
      );
      if (matchIndex < 0) {
        return false;
      }
      remainingServerItems.removeAt(matchIndex);
    }

    final payloadTotal = _toNum(_sumLineItems(createPayload['line_items']));
    final serverTotal = _toNum(serverOrder['total']);
    if ((payloadTotal - serverTotal).abs() > 0.01) {
      return false;
    }

    final payloadBilling = createPayload['billing'];
    final serverBilling = serverOrder['billing'];
    if (!_billingLooksLikeSameOrder(serverBilling, payloadBilling)) {
      return false;
    }

    return true;
  }

  List<Map<String, int>> _compactPayloadItems(dynamic rawItems) {
    if (rawItems is! List) {
      return const <Map<String, int>>[];
    }

    return rawItems
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return <String, int>{
            'product_id': _toInt(item['product_id']),
            'variation_id': _toInt(item['variation_id']),
            'quantity': _toInt(item['quantity'], fallback: 1),
          };
        })
        .toList(growable: false);
  }

  List<Map<String, int>> _compactServerItems(dynamic rawItems) {
    if (rawItems is! List) {
      return const <Map<String, int>>[];
    }

    return rawItems
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          return <String, int>{
            'product_id': _toInt(item['product_id']),
            'variation_id': _toInt(item['variation_id']),
            'quantity': _toInt(item['quantity'], fallback: 1),
          };
        })
        .toList(growable: false);
  }

  bool _billingLooksLikeSameOrder(
    dynamic serverBilling,
    dynamic payloadBilling,
  ) {
    final server = serverBilling is Map
        ? Map<String, dynamic>.from(serverBilling)
        : const <String, dynamic>{};
    final payload = payloadBilling is Map
        ? Map<String, dynamic>.from(payloadBilling)
        : const <String, dynamic>{};

    final payloadEmail = _normalizeIdentityText(payload['email']);
    final serverEmail = _normalizeIdentityText(server['email']);
    final payloadPhone = _digitsOnly(payload['phone']);
    final serverPhone = _digitsOnly(server['phone']);

    var identityMatched = false;
    if (payloadEmail.isNotEmpty && serverEmail.isNotEmpty) {
      identityMatched = payloadEmail == serverEmail;
    }
    if (!identityMatched && payloadPhone.isNotEmpty && serverPhone.isNotEmpty) {
      identityMatched = payloadPhone == serverPhone;
    }
    if (!identityMatched) {
      return false;
    }

    final payloadCity = _normalizeIdentityText(payload['city']);
    final serverCity = _normalizeIdentityText(server['city']);
    if (payloadCity.isNotEmpty &&
        serverCity.isNotEmpty &&
        payloadCity != serverCity) {
      return false;
    }

    final payloadAddress = _normalizeIdentityText(payload['address_1']);
    final serverAddress = _normalizeIdentityText(server['address']);
    if (payloadAddress.isNotEmpty &&
        serverAddress.isNotEmpty &&
        payloadAddress != serverAddress) {
      return false;
    }

    return true;
  }

  bool _isRecentServerOrder(Map<String, dynamic> serverOrder) {
    final rawDate = TextSanitizer.fix(serverOrder['date']);
    if (rawDate.isEmpty) {
      return false;
    }

    final parsed =
        DateTime.tryParse(rawDate) ??
        DateTime.tryParse(rawDate.replaceFirst(' ', 'T'));
    if (parsed == null) {
      return false;
    }

    final diff = _nowUtc().difference(parsed.toUtc()).abs();
    return diff <= const Duration(minutes: 10);
  }

  String _normalizeIdentityText(dynamic value) {
    return TextSanitizer.fix(value).trim().toLowerCase();
  }

  String _digitsOnly(dynamic value) {
    return TextSanitizer.fix(value).replaceAll(RegExp(r'[^0-9]'), '');
  }

  num _toNum(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse('${value ?? ''}') ?? 0;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  Options _freshReadOptions() {
    return DioClient().buildOptions(cachePolicy: CachePolicy.noCache);
  }

  String _fallbackCurrencyFor(OrderModel order) {
    final currency = order.currency.trim().toLowerCase();
    return currency.isEmpty ? 'syp' : currency;
  }

  String _orderNumberToken(String raw) {
    return TextSanitizer.fix(
      raw,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _orderNumberDigits(String raw) {
    return TextSanitizer.fix(raw).replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _buildWebBlockedRequestMessage() {
    return 'تعذر على المتصفح الوصول إلى الخادم لإرسال الطلب. '
        'قد يكون السبب CORS أو انتهاء الجلسة أو خطأ داخلي من الخادم. '
        'حدّث الصفحة، سجّل الدخول مجددًا، ثم أعد المحاولة.';
  }

  bool _isConnectivityError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.response == null;
  }

  bool _isStalePriceResponse(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status != 409 && status != 422) {
      return false;
    }

    final message = ApiContract.extractErrorMessage(
      error.response?.data,
    ).toLowerCase();
    return message.contains('price') ||
        message.contains('stock') ||
        message.contains('availability') ||
        message.contains('stale') ||
        message.contains('مخزون') ||
        message.contains('سعر');
  }

  bool _isTerminalOrderError(DioException error) {
    final status = error.response?.statusCode ?? 0;
    return status == 400 ||
        status == 401 ||
        status == 403 ||
        status == 404 ||
        status == 409 ||
        status == 410 ||
        status == 422;
  }

  bool _isDuplicateProtectedResponse(Map<String, dynamic> normalized) {
    final message = TextSanitizer.fix(normalized['message']).toLowerCase();
    if (message.contains('already created') ||
        message.contains('existing order')) {
      return true;
    }
    return normalized['duplicate_protected'] == true ||
        normalized['reused_existing'] == true;
  }

  bool _shouldQueueCreateOrder(ReachabilitySnapshot reachability) {
    return !reachability.isOnline;
  }

  bool _canUseHeuristicRecovery(String orderUuid) {
    return orderUuid.trim().isEmpty;
  }

  Future<String> _resolveUserScope(String fallbackUserId) async {
    final user = await _storageService.getUser();
    if (user == null || user.isGuest) {
      return 'guest';
    }

    if (user.id != null) {
      return 'user_${user.id}';
    }

    final normalizedFallback = fallbackUserId.trim().isEmpty
        ? 'unknown'
        : fallbackUserId.trim();
    return 'user_$normalizedFallback';
  }

  String _sumLineItems(dynamic lineItems) {
    if (lineItems is! List) {
      return '0';
    }

    num total = 0;
    for (final item in lineItems.whereType<Map>()) {
      final quantity = item['quantity'] is int
          ? item['quantity'] as int
          : int.tryParse('${item['quantity'] ?? '0'}') ?? 0;
      final unitPrice = num.tryParse('${item['unit_price'] ?? '0'}') ?? 0;
      total += quantity * unitPrice;
    }

    if (total == total.roundToDouble()) {
      return total.toInt().toString();
    }
    return total.toStringAsFixed(2);
  }

  List<Map<String, dynamic>> _buildPriceSnapshot(dynamic lineItems) {
    if (lineItems is! List) {
      return const <Map<String, dynamic>>[];
    }

    return lineItems
        .whereType<Map>()
        .map((item) {
          return <String, dynamic>{
            'product_id': item['product_id'],
            'variation_id': item['variation_id'],
            'quantity': item['quantity'],
            'unit_type': item['unit_type'],
            'unit_price': item['unit_price'],
          };
        })
        .toList(growable: false);
  }

  String _buildStaleConflictMessage(List<OrderPriceConflict> conflicts) {
    if (conflicts.isEmpty) {
      return 'لا يمكن مزامنة الطلب بسبب تغير الأسعار أو التوفر.';
    }

    final first = conflicts.first;
    switch (first.code) {
      case 'price_changed':
        return 'تغيّر سعر بعض المنتجات. يرجى مراجعة السلة قبل تأكيد الطلب.';
      case 'out_of_stock':
        return 'بعض المنتجات لم تعد متوفرة حالياً. يرجى تحديث السلة.';
      case 'unit_unavailable':
        return 'الوحدة المختارة لبعض المنتجات لم تعد متاحة.';
      default:
        return first.message;
    }
  }

  String _mapOrderContractFailure(ApiFailure failure) {
    return _mapOrderError(
      statusCode: failure.status,
      code: failure.code,
      message: failure.message,
      payload: failure.message,
      forShamCashConfirm: false,
    );
  }

  String _mapOrderDioError(
    DioException error, {
    bool forShamCashConfirm = false,
  }) {
    final payload = error.response?.data;
    final statusCode = _extractStatusCode(payload, error.response?.statusCode);
    final code = _extractErrorCode(payload);
    final message = _extractErrorMessage(payload);
    return _mapOrderError(
      statusCode: statusCode,
      code: code,
      message: message,
      payload: payload,
      forShamCashConfirm: forShamCashConfirm,
    );
  }

  String _mapOrderError({
    required int? statusCode,
    required String code,
    required String message,
    required dynamic payload,
    required bool forShamCashConfirm,
  }) {
    final normalizedCode = code.trim().toLowerCase();
    final normalizedMessage = message.trim().toLowerCase();
    final status = statusCode ?? 0;

    if (_looksLikeBlockedHtml(payload) || _looksLikeBlockedHtml(message)) {
      return _buildWebBlockedRequestMessage();
    }

    if (_isGuestCheckoutRestriction(
      code: normalizedCode,
      message: normalizedMessage,
      status: status,
    )) {
      return 'إتمام الطلب كضيف غير متاح حالياً. يرجى تسجيل الدخول ثم إعادة المحاولة.';
    }

    if (_isAuthOrderFailure(
      code: normalizedCode,
      message: normalizedMessage,
      status: status,
    )) {
      return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى ثم إعادة المحاولة.';
    }

    if (_isPermissionOrderFailure(
      code: normalizedCode,
      message: normalizedMessage,
      status: status,
    )) {
      return forShamCashConfirm
          ? 'لا تملك صلاحية تأكيد عملية الدفع لهذا الطلب.'
          : 'لا تملك صلاحية تنفيذ هذا الطلب.';
    }

    if (_isPaymentValidationFailure(
      code: normalizedCode,
      message: normalizedMessage,
    )) {
      return forShamCashConfirm
          ? 'تعذر تأكيد عملية شام كاش. تحقق من بيانات التحويل ثم أعد المحاولة.'
          : 'تعذر إتمام الدفع بطريقة الدفع المختارة. يرجى التحقق من البيانات أو اختيار طريقة أخرى.';
    }

    if (_isRequestValidationFailure(
      code: normalizedCode,
      message: normalizedMessage,
      status: status,
    )) {
      return forShamCashConfirm
          ? 'تعذر تأكيد التحويل بسبب بيانات غير مكتملة. يرجى مراجعة البيانات والمحاولة مجددًا.'
          : 'تعذر إنشاء الطلب بسبب نقص أو خطأ في البيانات. يرجى مراجعة السلة وبيانات الشحن.';
    }

    if (status == 403) {
      return forShamCashConfirm
          ? 'تعذر تأكيد عملية الدفع حالياً بسبب قيود الصلاحية.'
          : 'تعذر تنفيذ الطلب حالياً بسبب قيود الصلاحية.';
    }

    final fallback = ApiContract.extractErrorMessage(
      payload,
      statusCode: status,
    );
    if (fallback.trim().isEmpty || _looksLikeBlockedHtml(fallback)) {
      return forShamCashConfirm
          ? 'تعذر تأكيد عملية الدفع حالياً. يرجى المحاولة لاحقاً.'
          : 'تعذر إنشاء الطلب حالياً. يرجى المحاولة لاحقاً.';
    }
    return fallback;
  }

  bool _isAuthOrderFailure({
    required String code,
    required String message,
    required int status,
  }) {
    if (status == 401) {
      return true;
    }
    if (code.contains('jwt') ||
        code.contains('unauthorized') ||
        code == 'jwt_missing_token' ||
        code == 'jwt_auth_invalid_token') {
      return true;
    }
    return message.contains('authorization') ||
        message.contains('bearer') ||
        message.contains('expired token') ||
        message.contains('invalid token') ||
        message.contains('انتهت صلاحية') ||
        message.contains('رمز الدخول');
  }

  bool _isGuestCheckoutRestriction({
    required String code,
    required String message,
    required int status,
  }) {
    if (code.contains('guest_checkout') || code.contains('guest_not_allowed')) {
      return true;
    }
    if (status != 401 && status != 403) {
      return false;
    }
    return message.contains('guest checkout') ||
        message.contains('login required to checkout') ||
        message.contains('sign in to checkout') ||
        (message.contains('تسجيل الدخول') &&
            (message.contains('الطلب') || message.contains('الدفع')));
  }

  bool _isPermissionOrderFailure({
    required String code,
    required String message,
    required int status,
  }) {
    if (code == 'forbidden_order' ||
        code == 'forbidden_orders' ||
        code == 'forbidden_user_binding') {
      return true;
    }
    if (status != 403) {
      return false;
    }
    return message.contains('cannot create an order for this user') ||
        message.contains('cannot update this order') ||
        message.contains('ليس لديك صلاحية') ||
        message.contains('لا تملك صلاحية');
  }

  bool _isPaymentValidationFailure({
    required String code,
    required String message,
  }) {
    if (code.contains('payment') ||
        code.contains('sham_cash') ||
        code == 'invalid_payment_method') {
      return true;
    }
    return message.contains('payment method') ||
        message.contains('payment gateway') ||
        message.contains('sham cash') ||
        message.contains('transaction') ||
        message.contains('طريقة الدفع') ||
        message.contains('شام كاش');
  }

  bool _isRequestValidationFailure({
    required String code,
    required String message,
    required int status,
  }) {
    if (code == 'invalid_json' ||
        code == 'invalid_params' ||
        code == 'invalid_items' ||
        code == 'customer_not_found') {
      return true;
    }
    if (status != 400 && status != 404 && status != 422) {
      return false;
    }
    return message.contains('required') ||
        message.contains('invalid') ||
        message.contains('missing') ||
        message.contains('غير صالح') ||
        message.contains('مطلوب');
  }

  bool _looksLikeBlockedHtml(dynamic payload) {
    final raw = '${payload ?? ''}'.toLowerCase();
    if (raw.trim().isEmpty) {
      return false;
    }
    return raw.contains('<html') ||
        raw.contains('<!doctype') ||
        raw.contains('<body') ||
        raw.contains('wp-content') ||
        raw.contains('forbidden') ||
        raw.contains('access denied') ||
        raw.contains('mod_security') ||
        raw.contains('cloudflare');
  }

  int? _extractStatusCode(dynamic payload, int? fallback) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final top = map['status'];
      if (top is int) {
        return top;
      }
      if (top is String) {
        final parsed = int.tryParse(top);
        if (parsed != null) {
          return parsed;
        }
      }
      final data = map['data'];
      if (data is Map) {
        final nested = data['status'];
        if (nested is int) {
          return nested;
        }
        if (nested is String) {
          final parsed = int.tryParse(nested);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    return fallback;
  }

  String _extractErrorCode(dynamic payload) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final top = TextSanitizer.fix(map['code']);
      if (top.isNotEmpty) {
        return top;
      }
      final data = map['data'];
      if (data is Map) {
        final nested = TextSanitizer.fix(data['code']);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return '';
  }

  String _extractErrorMessage(dynamic payload) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final message = TextSanitizer.fix(
        map['message'] ?? map['error'] ?? map['detail'],
      );
      if (message.isNotEmpty) {
        return message;
      }
      final data = map['data'];
      if (data is Map) {
        final nested = TextSanitizer.fix(
          data['message'] ?? data['error'] ?? data['detail'],
        );
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return TextSanitizer.fix(payload);
  }

  String _normalizeError(String raw) {
    return raw
        .replaceAll('Exception: ', '')
        .replaceAll('SyncRetryableException: ', '')
        .replaceAll(RegExp(r'^SyncTerminalException\([^)]*\):\s*'), '')
        .trim();
  }

  static String _shamCashIdempotency(int orderId, String transactionId) {
    final tx = transactionId.trim().isEmpty ? 'none' : transactionId.trim();
    return 'sham::$orderId::$tx';
  }

  Options _orderRequestOptions(String orderUuid) {
    // For web builds we skip the custom header because some environments
    // reject it in CORS preflight. Server idempotency still uses order_uuid.
    if (kIsWeb) {
      return Options(headers: const <String, dynamic>{});
    }
    return Options(headers: <String, dynamic>{'X-Idempotency-Key': orderUuid});
  }

  static DateTime _defaultNowUtc() => DateTime.now().toUtc();

  static String _defaultUuidLike() {
    Random rnd;
    try {
      rnd = Random.secure();
    } catch (_) {
      rnd = Random();
    }

    final values = List<int>.generate(32, (_) => rnd.nextInt(16));
    final buffer = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16));
    }
    return buffer.toString();
  }
}
