import 'package:flutter/material.dart';
import 'package:lpco_llc/core/theme/app_colors.dart';

class AppShadows {
  const AppShadows._();

  static const BoxShadow sm = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  static const BoxShadow md = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BoxShadow lg = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static const BoxShadow xl = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static const BoxShadow xxl = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 40,
    offset: Offset(0, 12),
  );

  static BoxShadow get primary => BoxShadow(
    color: AppColors.primaryRed.withValues(alpha: 0.30),
    blurRadius: 16,
    offset: const Offset(0, 4),
  );
}
