import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/theme/app_colors.dart';
import 'package:lpco_llc/core/theme/app_radius.dart';
import 'package:lpco_llc/core/theme/app_spacing.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/core/widgets/lpco_logo.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/notifications/presentation/cubit/notifications_badge_cubit.dart';

class AppSideDrawer extends StatelessWidget {
  final bool embedded;

  const AppSideDrawer({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (embedded) {
      return content;
    }

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final currentUser = context.read<AuthCubit>().currentUser;
    final isAdmin = _isAdminUser(
      currentUser?.roles ?? const <String>[],
      currentUser?.group ?? '',
      currentUser?.isGuest ?? true,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D2535), Color(0xFF101622)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              _header(context),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    _sectionLabel(context, 'التنقل السريع'),
                    _item(
                      context,
                      Icons.home_rounded,
                      'الصفحة الرئيسية',
                      AppRoutePaths.home,
                    ),
                    _item(
                      context,
                      Icons.shopping_bag_rounded,
                      'الطلبات',
                      AppRoutePaths.orders,
                    ),
                    _item(
                      context,
                      Icons.inventory_2_rounded,
                      'المنتجات',
                      AppRoutePaths.categories,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _divider(),
                    _sectionLabel(context, 'التصفح'),
                    _item(
                      context,
                      Icons.sell_rounded,
                      'العلامات التجارية',
                      AppRoutePaths.brands,
                    ),
                    _item(
                      context,
                      Icons.favorite_rounded,
                      'المنتجات المحفوظة',
                      AppRoutePaths.saved,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _divider(),
                    _sectionLabel(context, 'الحساب والدعم'),
                    _item(
                      context,
                      Icons.notifications_active_rounded,
                      'الإشعارات',
                      AppRoutePaths.notifications,
                    ),
                    _item(
                      context,
                      Icons.person_rounded,
                      'حسابي',
                      AppRoutePaths.account,
                    ),
                    _item(
                      context,
                      Icons.work_rounded,
                      'الوظائف',
                      AppRoutePaths.jobs,
                    ),
                    _item(
                      context,
                      Icons.call_rounded,
                      'تواصل معنا',
                      AppRoutePaths.contact,
                    ),
                    if (isAdmin)
                      _item(
                        context,
                        Icons.admin_panel_settings_rounded,
                        'لوحة الإدارة',
                        AppRoutePaths.admin,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => launchUrlString('tel:0996841113'),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primaryRed.withValues(
                        alpha: 0.22,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        side: BorderSide(
                          color: AppColors.primaryRed.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('الدعم الفني'),
                  ),
                ),
              ),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final isLogged =
                      state is Authenticated || state is GuestAuthenticated;
                  return TextButton.icon(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      final authCubit = context.read<AuthCubit>();
                      _closeMenu(context);
                      if (isLogged) {
                        await context.read<CartCubit>().clear();
                        await authCubit.logout();
                        if (context.mounted) {
                          router.go(AppRoutePaths.login);
                        }
                      } else {
                        router.push(AppRoutePaths.login);
                      }
                    },
                    icon: Icon(
                      isLogged ? Icons.logout_rounded : Icons.login_rounded,
                      color: const Color(0xFFE0838D),
                    ),
                    label: Text(
                      isLogged ? 'تسجيل الخروج' : 'تسجيل الدخول',
                      style: const TextStyle(
                        color: Color(0xFFE6EAF0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  TextSanitizer.fix('إصدار التطبيق 1.0.0'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final user = context.read<AuthCubit>().currentUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const _DrawerLogo(),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primaryRed,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TextSanitizer.fix(user?.displayName ?? 'زائر'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (user?.email.isNotEmpty == true)
                        Text(
                          user!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB8C0CC),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: BlocBuilder<CartCubit, CartState>(
                  builder: (context, state) => _miniStatCard(
                    icon: Icons.shopping_cart_checkout_rounded,
                    label: 'السلة',
                    value: '${_cartCountOf(state)}',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: BlocBuilder<NotificationsBadgeCubit, int>(
                  builder: (context, unreadCount) => _miniStatCard(
                    icon: Icons.notifications_active_rounded,
                    label: 'غير مقروء',
                    value: '$unreadCount',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _cartCountOf(CartState state) {
    if (state is CartLoaded) {
      return state.totalCount;
    }
    return 0;
  }

  Widget _miniStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: const Color(0xFFF2A9B2)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              TextSanitizer.fix(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD9E0EA),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final selected =
        currentLocation == route || currentLocation.startsWith('$route/');
    final isNotifications = route == AppRoutePaths.notifications;
    final color = selected ? Colors.white : const Color(0xFFD9DEE6);
    final safeLabel = TextSanitizer.fix(label);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: selected
            ? LinearGradient(
                colors: <Color>[
                  AppColors.primaryRed.withValues(alpha: 0.34),
                  AppColors.primaryRedDark.withValues(alpha: 0.24),
                ],
              )
            : null,
        color: selected ? null : Colors.transparent,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        leading: isNotifications
            ? BlocBuilder<NotificationsBadgeCubit, int>(
                builder: (context, unreadCount) {
                  return _drawerIcon(
                    icon: icon,
                    color: selected ? Colors.white : const Color(0xFFE8A4AC),
                    badgeCount: unreadCount,
                  );
                },
              )
            : _drawerIcon(
                icon: icon,
                color: selected ? Colors.white : const Color(0xFFE8A4AC),
              ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: selected
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.44),
        ),
        title: Text(
          safeLabel,
          style: TextStyle(
            color: color,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        onTap: () {
          final router = GoRouter.of(context);
          _closeMenu(context);
          if (selected) {
            return;
          }
          if (_opensAsStackPage(route)) {
            router.push(route);
            return;
          }
          router.go(route);
        },
      ),
    );
  }

  bool _opensAsStackPage(String route) {
    return route == AppRoutePaths.notifications ||
        route == AppRoutePaths.contact;
  }

  Widget _drawerIcon({
    required IconData icon,
    required Color color,
    int badgeCount = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (badgeCount > 0)
          PositionedDirectional(
            top: -6,
            end: -10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Text(
        TextSanitizer.fix(label),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.64),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.xs,
        end: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }

  void _closeMenu(BuildContext context) {
    final zoomDrawer = ZoomDrawer.of(context);
    if (zoomDrawer != null && zoomDrawer.isOpen()) {
      zoomDrawer.close();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  bool _isAdminUser(List<String> roles, String group, bool isGuest) {
    if (isGuest) return false;

    final normalizedRoles = roles.map((e) => e.toLowerCase()).toSet();
    if (normalizedRoles.contains('administrator') ||
        normalizedRoles.contains('shop_manager') ||
        normalizedRoles.contains('editor')) {
      return true;
    }

    final normalizedGroup = group.toLowerCase();
    return normalizedGroup.contains('admin') ||
        normalizedGroup.contains('manager');
  }
}

class _DrawerLogo extends StatelessWidget {
  const _DrawerLogo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LpcoLogo(showTagline: false, fontSize: 52),
        SizedBox(height: 6),
        Text(
          'LPCO LLC',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            height: 1,
          ),
        ),
      ],
    );
  }
}
