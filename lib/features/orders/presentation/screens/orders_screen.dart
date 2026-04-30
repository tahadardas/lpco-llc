import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:lpco_llc/features/orders/presentation/utils/order_lifecycle_presenter.dart';
import 'package:lpco_llc/features/orders/presentation/widgets/order_status_widgets.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersCubit()..loadOrders(),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  double _bottomSafeInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final paddingBottom = mediaQuery.padding.bottom;
    final viewPaddingBottom = mediaQuery.viewPadding.bottom;
    return paddingBottom > viewPaddingBottom
        ? paddingBottom
        : viewPaddingBottom;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = _bottomSafeInset(context);

    return AppBackScope(
      fallbackLocation: AppRoutePaths.account,
      child: Scaffold(
        extendBody: false,
        extendBodyBehindAppBar: false,
        appBar: BrandAppBar(
          title: 'طلباتي',
          showBack: true,
          onBack: () => context.go(AppRoutePaths.account),
          actions: <Widget>[
            IconButton(
              tooltip: 'تحديث',
              onPressed: () => context.read<OrdersCubit>().loadOrders(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            if (state is OrdersLoading || state is OrdersInitial) {
              return const _OrdersLoadingState();
            }

            if (state is OrdersError) {
              return _ErrorState(
                message: state.message,
                onRetry: () => context.read<OrdersCubit>().loadOrders(),
              );
            }

            final orders = state is OrdersLoaded
                ? state.orders
                : <OrderModel>[];
            if (orders.isEmpty) {
              return _EmptyState(
                onRefresh: () => context.read<OrdersCubit>().loadOrders(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<OrdersCubit>().loadOrders(),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 120),
                itemCount: orders.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _OrderCard(order: orders[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset =
        mediaQuery.padding.bottom > mediaQuery.viewPadding.bottom
        ? mediaQuery.padding.bottom
        : mediaQuery.viewPadding.bottom;
    return AppSkeleton(
      enabled: true,
      child: ListView.builder(
        itemCount: 4,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 130 + bottomInset),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SkeletonBlock(height: 156),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final total = num.tryParse(order.total) ?? 0;
    final lifecycle = presentOrderLifecycle(order);
    final canDownloadInvoice =
        lifecycle.canDownloadInvoice && order.isConfirmedServerSide;
    final paymentLabel = _paymentLabel(order.paymentMethod);
    final serverStatus = order.isConfirmedServerSide
        ? presentServerOrderStatus(order.status)
        : '-';

    return TapScale(
      onTap: () => context.push(AppRoutePaths.ordersDetails, extra: order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: GlassStyle.acrylicDecoration(radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'طلب #${order.orderNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  PriceFormatter.format(total, currencyCode: order.currency),
                  style: const TextStyle(
                    color: GlassStyle.fireRed,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OrderLifecycleBadge(lifecycle: lifecycle),
                if (order.isConfirmedServerSide)
                  _serverStatusChip(serverStatus),
              ],
            ),
            const SizedBox(height: 8),
            OrderLifecyclePanel(
              lifecycle: lifecycle,
              errorMessage: order.syncError.trim().isEmpty
                  ? null
                  : order.syncError,
            ),
            const SizedBox(height: 8),
            _infoText('تاريخ الطلب: ${order.date.isEmpty ? '-' : order.date}'),
            _infoText('طريقة الدفع: $paymentLabel'),
            if (order.isConfirmedServerSide)
              _infoText('حالة المعالجة: $serverStatus'),
            if (order.retryCount > 0)
              _infoText('محاولات المزامنة: ${order.retryCount}'),
            if (_canManualRetry)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _retryOrder(context),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('إعادة الإرسال يدويًا'),
                  ),
                ),
              )
            else
              const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutePaths.ordersDetails, extra: order),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('تفاصيل الطلب'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutePaths.ordersDetails, extra: order),
                  icon: Icon(
                    canDownloadInvoice
                        ? Icons.download_rounded
                        : lifecycle.requiresAttention
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                  ),
                  label: Text(
                    canDownloadInvoice
                        ? 'تحميل الفاتورة'
                        : lifecycle.requiresAttention
                        ? 'مراجعة الحالة'
                        : 'عرض الحالة',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canManualRetry {
    final hasFailure = order.hasRetryableFailure || order.hasTerminalFailure;
    return hasFailure &&
        !order.hasSyncConflict &&
        !order.isConfirmedServerSide &&
        order.localQueueId.trim().isNotEmpty;
  }

  Future<void> _retryOrder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<OrdersCubit>().retryOrder(order);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'تمت إعادة الإرسال يدويًا. سيتم تنفيذ المزامنة فور توفر الاتصال.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = ApiContract.safeMessageFromException(
        error,
        fallback: 'تعذرت إعادة الإرسال اليدوي.',
      );
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _serverStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoText(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  String _paymentLabel(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'cod') {
      return 'الدفع عند الاستلام';
    }
    if (value == 'bacs') {
      return 'حوالة مصرفية';
    }
    if (value == 'instant_barcode') {
      return 'شام كاش';
    }
    return raw.trim().isEmpty ? '-' : raw;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: GlassStyle.acrylicDecoration(radius: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: GlassStyle.fireRed,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                message.isEmpty ? 'تعذر تحميل الطلبات' : message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: GlassStyle.acrylicDecoration(radius: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 42),
              const SizedBox(height: 10),
              const Text(
                'لا توجد طلبات بعد',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'عند إتمام أول طلب سيظهر هنا',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
