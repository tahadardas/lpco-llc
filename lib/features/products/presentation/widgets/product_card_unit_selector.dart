import 'package:flutter/material.dart';
import 'package:lpco_llc/core/utils/formatters.dart';

class ProductCardUnit {
  final String type;
  final String label;
  final num price;
  final int? piecesCount;

  const ProductCardUnit({
    required this.type,
    required this.label,
    required this.price,
    required this.piecesCount,
  });
}

class ProductCardUnitSelector extends StatelessWidget {
  final List<ProductCardUnit> units;
  final String? selectedUnitType;
  final ValueChanged<String> onSelected;
  final String currencyCode;
  final bool isGuest;
  final bool compact;

  const ProductCardUnitSelector({
    super.key,
    required this.units,
    required this.selectedUnitType,
    required this.onSelected,
    required this.currencyCode,
    required this.isGuest,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: units
          .map((unit) {
            final selected = unit.type == selectedUnitType;
            final titleColor = selected
                ? const Color(0xFFD31225)
                : const Color(0xFF343A45);
            final priceColor = isGuest
                ? const Color(0xFF7A8392)
                : const Color(0xFF111317);
            return Padding(
              padding: EdgeInsetsDirectional.only(bottom: compact ? 2 : 6),
              child: InkWell(
                key: ValueKey<String>('product_card_unit_${unit.type}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(unit.type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 3 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFD31225)
                          : const Color(0xFFDDE3ED),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: compact ? 0 : 2,
                        ),
                        child: Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: compact ? 16 : 18,
                          color: selected
                              ? const Color(0xFFD31225)
                              : const Color(0xFF8C95A4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              unit.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 10 : 11.5,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isGuest
                                  ? '\u0633\u062c\u0644 \u0644\u0639\u0631\u0636 \u0627\u0644\u0633\u0639\u0631'
                                  : PriceFormatter.format(
                                      unit.price,
                                      currencyCode: currencyCode,
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: priceColor,
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 9 : 10.5,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected && !compact) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE3E6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '\u0645\u062d\u062f\u062f',
                            style: TextStyle(
                              color: Color(0xFFD31225),
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
