import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primaryRed = Color(0xFFD31225);
  static const Color primaryRedDark = Color(0xFFB00F1E);
  static const Color primaryRedLight = Color(0xFFFF4757);

  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color secondaryGreen = Color(0xFF059669);
  static const Color secondaryAmber = Color(0xFFF59E0B);

  static const Color neutral50 = Color(0xFFFAFBFC);
  static const Color neutral100 = Color(0xFFF4F5F7);
  static const Color neutral200 = Color(0xFFE6EAF1);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[primaryRed, primaryRedLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: <Color>[Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
