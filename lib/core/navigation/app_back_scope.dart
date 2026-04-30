import 'package:flutter/material.dart';

import 'package:lpco_llc/core/navigation/app_back_navigation.dart';

class AppBackScope extends StatelessWidget {
  final Widget child;
  final String? fallbackLocation;

  const AppBackScope({super.key, required this.child, this.fallbackLocation});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        AppBackNavigation.popOrGo(context, fallbackLocation: fallbackLocation);
      },
      child: child,
    );
  }
}
