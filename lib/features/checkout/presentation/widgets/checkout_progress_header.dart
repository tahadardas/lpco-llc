import 'package:flutter/material.dart';

import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/checkout/application/checkout_state.dart';

class CheckoutProgressHeader extends StatelessWidget {
  final int currentStep;
  final CheckoutStatus status;

  const CheckoutProgressHeader({
    super.key,
    required this.currentStep,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _metaForStep(currentStep);
    final statusMeta = _statusMeta(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: GlassStyle.acrylicDecoration(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.icon, size: 18, color: meta.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (statusMeta != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusMeta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusMeta.color.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusMeta.icon, size: 14, color: statusMeta.color),
                  const SizedBox(width: 4),
                  Text(
                    statusMeta.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusMeta.color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  _CheckoutStepMeta _metaForStep(int step) {
    switch (step) {
      case 0:
        return const _CheckoutStepMeta(
          title: 'مراجعة السلة',
          description: 'تأكد من الكميات والمنتجات قبل المتابعة.',
          icon: Icons.shopping_bag_outlined,
          color: Color(0xFF2563EB),
        );
      case 1:
        return const _CheckoutStepMeta(
          title: 'بيانات الشحن',
          description: 'أدخل بيانات الاستلام بدقة لتجنب التأخير.',
          icon: Icons.local_shipping_outlined,
          color: Color(0xFF0E9F6E),
        );
      case 2:
        return const _CheckoutStepMeta(
          title: 'طريقة الدفع',
          description: 'اختر طريقة الدفع المناسبة لنشاطك.',
          icon: Icons.payments_outlined,
          color: Color(0xFFB45309),
        );
      case 3:
      default:
        return const _CheckoutStepMeta(
          title: 'تأكيد الإرسال',
          description: 'راجع الملخص النهائي ثم أرسل الطلب.',
          icon: Icons.fact_check_outlined,
          color: Color(0xFFD31225),
        );
    }
  }

  _CheckoutStatusMeta? _statusMeta(CheckoutStatus status) {
    switch (status) {
      case CheckoutStatus.submitting:
        return const _CheckoutStatusMeta(
          label: 'جارٍ الإرسال',
          icon: Icons.sync_rounded,
          color: Color(0xFF2563EB),
        );
      case CheckoutStatus.awaitingPaymentConfirmation:
        return const _CheckoutStatusMeta(
          label: 'بانتظار التأكيد',
          icon: Icons.qr_code_rounded,
          color: Color(0xFFB45309),
        );
      case CheckoutStatus.failure:
        return const _CheckoutStatusMeta(
          label: 'يتطلب مراجعة',
          icon: Icons.error_outline_rounded,
          color: Color(0xFFB91C1C),
        );
      default:
        return null;
    }
  }
}

class _CheckoutStepMeta {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _CheckoutStepMeta({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _CheckoutStatusMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _CheckoutStatusMeta({
    required this.label,
    required this.icon,
    required this.color,
  });
}
