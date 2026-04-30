import 'package:flutter/material.dart';
import 'dart:developer' as dev;

/// A professional navigation observer that logs page transitions for debugging and analytics.
class AppNavigationObserver extends NavigatorObserver {
  AppNavigationObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation('PUSH', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigation('POP', route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logNavigation('REPLACE', newRoute);
    }
  }

  void _logNavigation(String action, Route<dynamic> route) {
    final settings = route.settings;
    
    // Attempt to extract path/name info from Page settings (GoRouter standard)
    // Using settings.name which GoRouter typically populates with the route path.
    final path = (settings is Page) ? (settings.name ?? 'unnamed') : (settings.name ?? 'unnamed');

    dev.log(
      '[$action] Navigation: $path',
      name: 'NAV_LOG',
      error: {
        'action': action,
        'path': path,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
