import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';

class AppBackNavigation {
  const AppBackNavigation._();

  static Future<bool> popOrGo(
    BuildContext context, {
    String? fallbackLocation,
  }) async {
    final router = GoRouter.of(context);
    final currentUri = GoRouterState.of(context).uri;
    final target = fallbackLocation ?? resolveFallbackLocation(currentUri);

    final navigator = Navigator.maybeOf(context);
    final canPopNavigator = navigator?.canPop() ?? false;

    if (canPopNavigator) {
      navigator!.pop();
      return true;
    }

    if (router.canPop()) {
      router.pop();
      return true;
    }

    if (target == null || target.trim().isEmpty) {
      final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
      final canPopRoot = rootNavigator?.canPop() ?? false;
      if (canPopRoot && rootNavigator != navigator) {
        await rootNavigator!.maybePop();
        return true;
      }
      return false;
    }

    final normalizedTarget = target.trim();
    final currentLocation = currentUri.toString();
    if (currentLocation != normalizedTarget) {
      context.go(normalizedTarget);
      return true;
    }

    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    final canPopRoot = rootNavigator?.canPop() ?? false;
    if (canPopRoot && rootNavigator != navigator) {
      await rootNavigator!.maybePop();
      return true;
    }
    return false;
  }

  static String? resolveFallbackLocation(Uri uri) {
    final path = uri.path;

    if (path == AppRoutePaths.home) {
      return null;
    }

    if (path == AppRoutePaths.ordersDetails) {
      return AppRoutePaths.orders;
    }

    if (path == AppRoutePaths.orders ||
        path == AppRoutePaths.notifications ||
        path == AppRoutePaths.jobs ||
        path == AppRoutePaths.contact ||
        path == AppRoutePaths.security) {
      return AppRoutePaths.account;
    }

    if (path == AppRoutePaths.checkout) {
      return AppRoutePaths.cart;
    }

    if (path == AppRoutePaths.catalog ||
        path == AppRoutePaths.categoriesCatalog ||
        path == AppRoutePaths.brandsCatalog) {
      final type = (uri.queryParameters['type'] ?? '').trim().toLowerCase();
      if (type == 'brand' || path == AppRoutePaths.brandsCatalog) {
        return AppRoutePaths.brands;
      }
      if (type == 'category' || path == AppRoutePaths.categoriesCatalog) {
        return AppRoutePaths.categories;
      }
      if (uri.queryParameters['focus'] == '1') {
        return AppRoutePaths.home;
      }
      return AppRoutePaths.categories;
    }

    if (path == AppRoutePaths.categories ||
        path == AppRoutePaths.brands ||
        path == AppRoutePaths.saved ||
        path == AppRoutePaths.cart ||
        path == AppRoutePaths.account) {
      return AppRoutePaths.home;
    }

    if (path == AppRoutePaths.admin) {
      return AppRoutePaths.account;
    }

    if (path.startsWith('${AppRoutePaths.admin}/module/') ||
        path.startsWith('${AppRoutePaths.admin}/order/')) {
      return AppRoutePaths.admin;
    }

    if (path == AppRoutePaths.product ||
        path.startsWith('/product/') ||
        path.startsWith('/product-by-id/')) {
      return AppRoutePaths.home;
    }

    if (path.startsWith('/category/')) {
      return AppRoutePaths.categories;
    }

    if (path.startsWith('/brand/')) {
      return AppRoutePaths.brands;
    }

    if (path == AppRoutePaths.login ||
        path == AppRoutePaths.register ||
        path == AppRoutePaths.scanner) {
      return AppRoutePaths.home;
    }

    return AppRoutePaths.home;
  }
}
