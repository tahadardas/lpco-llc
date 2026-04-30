import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';

import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/app_drawer.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/checkout_wizard_stepper.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/widgets/cart_currency_conflict_dialog.dart';
import 'package:lpco_llc/shared/commerce/product_identity/product_identity_formatter.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: false,
      appBar: BrandAppBar(
        title: 'سلة التسوق',
        showMenu: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'إفراغ السلة',
            onPressed: () => _confirmClearCart(context),
          ),
        ],
      ),
      drawer: const AppSideDrawer(),
      body: BlocConsumer<CartCubit, CartState>(
        listenWhen: (previous, current) => current is CartCurrencyConflict,
        listener: (context, state) async {
          if (state is CartCurrencyConflict) {
            await showCartCurrencyConflictDialog(context, state);
          }
        },
        builder: (context, state) {
          if (state is CartLoading) {
            return AppSkeleton(
              enabled: true,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                itemCount: 4,
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBlock(height: 124),
                ),
              ),
            );
          }

          final loaded = state as CartLoaded;
          if (loaded.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: GlassStyle.acrylicDecoration(radius: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.shopping_cart_outlined, size: 58),
                      const SizedBox(height: 10),
                      const Text(
                        'السلة فارغة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أضف منتجات من التصنيفات أو من البحث للمتابعة.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => context.go(
                          AppRoutePaths.catalogListing(title: 'المنتجات'),
                        ),
                        child: const Text('تصفح المنتجات'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  itemCount: loaded.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _itemTile(context, loaded.items[index]),
                ),
              ),
              _checkoutBar(context, loaded),
            ],
          );
        },
      ),
    );
  }

  Widget _itemTile(BuildContext context, CartItemModel item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: GlassStyle.acrylicDecoration(radius: 24),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 92,
              height: 92,
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
                  item.displayName,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _buildVariantLabel(item),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  PriceFormatter.format(
                    item.unitPrice * item.quantity,
                    currencyCode: item.currency,
                  ),
                  style: const TextStyle(
                    color: Color(0xFFD31225),
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                onPressed: () async {
                  await context.read<CartCubit>().removeByKey(item.itemKey);
                },
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () async {
                        await context.read<CartCubit>().decrementItem(
                          item.itemKey,
                        );
                      },
                      icon: const Icon(Icons.remove_rounded, size: 20),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () async {
                        await context.read<CartCubit>().incrementItem(
                          item.itemKey,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
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

  Widget _checkoutBar(BuildContext context, CartLoaded state) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: FrostedGlassPanel(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'المجموع:',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '${state.totalCount} عنصر',
                          style: const TextStyle(
                            color: Color(0xFF6E7786),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    PriceFormatter.format(
                      state.subtotal,
                      currencyCode: state.currency,
                    ),
                    style: const TextStyle(
                      color: GlassStyle.fireRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const CheckoutWizardStepper(currentStep: 1),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(AppRoutePaths.checkout),
                  child: const Text('متابعة الدفع'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearCart(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إفراغ السلة'),
          content: const Text('هل تريد حذف كل المنتجات من السلة؟'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حذف الكل'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true && context.mounted) {
      await context.read<CartCubit>().clear();
    }
  }

  String _buildVariantLabel(CartItemModel item) {
    final components = <String>[
      'الوحدة: ${ProductIdentityFormatter.formatUnitLabel(unitLabel: item.unitLabel, unitType: item.unitType, piecesCount: item.piecesCount)}',
    ];
    if (item.colorName != null && item.colorName!.isNotEmpty) {
      components.add('اللون: ${item.colorName}');
    }
    for (final entry in item.selectedVariants.entries) {
      components.add('${entry.value}');
    }

    if (components.isEmpty) return '';
    return components.join(' | ');
  }
}
