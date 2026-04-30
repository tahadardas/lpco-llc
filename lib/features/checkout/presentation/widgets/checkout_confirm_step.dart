import 'package:flutter/material.dart';

import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/checkout/domain/models/checkout_form.dart';
import 'package:lpco_llc/shared/commerce/product_identity/product_identity_formatter.dart';

class CheckoutConfirmStep extends StatelessWidget {
  final CartLoaded cartState;
  final UserModel user;
  final CheckoutForm form;

  const CheckoutConfirmStep({
    super.key,
    required this.cartState,
    required this.user,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    final totalFormatted = PriceFormatter.format(
      cartState.subtotal,
      currencyCode: cartState.currency,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تأكيد الطلب',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const SizedBox(height: 6),
        const Text(
          'بعد الإرسال سيتم حفظ الطلب مباشرة أو وضعه بانتظار المزامنة حسب حالة الاتصال.',
          style: TextStyle(
            color: Color(0xFF707887),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _section(
          title: 'بيانات الاستلام',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('الاسم', form.fullName.trim()),
              _summaryRow('الهاتف', form.phone.trim()),
              _summaryRow('العنوان', form.address.trim()),
              _summaryRow(
                'المدينة',
                form.city.trim().isEmpty ? 'غير محدد' : form.city.trim(),
              ),
              _summaryRow(
                'المحافظة',
                form.state.trim().isEmpty ? 'غير محدد' : form.state.trim(),
              ),
              _summaryRow(
                'البريد',
                form.email.trim().isEmpty ? user.email : form.email.trim(),
              ),
              _summaryRow('طريقة الدفع', form.paymentMethodTitle),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _section(
          title: 'المنتجات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in cartState.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ProductIdentityFormatter.formatUnitAndQuantity(
                                quantity: item.quantity,
                                unitLabel: item.unitLabel,
                                unitType: item.unitType,
                                piecesCount: item.piecesCount,
                              ),
                              style: const TextStyle(
                                color: Color(0xFF707887),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        PriceFormatter.format(
                          item.totalPrice,
                          currencyCode: item.currency,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'إجمالي الطلب',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    totalFormatted,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD31225),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF707887),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
