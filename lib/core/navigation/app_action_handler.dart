import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lpco_llc/app/router/app_routes.dart';

class AppActionHandler {
  const AppActionHandler._();

  static Future<bool> handle(
    BuildContext context, {
    required String actionType,
    required String actionValue,
    String fallbackLink = '',
  }) async {
    final type = actionType.trim().toLowerCase().replaceAll('_', '');
    final value = actionValue.trim();

    switch (type) {
      case '':
      case 'none':
        if (fallbackLink.trim().isNotEmpty) {
          return openLegacyLink(context, fallbackLink);
        }
        return true;
      case 'category':
        final id = int.tryParse(value);
        if (id != null && id > 0) {
          context.push(AppRoutePaths.categoryUrl(id));
          return true;
        }
        break;
      case 'brand':
        if (value.isNotEmpty) {
          context.push(AppRoutePaths.brandUrl(value));
          return true;
        }
        break;
      case 'product':
        final id = int.tryParse(value);
        if (id != null && id > 0) {
          context.push(AppRoutePaths.productUrl(id));
          return true;
        }
        break;
      case 'search':
        if (value.isNotEmpty) {
          context.push(AppRoutePaths.searchUrl(query: value));
          return true;
        }
        break;
      case 'orders':
        context.push(AppRoutePaths.orders);
        return true;
      case 'cart':
        context.push(AppRoutePaths.cart);
        return true;
      case 'account':
        context.push(AppRoutePaths.account);
        return true;
      case 'notifications':
        context.push(AppRoutePaths.notifications);
        return true;
      case 'internalroute':
        final route = value.startsWith('/') ? value : '/$value';
        if (_isSafeInternalRoute(route)) {
          context.push(route);
          return true;
        }
        break;
      case 'externalurl':
      case 'url':
        final uri = Uri.tryParse(value);
        if (uri != null &&
            (uri.scheme.toLowerCase() == 'https' ||
                uri.scheme.toLowerCase() == 'http')) {
          return launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
    }

    _showInvalidAction(context);
    return false;
  }

  static Future<bool> openLegacyLink(
    BuildContext context,
    String rawLink,
  ) async {
    final link = rawLink.trim();
    final internalRoute = internalRouteForLegacyLink(link);
    if (internalRoute != null) {
      context.push(internalRoute);
      return true;
    }

    final uri = Uri.tryParse(link);
    if (uri != null &&
        (uri.scheme.toLowerCase() == 'https' ||
            uri.scheme.toLowerCase() == 'http')) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    _showInvalidAction(context);
    return false;
  }

  static String? internalRouteForLegacyLink(String rawLink) {
    final link = rawLink.trim();
    final lower = link.toLowerCase();
    if (lower.startsWith('product:')) {
      final id = int.tryParse(lower.replaceFirst('product:', ''));
      return id == null || id <= 0 ? null : AppRoutePaths.productUrl(id);
    }
    if (lower.startsWith('category:')) {
      final id = int.tryParse(lower.replaceFirst('category:', ''));
      return id == null || id <= 0 ? null : AppRoutePaths.categoryUrl(id);
    }
    if (lower.startsWith('brand:')) {
      final slug = lower.substring(lower.indexOf(':') + 1).trim();
      return slug.isEmpty ? null : AppRoutePaths.brandUrl(slug);
    }
    if (lower.startsWith('search:')) {
      final query = lower.substring(lower.indexOf(':') + 1).trim();
      return query.isEmpty ? null : AppRoutePaths.searchUrl(query: query);
    }

    switch (lower) {
      case 'catalog':
        return AppRoutePaths.catalog;
      case 'categories':
        return AppRoutePaths.categories;
      case 'brands':
        return AppRoutePaths.brands;
      case 'cart':
        return AppRoutePaths.cart;
      case 'account':
        return AppRoutePaths.account;
      case 'orders':
        return AppRoutePaths.orders;
      case 'notifications':
        return AppRoutePaths.notifications;
      default:
        return _isSafeInternalRoute(link) ? link : null;
    }
  }

  static bool _isSafeInternalRoute(String route) {
    final value = route.trim();
    return value.startsWith('/') &&
        !value.startsWith('//') &&
        !value.contains('://');
  }

  static void _showInvalidAction(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          '\u062a\u0639\u0630\u0631 \u0641\u062a\u062d \u0647\u0630\u0627 \u0627\u0644\u0631\u0627\u0628\u0637. \u064a\u0631\u062c\u0649 \u0645\u0631\u0627\u062c\u0639\u0629 \u0625\u0639\u062f\u0627\u062f \u0627\u0644\u0625\u062c\u0631\u0627\u0621.',
        ),
      ),
    );
  }
}
