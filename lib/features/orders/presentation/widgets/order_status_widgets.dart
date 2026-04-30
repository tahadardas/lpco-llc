import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/presentation/utils/order_lifecycle_presenter.dart';

class OrderLifecycleBadge extends StatelessWidget {
  final OrderLifecyclePresentation lifecycle;

  const OrderLifecycleBadge({super.key, required this.lifecycle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lifecycle.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lifecycle.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(lifecycle.icon, size: 14, color: lifecycle.color),
          const SizedBox(width: 4),
          Text(
            lifecycle.label,
            style: TextStyle(
              color: lifecycle.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderLifecyclePanel extends StatelessWidget {
  final OrderLifecyclePresentation lifecycle;
  final String? errorMessage;

  const OrderLifecyclePanel({
    super.key,
    required this.lifecycle,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMessage = (errorMessage ?? '').trim().isNotEmpty
        ? errorMessage!.trim()
        : lifecycle.description;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lifecycle.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lifecycle.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(lifecycle.icon, color: lifecycle.color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lifecycle.label,
                  style: TextStyle(
                    color: lifecycle.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  effectiveMessage,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderSyncMeta extends StatelessWidget {
  final OrderModel order;

  const OrderSyncMeta({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _metaRow('أنشئ محلياً', _formatDate(order.createdLocallyAt)),
      _metaRow('أضيف للطابور', _formatDate(order.enqueuedAt)),
      _metaRow('آخر محاولة مزامنة', _formatDate(order.lastSyncAttemptAt)),
      _metaRow('تأكيد الخادم', _formatDate(order.confirmedAt)),
      _metaRow('وقت التعارض', _formatDate(order.conflictDetectedAt)),
      _metaRow('عدد محاولات المزامنة', '${order.retryCount}'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('yyyy/MM/dd - HH:mm').format(date.toLocal());
  }
}
