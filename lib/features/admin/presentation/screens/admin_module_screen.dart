import 'package:flutter/material.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_content_management_screens.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_diagnostics_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_members_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_notifications_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_products_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_reviews_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_settings_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:lpco_llc/features/admin/presentation/widgets/admin_module_widgets.dart';

class AdminModuleScreen extends StatelessWidget {
  const AdminModuleScreen({super.key, required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context) {
    switch (moduleId) {
      case 'orders':
        return const AdminOrdersScreen();
      case 'users':
        return const AdminUsersScreen();
      case 'members':
        return const AdminMembersScreen();
      case 'settings':
        return const AdminSettingsScreen();
      case 'diagnostics':
        return const AdminDiagnosticsScreen();
      case 'notifications':
        return const AdminNotificationsScreen();
      case 'home-banner':
        return const AdminHomeBannerScreen();
      case 'home-layout':
        return const AdminHomeLayoutScreen();
      case 'app-theme':
        return const AdminAppThemeScreen();
      case 'popup-config':
        return const AdminPopupConfigScreen();
      case 'products':
        return const AdminProductsScreen();
      case 'reviews':
        return const AdminReviewsScreen();
      case 'ordering':
        return const AdminOrderingScreen();
      default:
        return const AdminModuleScaffold(
          title: 'وحدة غير معروفة',
          body: AdminScreenEmpty(label: 'هذه الوحدة غير متاحة في هذه النسخة.'),
        );
    }
  }
}
