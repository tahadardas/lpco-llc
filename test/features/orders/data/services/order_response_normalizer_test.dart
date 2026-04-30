import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/data/services/order_response_normalizer.dart';

void main() {
  group('OrderResponseNormalizer', () {
    final normalizer = OrderResponseNormalizer();

    test('normalizes wrapped order list and extracts order_uuid from meta', () {
      final payload = <String, dynamic>{
        'orders': [
          <String, dynamic>{
            'id': 120,
            'number': '120',
            'status': 'processing',
            'currency': 'SYP',
            'line_items': [
              <String, dynamic>{
                'product_id': 8,
                'name': 'Notebook',
                'quantity': 2,
                'total': '2000',
                'meta_data': [
                  <String, dynamic>{'key': 'unit_type', 'value': 'piece'},
                  <String, dynamic>{'key': 'unit_price', 'value': '1000'},
                ],
              },
            ],
            'meta_data': [
              <String, dynamic>{'key': 'order_uuid', 'value': 'uuid-120'},
            ],
          },
        ],
      };

      final normalized = normalizer.normalizeOrderListResponse(
        payload,
        endpoint: '/dms/v1/user/1/orders',
        fallbackCurrency: 'syp',
      );

      expect(normalized, hasLength(1));
      expect(normalized.first['id'], 120);
      expect(normalized.first['currency'], 'syp');
      expect(normalized.first['order_uuid'], 'uuid-120');
      expect(
        normalized.first['lifecycle_state'],
        OrderLifecycleState.confirmed.value,
      );
      expect(normalized.first['is_pending_sync'], isFalse);
    });

    test(
      'normalizes create response from order envelope and preserves message flags',
      () {
        final payload = <String, dynamic>{
          'message': 'Order already created using same idempotency key',
          'reused_existing': true,
          'order': <String, dynamic>{
            'id': 500,
            'order_number': '500',
            'status': 'pending',
            'currency': 'USD',
            'meta_data': [
              <String, dynamic>{'key': 'order_uuid', 'value': 'uuid-500'},
            ],
          },
        };

        final normalized = normalizer.normalizeCreateOrderResponse(
          payload,
          fallbackCurrency: 'syp',
          fallbackOrderUuid: 'fallback-uuid',
        );

        expect(normalized['id'], 500);
        expect(normalized['order_uuid'], 'uuid-500');
        expect(normalized['message'], contains('idempotency'));
        expect(normalized['reused_existing'], isTrue);
        expect(
          normalized['lifecycle_state'],
          OrderLifecycleState.confirmed.value,
        );
        expect(normalized['confirmed_at'], isNotEmpty);
      },
    );

    test(
      'prefers explicit duplicate flags over legacy existing order markers',
      () {
        final payload = <String, dynamic>{
          'message': 'Order created successfully',
          'duplicate_protected': false,
          'reused_existing': false,
          'existing_order_id': 777,
          'order': <String, dynamic>{
            'id': 501,
            'order_number': '501',
            'status': 'pending',
            'currency': 'SYP',
            'order_uuid': 'uuid-501',
          },
        };

        final normalized = normalizer.normalizeCreateOrderResponse(
          payload,
          fallbackCurrency: 'syp',
          fallbackOrderUuid: 'fallback-uuid',
        );

        expect(normalized['id'], 501);
        expect(normalized['order_uuid'], 'uuid-501');
        expect(normalized['duplicate_protected'], isFalse);
        expect(normalized['reused_existing'], isFalse);
      },
    );

    test(
      'throws ApiContractException when create response has no valid order id',
      () {
        final payload = <String, dynamic>{
          'message': 'ok',
          'order': <String, dynamic>{'status': 'processing', 'currency': 'syp'},
        };

        expect(
          () => normalizer.normalizeCreateOrderResponse(
            payload,
            fallbackCurrency: 'syp',
            fallbackOrderUuid: 'uuid-x',
          ),
          throwsA(isA<ApiContractException>()),
        );
      },
    );

    test('normalizes details response envelope', () {
      final payload = <String, dynamic>{
        'data': <String, dynamic>{
          'id': 77,
          'order_number': '77',
          'status': 'completed',
          'currency': 'SYP',
        },
      };

      final normalized = normalizer.normalizeOrderDetailsResponse(
        payload,
        fallbackCurrency: 'syp',
      );

      expect(normalized['id'], 77);
      expect(normalized['currency'], 'syp');
      expect(normalized['status'], 'completed');
    });

    test(
      'normalizes list entry when details are nested and root line_items is empty',
      () {
        final payload = <String, dynamic>{
          'orders': [
            <String, dynamic>{
              'id': 23521,
              'order_number': '23521#',
              'status': 'pending',
              'currency': 'SYP',
              'line_items': <dynamic>[],
              'date': '',
              'order': <String, dynamic>{
                'date_created': '2026-03-13 10:15:00',
                'line_items': [
                  <String, dynamic>{
                    'product_id': 90,
                    'product_name': 'Oil Filter',
                    'quantity': 3,
                    'total': '19521',
                    'unit': <String, dynamic>{
                      'type': 'box',
                      'name': 'علبة',
                      'pieces': 12,
                    },
                  },
                ],
                'billing': <String, dynamic>{
                  'first_name': 'Ali',
                  'last_name': 'K.',
                  'phone': '0999999999',
                  'address': 'Damascus',
                  'city': 'Damascus',
                },
              },
            },
          ],
        };

        final normalized = normalizer.normalizeOrderListResponse(
          payload,
          endpoint: '/dms/v1/user/1/orders',
          fallbackCurrency: 'syp',
        );

        expect(normalized, hasLength(1));
        expect(normalized.first['id'], 23521);
        expect((normalized.first['line_items'] as List), isNotEmpty);
        expect((normalized.first['date'] as String), isNotEmpty);
        expect(normalized.first['billing'], isNotNull);
      },
    );

    test('falls back to items list when line_items exists but is empty', () {
      final normalized = normalizer.normalizeOrderMap(<String, dynamic>{
        'id': 44,
        'status': 'processing',
        'currency': 'syp',
        'line_items': <dynamic>[],
        'items': [
          <String, dynamic>{
            'product_id': 7,
            'name': 'Brake Pads',
            'quantity': 1,
            'total': '5000',
          },
        ],
      }, fallbackCurrency: 'syp');

      expect((normalized['line_items'] as List), hasLength(1));
    });
  });
}
