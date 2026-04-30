import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShellLayout {
  static const double navHeight = 66;
  static const double navHorizontalPadding = 12;
  static const double navTopPadding = 0;
  static const double navBottomSpacing = 0;

  static double systemBottomInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return math.max(mediaQuery.padding.bottom, mediaQuery.viewPadding.bottom);
  }

  static double navBottomInset(BuildContext context) {
    return systemBottomInset(context) + navBottomSpacing;
  }
}
