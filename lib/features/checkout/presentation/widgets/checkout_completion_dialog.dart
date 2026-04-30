import 'package:flutter/material.dart';

import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/presentation/utils/order_lifecycle_presenter.dart';

enum CheckoutCompletionAction { viewOrder, home }

Future<CheckoutCompletionAction?> showCheckoutCompletionDialog({
  required BuildContext context,
  required OrderModel order,
  required bool isQueuedOrder,
  required bool reusedExisting,
  required bool awaitingShamCashConfirmation,
  required String orderReference,
}) async {
  final lifecycle = presentOrderLifecycle(order);
  final statusText = order.isConfirmedServerSide
      ? presentServerOrderStatus(order.status)
      : lifecycle.label;

  final headline = reusedExisting
      ? 'تم العثور على طلب سابق'
      : isQueuedOrder
      ? 'تم حفظ الطلب محلياً'
      : 'تم إنشاء الطلب بنجاح';

  final description = reusedExisting
      ? 'وجدنا طلباً مطابقاً سابقاً وتم ربطه بحسابك.'
      : isQueuedOrder
      ? 'طلبك محفوظ وسيتم إرساله تلقائياً عند عودة الاتصال.'
      : awaitingShamCashConfirmation
      ? 'تم إنشاء الطلب وبانتظار تأكيد تحويل شام كاش.'
      : 'يمكنك متابعة حالة الطلب الآن من شاشة الطلبات.';

  return showDialog<CheckoutCompletionAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              isQueuedOrder
                  ? Icons.schedule_send_rounded
                  : Icons.check_circle_rounded,
              color: isQueuedOrder
                  ? const Color(0xFFB45309)
                  : const Color(0xFF0E9F6E),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(headline)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 10),
            Text(
              'رقم الطلب: $orderReference',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'حالة الطلب: $statusText',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(CheckoutCompletionAction.home),
            child: const Text('العودة للرئيسية'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CheckoutCompletionAction.viewOrder),
            child: const Text('عرض الطلب'),
          ),
        ],
      );
    },
  );
}
