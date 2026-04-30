import 'package:flutter/material.dart';

import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/glass.dart';

class CheckoutPaymentStep extends StatelessWidget {
  final num subtotal;
  final String currency;
  final String paymentMethod;
  final ValueChanged<String> onSelectPaymentMethod;

  const CheckoutPaymentStep({
    super.key,
    required this.subtotal,
    required this.currency,
    required this.paymentMethod,
    required this.onSelectPaymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final totalFormatted = PriceFormatter.format(
      subtotal,
      currencyCode: currency,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختيار طريقة الدفع',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'إجمالي الطلب: $totalFormatted',
            style: const TextStyle(
              color: Color(0xFFD31225),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          _paymentOption(
            value: 'cod',
            title: 'الدفع عند الاستلام',
            subtitle: 'سداد المبلغ عند التسليم.',
            icon: Icons.payments_outlined,
          ),
          _paymentOption(
            value: 'bacs',
            title: 'حوالة مصرفية',
            subtitle: 'تحويل مباشر إلى حساباتنا البنكية.',
            icon: Icons.account_balance_outlined,
          ),
          _paymentOption(
            value: 'instant_barcode',
            title: 'شام كاش - الباركود الفوري',
            subtitle: 'إصدار باركود دفع فوري بعد إرسال الطلب.',
            icon: Icons.qr_code_2_outlined,
          ),
          const SizedBox(height: 8),
          if (paymentMethod == 'bacs') _bankTransferInfo(),
          if (paymentMethod == 'instant_barcode') _shamCashInfo(totalFormatted),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = paymentMethod == value;

    return InkWell(
      onTap: () => onSelectPaymentMethod(value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration:
            GlassStyle.acrylicDecoration(
              radius: 14,
              color: selected
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.82),
            ).copyWith(
              border: Border.all(
                color: selected ? GlassStyle.fireRed : const Color(0xFFE1E5EC),
                width: selected ? 1.4 : 1,
              ),
            ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? GlassStyle.fireRed : const Color(0xFF667085),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? GlassStyle.fireRed
                          : const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF707887),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? GlassStyle.fireRed : const Color(0xFF9DA4B2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankTransferInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'يرجى استخدام رقم الطلب كمرجع للتحويل ثم متابعة الحالة من شاشة الطلبات.',
          ),
          const SizedBox(height: 10),
          for (final account in AppStaticData.bankAccounts)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.bankName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('رقم الحساب: ${account.accountNumber}'),
                  Text('صاحب الحساب: ${account.accountHolder}'),
                  Text('الهاتف: ${account.phone}'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _shamCashInfo(String totalFormatted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سيتم إنشاء باركود الدفع تلقائياً بعد الضغط على إرسال الطلب.',
          ),
          const SizedBox(height: 6),
          Text('المبلغ المستحق: $totalFormatted'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
            ),
            child: const Text(
              'ملاحظة: سيبقى الطلب بحالة انتظار تأكيد حتى تثبيت التحويل.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
