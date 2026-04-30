import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

class OrderResponseNormalizer {
  List<Map<String, dynamic>> normalizeOrderListResponse(
    dynamic payload, {
    required String endpoint,
    required String fallbackCurrency,
  }) {
    final list = ApiContract.expectList(
      payload,
      endpoint: endpoint,
      envelopeKeys: const <String>['orders', 'data', 'items'],
    );

    return list
        .whereType<Map>()
        .map(
          (entry) => normalizeOrderMap(
            _extractPrimaryOrderMap(Map<String, dynamic>.from(entry)),
            fallbackCurrency: fallbackCurrency,
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> normalizeCreateOrderResponse(
    dynamic payload, {
    required String fallbackCurrency,
    required String fallbackOrderUuid,
  }) {
    final envelope = ApiContract.expectMap(payload, endpoint: '/dms/v1/orders');
    final source = _extractPrimaryOrderMap(envelope);
    final normalized = normalizeOrderMap(
      source,
      fallbackCurrency: fallbackCurrency,
      fallbackOrderUuid: fallbackOrderUuid,
      lifecycleOverride: OrderLifecycleState.confirmed,
      confirmedAt: DateTime.now().toUtc(),
    );

    final idFromEnvelope = _toInt(envelope['order_id']);
    if ((normalized['id'] as int) <= 0 && idFromEnvelope > 0) {
      normalized['id'] = idFromEnvelope;
      normalized['order_number'] =
          TextSanitizer.fix(
            normalized['order_number'] ?? '$idFromEnvelope',
          ).isNotEmpty
          ? normalized['order_number']
          : '$idFromEnvelope';
    }

    if ((normalized['id'] as int) <= 0) {
      throw ApiContractException(
        const ApiFailure(
          code: 'invalid_order_create_response',
          message: 'استجابة إنشاء الطلب لا تحتوي معرف طلب صالح.',
          status: 500,
          endpoint: '/dms/v1/orders',
        ),
      );
    }

    normalized['message'] = TextSanitizer.fix(
      envelope['message'] ?? envelope['detail'] ?? normalized['message'],
    );
    final duplicateProtected = envelope['duplicate_protected'];
    normalized['duplicate_protected'] = duplicateProtected is bool
        ? duplicateProtected
        : envelope['idempotent_reused'] == true ||
              envelope['already_exists'] == true;
    final reusedExisting = envelope['reused_existing'];
    normalized['reused_existing'] = reusedExisting is bool
        ? reusedExisting
        : envelope['existing_order'] != null ||
              envelope['existing_order_id'] != null;

    return normalized;
  }

  Map<String, dynamic> normalizeOrderDetailsResponse(
    dynamic payload, {
    required String fallbackCurrency,
  }) {
    final envelope = ApiContract.expectMap(
      payload,
      endpoint: '/dms/v1/orders/details',
    );
    return normalizeOrderMap(
      _extractPrimaryOrderMap(envelope),
      fallbackCurrency: fallbackCurrency,
    );
  }

  Map<String, dynamic> normalizeShamCashConfirmationResponse(
    dynamic payload, {
    required int fallbackOrderId,
    required String fallbackCurrency,
  }) {
    final envelope = ApiContract.expectMap(
      payload,
      endpoint: '/dms/v1/orders/{id}/sham-cash-confirm',
    );
    final source = _extractPrimaryOrderMap(envelope);
    final normalized = normalizeOrderMap(
      source,
      fallbackCurrency: fallbackCurrency,
      lifecycleOverride: OrderLifecycleState.confirmed,
      confirmedAt: DateTime.now().toUtc(),
    );
    if ((normalized['id'] as int) <= 0) {
      normalized['id'] = fallbackOrderId;
      normalized['order_number'] =
          TextSanitizer.fix(normalized['order_number']).isEmpty
          ? '$fallbackOrderId'
          : normalized['order_number'];
    }
    return normalized;
  }

  Map<String, dynamic> _extractPrimaryOrderMap(Map<String, dynamic> envelope) {
    final result = Map<String, dynamic>.from(envelope);

    final nestedKeys = ['order', 'data', 'result', 'payload', 'item'];
    for (final key in nestedKeys) {
      final nested = envelope[key];
      if (nested is Map) {
        nested.forEach((k, v) {
          final existing = result[k];
          if (_shouldAdoptNestedValue(k, existing, v)) {
            result[k] = v;
          }
        });
      }
    }

    return result;
  }

  Map<String, dynamic> normalizeOrderMap(
    Map<String, dynamic> raw, {
    required String fallbackCurrency,
    String fallbackOrderUuid = '',
    OrderLifecycleState? lifecycleOverride,
    String localQueueId = '',
    bool? isPendingSync,
    DateTime? createdLocallyAt,
    DateTime? enqueuedAt,
    DateTime? lastSyncAttemptAt,
    DateTime? confirmedAt,
    DateTime? conflictDetectedAt,
    int retryCount = 0,
    String syncError = '',
  }) {
    final normalized = Map<String, dynamic>.from(raw);
    final id = _toInt(normalized['id']);
    final status = TextSanitizer.fix(normalized['status']).toLowerCase();
    final orderNumber = TextSanitizer.fix(
      normalized['order_number'] ?? normalized['number'] ?? '$id',
    );
    final currency = TextSanitizer.fix(
      normalized['currency'] ?? fallbackCurrency,
    ).toLowerCase();
    final lineItems = _normalizeLineItems(_resolveRawLineItems(normalized));
    final billing = _normalizeBilling(
      _resolveRawBilling(normalized),
      _resolveRawShipping(normalized),
    );
    final shamCash = _normalizeShamCash(normalized['sham_cash']);
    final orderUuid = _extractOrderUuid(normalized).isNotEmpty
        ? _extractOrderUuid(normalized)
        : fallbackOrderUuid.trim();
    final pending =
        isPendingSync ??
        normalized['is_pending_sync'] == true || status == 'pending_sync';

    final lifecycle =
        lifecycleOverride ??
        OrderLifecycleState.fromRaw(
          '${normalized['lifecycle_state'] ?? ''}',
          hasServerId: id > 0,
          isPendingFlag: pending,
          status: status,
        );

    return <String, dynamic>{
      ...normalized,
      'id': id,
      'order_number': orderNumber.isEmpty ? '$id' : orderNumber,
      'status': status,
      'total': _toNumString(normalized['total'] ?? normalized['amount'] ?? 0),
      'currency': currency.isEmpty ? 'syp' : currency,
      'date': _normalizeDateString(_resolveRawDate(normalized)),
      'payment_method': _extractPaymentMethod(normalized),
      'invoice_url': TextSanitizer.fix(
        normalized['invoice_url'] ?? normalized['invoice'],
      ),
      'line_items': lineItems,
      'billing': billing,
      'sham_cash': shamCash,
      'order_uuid': orderUuid,
      'idempotency_key': orderUuid,
      'local_queue_id': TextSanitizer.fix(
        normalized['local_queue_id'] ?? localQueueId,
      ),
      'is_pending_sync':
          lifecycle == OrderLifecycleState.pendingSync ||
          lifecycle == OrderLifecycleState.syncing ||
          lifecycle == OrderLifecycleState.failedRetryable ||
          lifecycle == OrderLifecycleState.localDraft,
      'lifecycle_state': lifecycle.value,
      'created_locally_at':
          _dateToIso(createdLocallyAt) ??
          _normalizeDateString(normalized['created_locally_at']),
      'enqueued_at':
          _dateToIso(enqueuedAt) ??
          _normalizeDateString(normalized['enqueued_at']),
      'last_sync_attempt_at':
          _dateToIso(lastSyncAttemptAt) ??
          _normalizeDateString(normalized['last_sync_attempt_at']),
      'confirmed_at':
          _dateToIso(confirmedAt) ??
          _normalizeDateString(normalized['confirmed_at']),
      'conflict_detected_at':
          _dateToIso(conflictDetectedAt) ??
          _normalizeDateString(normalized['conflict_detected_at']),
      'retry_count': _toInt(normalized['retry_count'], fallback: retryCount),
      'sync_error': TextSanitizer.fix(normalized['sync_error'] ?? syncError),
    };
  }

  bool _shouldAdoptNestedValue(
    dynamic key,
    dynamic existing,
    dynamic incoming,
  ) {
    if (existing == null) {
      return true;
    }

    final normalizedKey = TextSanitizer.fix(key).toLowerCase();
    if (normalizedKey.isEmpty) {
      return false;
    }

    const collectionKeys = <String>{
      'line_items',
      'items',
      'order_items',
      'products',
    };
    if (collectionKeys.contains(normalizedKey)) {
      final existingHasData = _hasCollectionData(existing);
      final incomingHasData = _hasCollectionData(incoming);
      return !existingHasData && incomingHasData;
    }

    const mapKeys = <String>{'billing', 'shipping', 'sham_cash'};
    if (mapKeys.contains(normalizedKey)) {
      final existingHasData = existing is Map && existing.isNotEmpty;
      final incomingHasData = incoming is Map && incoming.isNotEmpty;
      return !existingHasData && incomingHasData;
    }

    const textKeys = <String>{
      'date',
      'date_created',
      'created_at',
      'payment_method',
      'payment_method_title',
      'order_number',
      'number',
    };
    if (textKeys.contains(normalizedKey)) {
      return TextSanitizer.fix(existing).isEmpty &&
          TextSanitizer.fix(incoming).isNotEmpty;
    }

    return false;
  }

  dynamic _resolveRawLineItems(Map<String, dynamic> normalized) {
    final details = normalized['details'];
    final orderData = normalized['order'];
    final dataData = normalized['data'];

    final candidates = <dynamic>[
      normalized['line_items'],
      normalized['items'],
      normalized['order_items'],
      normalized['products'],
      details is Map ? details['line_items'] : null,
      details is Map ? details['items'] : null,
      details is Map ? details['products'] : null,
      orderData is Map ? orderData['line_items'] : null,
      orderData is Map ? orderData['items'] : null,
      dataData is Map ? dataData['line_items'] : null,
      dataData is Map ? dataData['items'] : null,
    ];

    return _firstCollectionCandidate(candidates);
  }

  dynamic _resolveRawBilling(Map<String, dynamic> normalized) {
    final details = normalized['details'];
    final orderData = normalized['order'];
    final dataData = normalized['data'];

    return _firstMapCandidate(<dynamic>[
      normalized['billing'],
      details is Map ? details['billing'] : null,
      orderData is Map ? orderData['billing'] : null,
      dataData is Map ? dataData['billing'] : null,
    ]);
  }

  dynamic _resolveRawShipping(Map<String, dynamic> normalized) {
    final details = normalized['details'];
    final orderData = normalized['order'];
    final dataData = normalized['data'];

    return _firstMapCandidate(<dynamic>[
      normalized['shipping'],
      details is Map ? details['shipping'] : null,
      orderData is Map ? orderData['shipping'] : null,
      dataData is Map ? dataData['shipping'] : null,
    ]);
  }

  dynamic _resolveRawDate(Map<String, dynamic> normalized) {
    final details = normalized['details'];
    final orderData = normalized['order'];
    final dataData = normalized['data'];

    return _firstTextCandidate(<dynamic>[
      normalized['date'],
      normalized['date_created'],
      normalized['created_at'],
      normalized['date_created_gmt'],
      normalized['confirmed_at'],
      details is Map ? details['date'] : null,
      details is Map ? details['date_created'] : null,
      orderData is Map ? orderData['date'] : null,
      orderData is Map ? orderData['date_created'] : null,
      dataData is Map ? dataData['date'] : null,
      dataData is Map ? dataData['date_created'] : null,
    ]);
  }

  String _extractPaymentMethod(Map<String, dynamic> normalized) {
    final rawPayment =
        normalized['payment_method'] ?? normalized['payment_method_title'];
    if (rawPayment is Map) {
      return TextSanitizer.fix(
        rawPayment['title'] ??
            rawPayment['name'] ??
            rawPayment['label'] ??
            rawPayment['id'] ??
            rawPayment['code'],
      );
    }
    return TextSanitizer.fix(rawPayment);
  }

  String extractOrderUuidFromOrder(Map<String, dynamic> order) {
    return _extractOrderUuid(order);
  }

  String _extractOrderUuid(Map<String, dynamic> map) {
    final direct = TextSanitizer.fix(
      map['order_uuid'] ?? map['idempotency_key'] ?? map['order_uid'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }

    final meta = _extractMetaMap(map['meta_data'] ?? map['meta']);
    final fromMeta = TextSanitizer.fix(
      meta['order_uuid'] ?? meta['idempotency_key'] ?? meta['order_uid'],
    );
    return fromMeta;
  }

  List<Map<String, dynamic>> _normalizeLineItems(dynamic rawLineItems) {
    final source = _toCollectionList(rawLineItems);

    return source
        .whereType<Map>()
        .map((rawItem) {
          final item = Map<String, dynamic>.from(rawItem);
          final meta = _extractMetaMap(item['meta_data'] ?? item['meta']);
          final attributes = _normalizeAttributes(item['attributes'], meta);

          final quantity = _toInt(item['quantity'], fallback: 0);
          final unitPrice = _toNumString(
            item['unit_price'] ??
                meta['unit_price'] ??
                (quantity > 0 ? (_toNum(item['total']) / quantity) : 0),
          );

          // Robust unit parsing
          Map<String, dynamic> unit;
          final rawUnit = item['unit'];
          if (rawUnit is Map) {
            unit = Map<String, dynamic>.from(rawUnit);
          } else {
            unit = <String, dynamic>{};
          }

          unit['type'] = TextSanitizer.fix(
            unit['type'] ??
                item['unit_type'] ??
                meta['unit_type'] ??
                meta['unit_display_default_ar'],
          );

          unit['name'] = TextSanitizer.fix(
            unit['name'] ??
                unit['label'] ??
                item['unit_name'] ??
                item['unit_label'] ??
                meta['unit_name'] ??
                meta['unit_label'] ??
                meta['unit_display_default_ar'],
          );

          unit['pieces'] = _toInt(
            unit['pieces'] ??
                item['unit_multiplier_pieces'] ??
                item['unit_pieces'] ??
                meta['unit_multiplier_pieces'] ??
                meta['unit_pieces'] ??
                meta['pieces_count'],
            fallback: 0,
          );

          unit['price'] = unit['price'] ?? unitPrice;

          // Robust image parsing
          final imageUrl = TextSanitizer.fix(
            item['image_url'] ??
                item['imageUrl'] ??
                (item['image'] is Map ? (item['image'] as Map)['src'] : null) ??
                item['product_image'] ??
                item['thumbnail'] ??
                meta['product_image'] ??
                meta['thumbnail'],
          );

          return <String, dynamic>{
            'product_id': _toInt(item['product_id'] ?? item['id']),
            'product_name': TextSanitizer.fix(
              item['product_name'] ?? item['name'] ?? item['title'],
            ),
            'variation_id': _toNullableInt(item['variation_id']),
            'quantity': quantity,
            'total': _toNumString(item['total']),
            'attributes': attributes,
            'unit': unit,
            'unit_type': unit['type'],
            'unit_price': unitPrice,
            'image_url': imageUrl,
            'imageUrl': imageUrl,
          };
        })
        .toList(growable: false);
  }

  List<dynamic> _toCollectionList(dynamic value) {
    if (value is List) {
      return value;
    }
    if (value is Map) {
      if (value['data'] is List) {
        return value['data'] as List;
      }
      if (value['items'] is List) {
        return value['items'] as List;
      }
      if (value['line_items'] is List) {
        return value['line_items'] as List;
      }
      if (value['products'] is List) {
        return value['products'] as List;
      }
      return value.values.toList();
    }
    return const <dynamic>[];
  }

  Map<String, dynamic>? _normalizeBilling(
    dynamic rawBilling,
    dynamic rawShipping,
  ) {
    final source = rawBilling is Map
        ? Map<String, dynamic>.from(rawBilling)
        : rawShipping is Map
        ? Map<String, dynamic>.from(rawShipping)
        : null;
    if (source == null) {
      return null;
    }

    return <String, dynamic>{
      'first_name': TextSanitizer.fix(source['first_name']),
      'last_name': TextSanitizer.fix(source['last_name']),
      'phone': TextSanitizer.fix(source['phone']),
      'email': TextSanitizer.fix(source['email']),
      'address': TextSanitizer.fix(source['address'] ?? source['address_1']),
      'city': TextSanitizer.fix(source['city']),
    };
  }

  Map<String, dynamic>? _normalizeShamCash(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    return <String, dynamic>{
      ...map,
      'currency': TextSanitizer.fix(map['currency'] ?? 'syp').toLowerCase(),
      'qr_text': TextSanitizer.fix(map['qr_text'] ?? map['account']),
      'qr_url': TextSanitizer.fix(map['qr_url']),
      'confirmation_endpoint': TextSanitizer.fix(map['confirmation_endpoint']),
    };
  }

  Map<String, String> _normalizeAttributes(
    dynamic rawAttrs,
    Map<String, dynamic> meta,
  ) {
    final attrs = <String, String>{};
    if (rawAttrs is Map) {
      for (final entry in rawAttrs.entries) {
        final key = TextSanitizer.fix(entry.key);
        final value = TextSanitizer.fix(entry.value);
        if (key.isNotEmpty && value.isNotEmpty) {
          attrs[key] = value;
        }
      }
    }

    for (final entry in meta.entries) {
      final key = entry.key.trim();
      if (!key.startsWith('attribute_')) {
        continue;
      }
      final attrKey = key.substring('attribute_'.length).trim();
      if (attrKey.isEmpty) {
        continue;
      }
      final attrValue = TextSanitizer.fix(entry.value);
      if (attrValue.isEmpty) {
        continue;
      }
      attrs[attrKey] = attrValue;
    }

    return attrs;
  }

  Map<String, dynamic> _extractMetaMap(dynamic rawMeta) {
    final map = <String, dynamic>{};
    if (rawMeta is Map) {
      for (final entry in rawMeta.entries) {
        final key = TextSanitizer.fix(entry.key).toLowerCase();
        if (key.isEmpty) {
          continue;
        }
        map[key] = entry.value;
      }
      return map;
    }

    if (rawMeta is List) {
      for (final entry in rawMeta.whereType<Map>()) {
        final key = TextSanitizer.fix(entry['key']).toLowerCase();
        if (key.isEmpty) {
          continue;
        }
        map[key] = entry['value'];
      }
    }
    return map;
  }

  String _normalizeDateString(dynamic raw) {
    final value = TextSanitizer.fix(raw);
    if (value.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    return parsed.toUtc().toIso8601String();
  }

  bool _hasCollectionData(dynamic value) {
    if (value is List) {
      return value.isNotEmpty;
    }
    if (value is Map) {
      if (value['data'] is List) {
        return (value['data'] as List).isNotEmpty;
      }
      if (value['items'] is List) {
        return (value['items'] as List).isNotEmpty;
      }
      if (value['line_items'] is List) {
        return (value['line_items'] as List).isNotEmpty;
      }
      if (value['products'] is List) {
        return (value['products'] as List).isNotEmpty;
      }
      return value.isNotEmpty;
    }
    return false;
  }

  dynamic _firstCollectionCandidate(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (_hasCollectionData(candidate)) {
        return candidate;
      }
    }
    for (final candidate in candidates) {
      if (candidate is List || candidate is Map) {
        return candidate;
      }
    }
    return null;
  }

  dynamic _firstMapCandidate(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is Map && candidate.isNotEmpty) {
        return candidate;
      }
    }
    for (final candidate in candidates) {
      if (candidate is Map) {
        return candidate;
      }
    }
    return null;
  }

  dynamic _firstTextCandidate(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (TextSanitizer.fix(candidate).isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? _dateToIso(DateTime? date) {
    return date?.toUtc().toIso8601String();
  }

  int _toInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse('${raw ?? ''}') ?? fallback;
  }

  int? _toNullableInt(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    return int.tryParse('$raw');
  }

  num _toNum(dynamic raw) {
    if (raw is num) {
      return raw;
    }
    return num.tryParse('${raw ?? '0'}') ?? 0;
  }

  String _toNumString(dynamic raw) {
    final value = _toNum(raw);
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
