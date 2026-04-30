import 'package:flutter/material.dart';

import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';

class OrderLifecyclePresentation {
  final String label;
  final String description;
  final Color color;
  final IconData icon;
  final bool canDownloadInvoice;
  final bool requiresAttention;

  const OrderLifecyclePresentation({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
    required this.canDownloadInvoice,
    required this.requiresAttention,
  });
}

OrderLifecyclePresentation presentOrderLifecycle(OrderModel order) {
  switch (order.lifecycleState) {
    case OrderLifecycleState.localDraft:
      return const OrderLifecyclePresentation(
        label: 'مسودة محلية',
        description: 'لم يتم وضع الطلب في طابور المزامنة بعد.',
        color: Color(0xFF6B7280),
        icon: Icons.edit_note_rounded,
        canDownloadInvoice: false,
        requiresAttention: false,
      );
    case OrderLifecycleState.pendingSync:
      return const OrderLifecyclePresentation(
        label: 'بانتظار المزامنة',
        description: 'سيتم إرسال الطلب تلقائياً عند توفر الاتصال.',
        color: Color(0xFF854D0E),
        icon: Icons.schedule_send_rounded,
        canDownloadInvoice: false,
        requiresAttention: false,
      );
    case OrderLifecycleState.syncing:
      return const OrderLifecyclePresentation(
        label: 'جارٍ الإرسال',
        description: 'الطلب قيد المزامنة حالياً.',
        color: Color(0xFF2563EB),
        icon: Icons.sync_rounded,
        canDownloadInvoice: false,
        requiresAttention: false,
      );
    case OrderLifecycleState.confirmed:
      return const OrderLifecyclePresentation(
        label: 'مؤكد من الخادم',
        description: 'تم تأكيد الطلب ويمكن تنزيل الفاتورة.',
        color: Color(0xFF0E9F6E),
        icon: Icons.verified_rounded,
        canDownloadInvoice: true,
        requiresAttention: false,
      );
    case OrderLifecycleState.reconciled:
      return const OrderLifecyclePresentation(
        label: 'مؤكد بعد مطابقة',
        description: 'تمت مطابقة الطلب المحلي مع طلب مؤكد على الخادم.',
        color: Color(0xFF0E9F6E),
        icon: Icons.task_alt_rounded,
        canDownloadInvoice: true,
        requiresAttention: false,
      );
    case OrderLifecycleState.failedRetryable:
      return const OrderLifecyclePresentation(
        label: 'فشل قابل لإعادة المحاولة',
        description: 'ستتم إعادة محاولة الإرسال تلقائياً.',
        color: Color(0xFFB45309),
        icon: Icons.refresh_rounded,
        canDownloadInvoice: false,
        requiresAttention: true,
      );
    case OrderLifecycleState.failedTerminal:
      return const OrderLifecyclePresentation(
        label: 'فشل نهائي',
        description: 'تعذر مزامنة الطلب ويتطلب إجراءً يدوياً.',
        color: Color(0xFFB91C1C),
        icon: Icons.error_outline_rounded,
        canDownloadInvoice: false,
        requiresAttention: true,
      );
    case OrderLifecycleState.staleConflict:
      return const OrderLifecyclePresentation(
        label: 'تعارض أسعار',
        description: 'الأسعار أو التوفر تغيرت ويجب مراجعة الطلب.',
        color: Color(0xFFDC2626),
        icon: Icons.warning_amber_rounded,
        canDownloadInvoice: false,
        requiresAttention: true,
      );
  }
}

String presentServerOrderStatus(String rawStatus) {
  final normalized = TextSanitizer.fix(rawStatus).toLowerCase();
  switch (normalized) {
    case 'completed':
      return 'مكتمل';
    case 'processing':
      return 'قيد المعالجة';
    case 'on-hold':
      return 'معلق';
    case 'cancelled':
      return 'ملغي';
    case 'failed':
      return 'فشل';
    case 'pending':
      return 'قيد الانتظار';
    case 'pending-payment':
      return 'بانتظار الدفع';
    case 'refunded':
      return 'مسترجع';
    case 'draft':
      return 'مسودة';
    case '':
      return '-';
    default:
      return rawStatus;
  }
}
