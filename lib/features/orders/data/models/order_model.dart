import 'package:lpco_llc/core/utils/text_sanitizer.dart';

enum OrderLifecycleState {
  localDraft('local_draft'),
  pendingSync('pending_sync'),
  syncing('syncing'),
  confirmed('confirmed'),
  failedRetryable('failed_retryable'),
  failedTerminal('failed_terminal'),
  staleConflict('stale_conflict'),
  reconciled('reconciled');

  final String value;

  const OrderLifecycleState(this.value);

  static OrderLifecycleState fromRaw(
    String raw, {
    required bool hasServerId,
    required bool isPendingFlag,
    String status = '',
  }) {
    final normalized = TextSanitizer.fix(raw).toLowerCase().trim();
    switch (normalized) {
      case 'local_draft':
        return OrderLifecycleState.localDraft;
      case 'pending_sync':
        return OrderLifecycleState.pendingSync;
      case 'syncing':
        return OrderLifecycleState.syncing;
      case 'confirmed':
        return OrderLifecycleState.confirmed;
      case 'failed_retryable':
        return OrderLifecycleState.failedRetryable;
      case 'failed_terminal':
        return OrderLifecycleState.failedTerminal;
      case 'stale_conflict':
        return OrderLifecycleState.staleConflict;
      case 'reconciled':
        return OrderLifecycleState.reconciled;
    }

    final statusNormalized = TextSanitizer.fix(status).toLowerCase().trim();
    if (statusNormalized == 'pending_sync') {
      return OrderLifecycleState.pendingSync;
    }
    if (statusNormalized == 'syncing') {
      return OrderLifecycleState.syncing;
    }
    if (statusNormalized == 'failed_retryable') {
      return OrderLifecycleState.failedRetryable;
    }
    if (statusNormalized == 'failed_terminal') {
      return OrderLifecycleState.failedTerminal;
    }
    if (statusNormalized == 'stale_conflict') {
      return OrderLifecycleState.staleConflict;
    }
    if (statusNormalized == 'local_draft') {
      return OrderLifecycleState.localDraft;
    }
    if (statusNormalized == 'reconciled') {
      return OrderLifecycleState.reconciled;
    }

    if (isPendingFlag) {
      return OrderLifecycleState.pendingSync;
    }
    return hasServerId
        ? OrderLifecycleState.confirmed
        : OrderLifecycleState.pendingSync;
  }
}

class ShamCashPayload {
  final String company;
  final String account;
  final double amount;
  final int expiry;
  final int timeLimit;
  final String currency;
  final String qrText;
  final String qrUrl;
  final String status;
  final String confirmationEndpoint;

  const ShamCashPayload({
    required this.company,
    required this.account,
    required this.amount,
    required this.expiry,
    required this.timeLimit,
    required this.currency,
    required this.qrText,
    required this.qrUrl,
    required this.status,
    required this.confirmationEndpoint,
  });

  factory ShamCashPayload.fromJson(Map<String, dynamic> json) {
    return ShamCashPayload(
      company: TextSanitizer.fix(json['company']),
      account: TextSanitizer.fix(json['account']),
      amount: double.tryParse('${json['amount'] ?? '0'}') ?? 0,
      expiry: int.tryParse('${json['expiry'] ?? '0'}') ?? 0,
      timeLimit: int.tryParse('${json['time_limit'] ?? '15'}') ?? 15,
      currency: TextSanitizer.fix(json['currency'] ?? 'syp').toLowerCase(),
      qrText: TextSanitizer.fix(json['qr_text'] ?? json['account']),
      qrUrl: TextSanitizer.fix(json['qr_url']),
      status: TextSanitizer.fix(json['status']),
      confirmationEndpoint: TextSanitizer.fix(json['confirmation_endpoint']),
    );
  }
}

class OrderUnitInfo {
  final String type;
  final String name;
  final int? pieces;
  final String price;

  const OrderUnitInfo({
    required this.type,
    required this.name,
    required this.pieces,
    required this.price,
  });

  factory OrderUnitInfo.fromJson(Map<String, dynamic> json) {
    return OrderUnitInfo(
      type: TextSanitizer.fix(json['type']),
      name: TextSanitizer.fix(json['name']),
      pieces: json['pieces'] is int
          ? json['pieces'] as int
          : int.tryParse('${json['pieces'] ?? ''}'),
      price: TextSanitizer.fix(json['price']),
    );
  }
}

class OrderLineItem {
  final int productId;
  final String productName;
  final int? variationId;
  final int quantity;
  final String total;
  final Map<String, String> attributes;
  final String imageUrl;
  final OrderUnitInfo? unit;
  final String warehouseCode;
  final String warehouseLabel;

  const OrderLineItem({
    required this.productId,
    required this.productName,
    required this.variationId,
    required this.quantity,
    required this.total,
    required this.attributes,
    required this.unit,
    required this.imageUrl,
    required this.warehouseCode,
    required this.warehouseLabel,
  });

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['meta_data'] ?? json['meta'];
    final metaMap = <String, dynamic>{};
    if (rawMeta is List) {
      for (final entry in rawMeta.whereType<Map>()) {
        metaMap[TextSanitizer.fix(entry['key']).toLowerCase()] = entry['value'];
      }
    } else if (rawMeta is Map) {
      for (final entry in rawMeta.entries) {
        metaMap[TextSanitizer.fix(entry.key).toLowerCase()] = entry.value;
      }
    }

    final rawAttrs = json['attributes'];
    final attrs = <String, String>{};
    if (rawAttrs is Map) {
      for (final entry in rawAttrs.entries) {
        attrs[TextSanitizer.fix(entry.key)] = TextSanitizer.fix(entry.value);
      }
    }

    final rawUnit = json['unit'];
    var unit = rawUnit is Map
        ? OrderUnitInfo.fromJson(Map<String, dynamic>.from(rawUnit))
        : null;

    if (unit == null) {
      final uName = TextSanitizer.fix(
        json['unit_name'] ??
            json['unit_label'] ??
            metaMap['unit_name'] ??
            metaMap['unit_label'] ??
            metaMap['unit_display_default_ar'] ??
            metaMap['unit'],
      );
      final uType = TextSanitizer.fix(
        json['unit_type'] ??
            metaMap['unit_type'] ??
            metaMap['type'] ??
            metaMap['unit_display_default_ar'],
      );

      if (uName.isNotEmpty || uType.isNotEmpty) {
        unit = OrderUnitInfo(
          type: uType,
          name: uName,
          pieces:
              int.tryParse(
                '${json['unit_multiplier_pieces'] ?? json['unit_pieces'] ?? metaMap['unit_multiplier_pieces'] ?? metaMap['unit_pieces'] ?? metaMap['pieces'] ?? metaMap['pieces_count'] ?? '0'}',
              ) ??
              0,
          price: TextSanitizer.fix(
            '${json['unit_price'] ?? metaMap['unit_price'] ?? ''}',
          ),
        );
      }
    }

    final imageUrl = TextSanitizer.fix(
      json['thumbnail_url'] ??
          json['thumbnail'] ??
          (json['image'] is Map ? (json['image'] as Map)['src'] : null) ??
          metaMap['product_image'] ??
          metaMap['image_url'] ??
          metaMap['thumbnail'] ??
          '',
    );

    final warehouseCode = TextSanitizer.fix(
      json['warehouse_code'] ??
          json['dms_warehouse_code'] ??
          metaMap['warehouse_code'] ??
          metaMap['dms_warehouse_code'] ??
          '',
    );
    final warehouseLabel = TextSanitizer.fix(
      json['warehouse_label'] ??
          json['dms_warehouse_label'] ??
          metaMap['warehouse_label'] ??
          metaMap['dms_warehouse_label'] ??
          '',
    );

    return OrderLineItem(
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse('${json['product_id'] ?? ''}') ?? 0,
      productName: TextSanitizer.fix(
        json['product_name'] ?? json['name'] ?? metaMap['product_name'] ?? '',
      ),
      variationId: json['variation_id'] is int
          ? json['variation_id'] as int
          : int.tryParse('${json['variation_id'] ?? ''}'),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse('${json['quantity'] ?? '0'}') ?? 0,
      total: TextSanitizer.fix('${json['total'] ?? json['subtotal'] ?? '0'}'),
      attributes: attrs,
      unit: unit,
      imageUrl: imageUrl,
      warehouseCode: warehouseCode,
      warehouseLabel: warehouseLabel,
    );
  }
}

class OrderBillingInfo {
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String address;
  final String city;

  const OrderBillingInfo({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
  });

  factory OrderBillingInfo.fromJson(Map<String, dynamic> json) {
    return OrderBillingInfo(
      firstName: TextSanitizer.fix(json['first_name']),
      lastName: TextSanitizer.fix(json['last_name']),
      phone: TextSanitizer.fix(json['phone']),
      email: TextSanitizer.fix(json['email']),
      address: TextSanitizer.fix(json['address']),
      city: TextSanitizer.fix(json['city']),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String total;
  final String currency;
  final String date;
  final String paymentMethod;
  final String invoiceUrl;
  final ShamCashPayload? shamCash;
  final List<OrderLineItem> lineItems;
  final OrderBillingInfo? billing;
  final bool isPendingSync;
  final String localQueueId;
  final String idempotencyKey;
  final OrderLifecycleState lifecycleState;
  final DateTime? createdLocallyAt;
  final DateTime? enqueuedAt;
  final DateTime? lastSyncAttemptAt;
  final DateTime? confirmedAt;
  final DateTime? conflictDetectedAt;
  final int retryCount;
  final String syncError;
  final String warehouseCode;
  final String warehouseLabel;
  final List<String> warehouseCodes;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.date,
    required this.paymentMethod,
    required this.invoiceUrl,
    required this.shamCash,
    required this.lineItems,
    required this.billing,
    required this.isPendingSync,
    required this.localQueueId,
    required this.idempotencyKey,
    required this.lifecycleState,
    required this.createdLocallyAt,
    required this.enqueuedAt,
    required this.lastSyncAttemptAt,
    required this.confirmedAt,
    required this.conflictDetectedAt,
    required this.retryCount,
    required this.syncError,
    required this.warehouseCode,
    required this.warehouseLabel,
    required this.warehouseCodes,
  });

  factory OrderModel.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> json = raw;
    if (_shouldUnwrapNestedOrder(raw)) {
      if (raw.containsKey('order') && raw['order'] is Map) {
        json = Map<String, dynamic>.from(raw['order'] as Map);
      } else if (raw.containsKey('data') && raw['data'] is Map) {
        json = Map<String, dynamic>.from(raw['data'] as Map);
      }
    }

    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse('${json['id'] ?? ''}') ?? 0;

    final shamCashRaw = json['sham_cash'];
    final shamCash = shamCashRaw is Map
        ? ShamCashPayload.fromJson(Map<String, dynamic>.from(shamCashRaw))
        : null;
    final rawLineItems = json['line_items'] ?? json['items'];
    final lineItemsSource = rawLineItems is List
        ? rawLineItems
        : rawLineItems is Map
        ? rawLineItems.values.toList()
        : const <dynamic>[];
    final lineItems = lineItemsSource
        .whereType<Map>()
        .map((e) => OrderLineItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final rawBilling = json['billing'];
    final billing = rawBilling is Map
        ? OrderBillingInfo.fromJson(Map<String, dynamic>.from(rawBilling))
        : null;
    final status = TextSanitizer.fix(json['status']).toLowerCase();
    final pendingFlag =
        json['is_pending_sync'] == true || status == 'pending_sync';
    final hasServerId = id > 0;
    final lifecycle = OrderLifecycleState.fromRaw(
      '${json['lifecycle_state'] ?? json['local_state'] ?? ''}',
      hasServerId: hasServerId,
      isPendingFlag: pendingFlag,
      status: status,
    );

    return OrderModel(
      id: id,
      orderNumber: TextSanitizer.fix(
        json['order_number'] ?? json['number'] ?? id.toString(),
      ),
      status: status,
      total: TextSanitizer.fix(json['total'] ?? '0'),
      currency: TextSanitizer.fix(json['currency'] ?? 'syp').toLowerCase(),
      date: TextSanitizer.fix(
        json['date'] ??
            json['date_created'] ??
            json['created_at'] ??
            json['date_created_gmt'] ??
            '',
      ),
      paymentMethod: TextSanitizer.fix(
        json['payment_method_title'] ??
            json['payment_method'] ??
            json['payment_title'] ??
            '',
      ),
      invoiceUrl: TextSanitizer.fix(
        json['invoice_url'] ?? json['invoice'] ?? json['pdf_invoice_url'] ?? '',
      ),
      shamCash: shamCash,
      lineItems: lineItems,
      billing: billing,
      isPendingSync:
          lifecycle == OrderLifecycleState.pendingSync ||
          lifecycle == OrderLifecycleState.syncing ||
          lifecycle == OrderLifecycleState.failedRetryable ||
          lifecycle == OrderLifecycleState.localDraft,
      localQueueId: TextSanitizer.fix(json['local_queue_id']),
      idempotencyKey: TextSanitizer.fix(
        json['idempotency_key'] ?? json['order_uuid'] ?? json['order_uid'],
      ),
      lifecycleState: lifecycle,
      createdLocallyAt: _parseDate(
        json['created_locally_at'] ?? json['local_created_at'],
      ),
      enqueuedAt: _parseDate(json['enqueued_at']),
      lastSyncAttemptAt: _parseDate(json['last_sync_attempt_at']),
      confirmedAt: _parseDate(json['confirmed_at']),
      conflictDetectedAt: _parseDate(json['conflict_detected_at']),
      retryCount: json['retry_count'] is int
          ? json['retry_count'] as int
          : int.tryParse('${json['retry_count'] ?? '0'}') ?? 0,
      syncError: TextSanitizer.fix(json['sync_error']),
      warehouseCode: TextSanitizer.fix(json['warehouse_code']),
      warehouseLabel: TextSanitizer.fix(json['warehouse_label']),
      warehouseCodes:
          ((json['warehouse_codes'] as List?) ?? const <dynamic>[])
              .map((entry) => TextSanitizer.fix(entry))
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false),
    );
  }

  bool get isConfirmedServerSide =>
      (lifecycleState == OrderLifecycleState.confirmed ||
          lifecycleState == OrderLifecycleState.reconciled) &&
      id > 0;

  bool get hasSyncConflict =>
      lifecycleState == OrderLifecycleState.staleConflict;

  bool get hasRetryableFailure =>
      lifecycleState == OrderLifecycleState.failedRetryable;

  bool get hasTerminalFailure =>
      lifecycleState == OrderLifecycleState.failedTerminal;

  static DateTime? _parseDate(dynamic raw) {
    final value = TextSanitizer.fix(raw);
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static bool _shouldUnwrapNestedOrder(Map<String, dynamic> raw) {
    final hasTopLevelNormalizedKeys =
        raw['line_items'] != null ||
        raw['items'] != null ||
        raw['billing'] != null ||
        raw['lifecycle_state'] != null ||
        raw['is_pending_sync'] != null ||
        raw['sync_error'] != null;
    if (hasTopLevelNormalizedKeys) {
      return false;
    }

    return (raw['order'] is Map) || (raw['data'] is Map);
  }
}
