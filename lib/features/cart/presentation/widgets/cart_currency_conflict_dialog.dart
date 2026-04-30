import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';

Future<void> showCartCurrencyConflictDialog(
  BuildContext context,
  CartCurrencyConflict state,
) async {
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
    return;
  }

  final currentCurrency = state.currentCurrency.toUpperCase();
  final newCurrency = state.newCurrency.toUpperCase();
  final shouldSwitch = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('تعارض في عملة السلة'),
        content: Text(
          'السلة الحالية تحتوي على منتجات بعملة $currentCurrency. '
          'هل تريد تفريغ السلة والتحويل إلى $newCurrency لإضافة المنتج الجديد؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تبديل العملة'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) {
    return;
  }

  final cartCubit = context.read<CartCubit>();
  if (shouldSwitch == true) {
    await cartCubit.confirmCurrencySwitch();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تبديل العملة إلى $newCurrency وإضافة المنتج إلى السلة',
        ),
      ),
    );
    return;
  }

  await cartCubit.cancelCurrencySwitch();
}
