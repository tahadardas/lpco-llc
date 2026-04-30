import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/domain/admin_module.dart';
import 'package:lpco_llc/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminCubit()..fetchDashboard(),
      child: AppBackScope(
        fallbackLocation: AppRoutePaths.account,
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: BrandAppBar(
            title: 'لوحة التحكم',
            showBack: true,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () async {
                  final cartCubit = context.read<CartCubit>();
                  final authCubit = context.read<AuthCubit>();
                  await cartCubit.clear();
                  await authCubit.logout();
                  if (!context.mounted) return;
                  context.go(AppRoutePaths.login);
                },
              ),
            ],
          ),
          body: BlocBuilder<AdminCubit, AdminState>(
            builder: (context, state) {
              if (state is AdminLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is AdminError) {
                return _DashboardError(message: state.message);
              }

              if (state is! AdminLoaded) {
                return const SizedBox.shrink();
              }

              final quickActions = state.modules
                  .where(
                    (module) =>
                        module.isAvailable &&
                        module.kind != AdminModuleKind.stats,
                  )
                  .take(8)
                  .toList();

              return RefreshIndicator(
                onRefresh: () => context.read<AdminCubit>().fetchDashboard(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 92, 16, 24),
                  children: <Widget>[
                    _KpiGrid(dashboard: state.dashboard),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'إجراءات سريعة',
                      subtitle: 'روابط مباشرة للوحدات التشغيلية المتاحة',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: quickActions
                          .map(
                            (module) => _QuickActionChip(
                              module: module,
                              onTap: () => context.push(
                                AppRoutePaths.adminModule(module.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'الوحدات',
                      subtitle: 'القدرات الحقيقية القادمة من الخادم',
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.modules.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.14,
                          ),
                      itemBuilder: (context, index) {
                        final module = state.modules[index];
                        return _ModuleCard(
                          module: module,
                          onTap:
                              module.isAvailable &&
                                  module.kind != AdminModuleKind.stats
                              ? () => context.push(
                                  AppRoutePaths.adminModule(module.id),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'آخر النشاط',
                      subtitle: 'طلبات، أعضاء، وإشعارات حديثة',
                    ),
                    const SizedBox(height: 10),
                    _ActivityBlock(
                      title: 'أحدث الطلبات',
                      emptyLabel: 'لا توجد طلبات حديثة',
                      children: state.dashboard.latestOrders
                          .map(
                            (order) => _SimpleRow(
                              title: 'طلب #${order.number}',
                              subtitle:
                                  '${order.customer} • ${order.statusLabel}',
                              trailing: PriceFormatter.format(
                                order.total,
                                currencyCode: order.currency,
                              ),
                              onTap: () => context.push(
                                AppRoutePaths.adminOrder(order.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    _ActivityBlock(
                      title: 'أحدث الأعضاء',
                      emptyLabel: 'لا يوجد أعضاء حديثون',
                      children: state.dashboard.latestMembers
                          .map(
                            (member) => _SimpleRow(
                              title: member.name.isEmpty
                                  ? member.username
                                  : member.name,
                              subtitle:
                                  '${member.group} • ${member.accountStatus}',
                              trailing: member.phone,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    _ActivityBlock(
                      title: 'آخر الإشعارات',
                      emptyLabel: 'لا يوجد سجل إشعارات بعد',
                      children: state.dashboard.latestNotifications
                          .map(
                            (entry) => _SimpleRow(
                              title: entry.title,
                              subtitle:
                                  '${entry.audience} • مقروء ${entry.readCount}',
                              trailing: '${entry.deliveredCount}',
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'صحة النظام',
                      subtitle: 'جاهزية البيئة والمصادقة والإشعارات والفواتير',
                    ),
                    const SizedBox(height: 10),
                    ...state.diagnostics.sections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DiagnosticsSection(section: section),
                      ),
                    ),
                    if (state.diagnostics.warnings.isNotEmpty ||
                        state.dashboard.warnings.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: GlassStyle.acrylicDecoration(radius: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'تحذيرات حالية',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...<String>{
                              ...state.dashboard.warnings,
                              ...state.diagnostics.warnings,
                            }.map(
                              (warning) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFC98106),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        warning,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});

  final AdminDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, IconData icon})>[
      (
        label: 'طلبات اليوم',
        value: '${dashboard.ordersToday}',
        icon: Icons.today_rounded,
      ),
      (
        label: 'طلبات الشهر',
        value: '${dashboard.ordersMonth}',
        icon: Icons.calendar_month_rounded,
      ),
      (
        label: 'إيراد الشهر',
        value: PriceFormatter.format(
          dashboard.revenueMonth,
          currencyCode: 'syp',
        ),
        icon: Icons.payments_rounded,
      ),
      (
        label: 'إجمالي الأعضاء',
        value: '${dashboard.totalMembers}',
        icon: Icons.people_alt_rounded,
      ),
      (
        label: 'طلبات معلقة',
        value: '${dashboard.pendingOrders}',
        icon: Icons.hourglass_top_rounded,
      ),
      (
        label: 'طلبات مكتملة',
        value: '${dashboard.completedOrders}',
        icon: Icons.check_circle_rounded,
      ),
      (
        label: 'إشعارات غير مقروءة',
        value: '${dashboard.unreadNotificationsCount}',
        icon: Icons.notifications_active_rounded,
      ),
      (
        label: 'أجهزة مسجلة',
        value: '${dashboard.deviceTokensCount}',
        icon: Icons.phone_android_rounded,
      ),
      (
        label: 'مخزون منخفض',
        value: '${dashboard.lowStockProductsCount}',
        icon: Icons.inventory_2_rounded,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: GlassStyle.acrylicDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: GlassStyle.fireRed.withValues(alpha: 0.1),
                ),
                child: Icon(item.icon, color: GlassStyle.fireRed),
              ),
              const Spacer(),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.module, required this.onTap});

  final AdminModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: GlassStyle.acrylicDecoration(radius: 18),
          child: Text(
            module.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, this.onTap});

  final AdminModule module;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (module.support) {
      AdminModuleSupport.fullControl => const Color(0xFF138A3F),
      AdminModuleSupport.readOnly => const Color(0xFFC98106),
      AdminModuleSupport.partial => const Color(0xFF1D6FD8),
      AdminModuleSupport.unavailable => GlassStyle.fireRed,
    };

    final badge = switch (module.support) {
      AdminModuleSupport.fullControl => 'تحكم كامل',
      AdminModuleSupport.readOnly => 'قراءة فقط',
      AdminModuleSupport.partial => 'جزئي',
      AdminModuleSupport.unavailable => 'غير متاح',
    };

    final child = Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassStyle.acrylicDecoration(
        radius: 20,
      ).copyWith(border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  module.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (module.isAvailable)
                const Icon(Icons.chevron_left_rounded, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              module.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF667085),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _ActivityBlock extends StatelessWidget {
  const _ActivityBlock({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              emptyLabel,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: child,
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({required this.section});

  final AdminDiagnosticSectionModel section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassStyle.acrylicDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            section.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...section.items.map((item) {
            final color = switch (item.status) {
              'ok' => const Color(0xFF138A3F),
              'warning' => const Color(0xFFC98106),
              'error' => GlassStyle.fireRed,
              _ => const Color(0xFF1D6FD8),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.circle, size: 12, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: GlassStyle.acrylicDecoration(radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: GlassStyle.fireRed,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.read<AdminCubit>().fetchDashboard(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
