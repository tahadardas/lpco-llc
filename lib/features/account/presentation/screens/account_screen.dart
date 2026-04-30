import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lpco_llc/app/router/app_routes.dart';

import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/widgets/app_drawer.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/notifications/presentation/cubit/notifications_badge_cubit.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: false,
      appBar: BrandAppBar(
        title: 'حسابي',
        showMenu: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.go(AppRoutePaths.cart),
          ),
        ],
      ),
      drawer: const AppSideDrawer(),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading || state is AuthInitial) {
            return AppSkeleton(enabled: true, child: const _AccountSkeleton());
          }

          if (state is Unauthenticated || state is GuestAuthenticated) {
            return _buildGuestFallback(
              context,
              message: 'يرجى تسجيل الدخول لإدارة حسابك',
            );
          }

          final user = context.read<AuthCubit>().currentUser;
          if (user == null) {
            return _buildGuestFallback(
              context,
              message: 'تعذر تحميل بيانات الحساب حالياً. يمكنك تسجيل الدخول مجدداً.',
            );
          }
          final isAdmin = _isAdminUser(user.roles, user.group, user.isGuest);

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            children: [
              _headerCard(
                name: user.fullName.isEmpty ? user.displayName : user.fullName,
                company: user.companyName,
                email: user.email,
              ),
              const SizedBox(height: 12),
              Row(
                children: [Expanded(child: _tinyStat('الحالة', user.status))],
              ),
              const SizedBox(height: 14),
              const Text(
                'الإجراءات السريعة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.7,
                children: [
                  _actionTile(
                    icon: Icons.shopping_bag_rounded,
                    title: 'طلباتي',
                    onTap: () => context.go(AppRoutePaths.orders),
                  ),
                  _actionTile(
                    icon: Icons.favorite_rounded,
                    title: 'المحفوظة',
                    onTap: () => context.go(AppRoutePaths.saved),
                  ),
                  _actionTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'الإشعارات',
                    onTap: () => context.go(AppRoutePaths.notifications),
                  ),
                  _actionTile(
                    icon: Icons.support_agent_rounded,
                    title: 'الدعم',
                    onTap: () => _openSupportActions(context),
                  ),
                  _actionTile(
                    icon: Icons.security_rounded,
                    title: 'أمان التطبيق',
                    onTap: () => context.push(AppRoutePaths.security),
                  ),
                  if (isAdmin)
                    _actionTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'لوحة الإدارة',
                      onTap: () => context.push(AppRoutePaths.admin),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _infoSection(
                title: 'بيانات التواصل',
                rows: [
                  _infoRow(
                    'البريد',
                    user.email.isEmpty ? 'غير محدد' : user.email,
                  ),
                  _infoRow(
                    'الهاتف',
                    user.phone.isEmpty ? 'غير محدد' : user.phone,
                  ),
                  _infoRow(
                    'العنوان',
                    user.address.isEmpty ? 'غير محدد' : user.address,
                  ),
                  _infoRow(
                    'المدينة',
                    user.city.isEmpty ? 'غير محدد' : user.city,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _infoSection(
                title: 'الحساب',
                rows: [
                  _infoRow('اسم المستخدم', user.username),
                  _infoRow('نوع الحساب', user.isGuest ? 'ضيف' : 'مستخدم'),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: () => context.push(AppRoutePaths.editProfile),
                child: const Text('تحديث البيانات'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  final cartCubit = context.read<CartCubit>();
                  final authCubit = context.read<AuthCubit>();
                  await cartCubit.clear();
                  await authCubit.logout();
                  if (!context.mounted) return;
                  context.go(AppRoutePaths.login);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B1F27),
                ),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildGuestFallback(
    BuildContext context, {
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: GlassStyle.acrylicDecoration(radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: GlassStyle.fireRed,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(AppRoutePaths.login),
                  child: const Text('تسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard({
    required String name,
    required String company,
    required String email,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          GlassStyle.acrylicDecoration(
            radius: 24,
            color: Colors.white.withValues(alpha: 0.92),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: GlassStyle.fireRed.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: GlassStyle.fireRed.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person,
              color: GlassStyle.fireRed,
              size: 36,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GlassStyle.darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (company.isNotEmpty)
                  Text(
                    company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GlassStyle.darkText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6E7585),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: GlassStyle.acrylicDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF707887),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isNotificationsTile = icon == Icons.notifications_active_rounded;

    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: GlassStyle.acrylicDecoration(radius: 14),
        child: Row(
          children: [
            if (isNotificationsTile)
              BlocBuilder<NotificationsBadgeCubit, int>(
                builder: (context, unreadCount) =>
                    _actionIcon(icon, badgeCount: unreadCount),
              )
            else
              _actionIcon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, {int badgeCount = 0}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: GlassStyle.fireRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: GlassStyle.fireRed),
        ),
        if (badgeCount > 0)
          PositionedDirectional(
            top: -6,
            end: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: GlassStyle.fireRed,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoSection({required String title, required List<Widget> rows}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF717988),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _openSupportActions(BuildContext context) async {
    final phone = _primarySupportPhone();
    final displayPhone = _normalizeDialPhone(phone);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.call_rounded),
                title: const Text('اتصال'),
                subtitle: Text(displayPhone),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchSupportUri(
                    context,
                    Uri(scheme: 'tel', path: displayPhone),
                    fallbackMessage:
                        'تعذر فتح الاتصال. رقم الدعم: $displayPhone',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded),
                title: const Text('واتساب'),
                subtitle: Text(displayPhone),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final whatsappPhone = _normalizeWhatsAppPhone(phone);
                  await _launchSupportUri(
                    context,
                    Uri.parse('https://wa.me/$whatsappPhone'),
                    mode: LaunchMode.externalApplication,
                    fallbackMessage:
                        'تعذر فتح واتساب. يمكنك التواصل على الرقم: $displayPhone',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('إلغاء'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchSupportUri(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    required String fallbackMessage,
  }) async {
    final opened = await launchUrl(uri, mode: mode);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fallbackMessage)));
    }
  }

  String _primarySupportPhone() {
    for (final phone in AppStaticData.contactPhones) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        return phone;
      }
    }
    return AppStaticData.contactPhones.first;
  }

  String _normalizeDialPhone(String raw) {
    final compact = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (compact.startsWith('00')) {
      return '+${compact.substring(2)}';
    }
    return compact;
  }

  String _normalizeWhatsAppPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 10) {
      digits = '963${digits.substring(1)}';
    }
    return digits;
  }
}

class _AccountSkeleton extends StatelessWidget {
  const _AccountSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      children: [
        const SkeletonBlock(height: 112),
        const SizedBox(height: 12),
        Row(children: const [Expanded(child: SkeletonBlock(height: 76))]),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.7,
          children: List.generate(4, (_) => const SkeletonBlock(height: 70)),
        ),
        const SizedBox(height: 12),
        const SkeletonBlock(height: 160),
        const SizedBox(height: 10),
        const SkeletonBlock(height: 120),
      ],
    );
  }
}
