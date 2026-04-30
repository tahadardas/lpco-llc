import 'package:flutter/material.dart';

import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/shared/commerce/product_identity/product_identity_formatter.dart';

class CheckoutCartStep extends StatelessWidget {
  final CartLoaded cartState;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;

  const CheckoutCartStep({
    super.key,
    required this.cartState,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مراجعة السلة',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const SizedBox(height: 6),
        const Text(
          'تأكد من الكميات والوحدات قبل الانتقال لبيانات الشحن.',
          style: TextStyle(
            color: Color(0xFF707887),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in cartState.items) _cartItemTile(item),
        const SizedBox(height: 8),
        _totalCard(),
      ],
    );
  }

  Widget _cartItemTile(CartItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: AppNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.contain,
                placeholder: Container(color: const Color(0xFFF0F2F6)),
                errorWidget: Container(
                  color: const Color(0xFFF0F2F6),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ProductIdentityFormatter.formatUnitLabel(
                    unitLabel: item.unitLabel,
                    unitType: item.unitType,
                    piecesCount: item.piecesCount,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF707887),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'الكمية: ${ProductIdentityFormatter.formatQuantityLabel(quantity: item.quantity, unitLabel: item.unitLabel, unitType: item.unitType)}',
                  style: const TextStyle(
                    color: Color(0xFF707887),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  PriceFormatter.format(
                    item.totalPrice,
                    currencyCode: item.currency,
                  ),
                  style: const TextStyle(
                    color: GlassStyle.fireRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => onRemove(item.itemKey),
                tooltip: 'حذف',
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: () => onDecrement(item.itemKey),
                      tooltip: 'تنقيص',
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => onIncrement(item.itemKey),
                      tooltip: 'زيادة',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'إجمالي الطلب',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
          Text(
            PriceFormatter.format(
              cartState.subtotal,
              currencyCode: cartState.currency,
            ),
            style: const TextStyle(
              color: GlassStyle.fireRed,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }
}
