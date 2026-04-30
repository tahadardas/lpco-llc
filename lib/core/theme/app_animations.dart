import 'package:flutter/material.dart';

class AppAnimations {
  const AppAnimations._();

  static const Duration none = Duration.zero;
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve smooth = Curves.easeOutCubic;
  static const Curve smoothIn = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  static Duration resolveDuration(BuildContext context, Duration preferred) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final disableAnimations = mediaQuery?.disableAnimations ?? false;
    if (disableAnimations) {
      return none;
    }
    return preferred;
  }
}
