# 🚀 COMPREHENSIVE DEVELOPMENT PROMPT
## تطوير تطبيق LPCO LLC - برومبت شامل للتحديث الكامل

---

## 🎯 MISSION STATEMENT

أنت مطور Flutter خبير متخصص في تطوير تطبيقات B2B عالية الجودة. مهمتك هي تحديث تطبيق LPCO LLC ليصبح تطبيقاً عصرياً، سريعاً، وذو تجربة مستخدم استثنائية مع التركيز على:

1. **تصميم UI/UX عصري وجذاب**
2. **أداء سريع ومحسّن**
3. **تجربة مستخدم سلسة**
4. **معايير تطوير عالمية**
5. **دعم كامل للغة العربية (RTL)**

---

## 📋 PHASE 1: Design System Overhaul
### المرحلة الأولى: إعادة بناء نظام التصميم

### ✅ **Task 1.1: Create AppColors Class**

```dart
/// lib/core/theme/app_colors.dart

class AppColors {
  // Prevent instantiation
  const AppColors._();
  
  // ============== PRIMARY COLORS ==============
  static const Color primaryRed = Color(0xFFD31225);
  static const Color primaryRedDark = Color(0xFFB00F1E);
  static const Color primaryRedLight = Color(0xFFFF4757);
  static const Color primaryRedLighter = Color(0xFFFF6B7A);
  
  // ============== SECONDARY COLORS ==============
  static const Color secondaryBlue = Color(0xFF1E40AF);
  static const Color secondaryGreen = Color(0xFF059669);
  static const Color secondaryAmber = Color(0xFFF59E0B);
  static const Color secondaryPurple = Color(0xFF7C3AED);
  
  // ============== NEUTRAL COLORS ==============
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
  static const Color neutralBlack = Color(0xFF000000);
  static const Color neutralWhite = Color(0xFFFFFFFF);
  
  // ============== SEMANTIC COLORS ==============
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF047857);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);
  
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);
  
  // ============== BACKGROUND COLORS ==============
  static const Color backgroundLight = Color(0xFFFAFBFC);
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2937);
  
  // ============== TEXT COLORS ==============
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  
  // ============== BORDER COLORS ==============
  static const Color borderLight = Color(0xFFE6EAF1);
  static const Color borderMedium = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF9CA3AF);
  
  // ============== GRADIENTS ==============
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, primaryRedLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient lightGradient = LinearGradient(
    colors: [Color(0xFFFAFBFC), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0xFFEBEBF4),
      Color(0xFFF4F4F4),
      Color(0xFFEBEBF4),
    ],
    stops: [0.1, 0.3, 0.4],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}
```

### ✅ **Task 1.2: Create AppTypography Class**

```dart
/// lib/core/theme/app_typography.dart

import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();
  
  static const String _fontFamily = 'Cairo';
  
  // ============== DISPLAY ==============
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w900,
    height: 1.12,
    letterSpacing: -0.25,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w800,
    height: 1.16,
    letterSpacing: 0,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: 0,
  );
  
  // ============== HEADINGS ==============
  static const TextStyle headingXLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0,
  );
  
  static const TextStyle headingLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.29,
    letterSpacing: 0,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.33,
    letterSpacing: 0,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0,
  );
  
  static const TextStyle headingXSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.44,
    letterSpacing: 0,
  );
  
  // ============== BODY ==============
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.15,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.25,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );
  
  // ============== LABELS ==============
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.43,
    letterSpacing: 0.1,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.33,
    letterSpacing: 0.5,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0.5,
  );
  
  // ============== BUTTON ==============
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.5,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.43,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.33,
    letterSpacing: 0.5,
  );
  
  // ============== CAPTION ==============
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );
  
  static const TextStyle overline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.6,
    letterSpacing: 1.5,
  );
}
```

### ✅ **Task 1.3: Create AppSpacing Class**

```dart
/// lib/core/theme/app_spacing.dart

class AppSpacing {
  const AppSpacing._();
  
  // ============== BASE UNIT ==============
  static const double unit = 4.0;
  
  // ============== SPACING SCALE ==============
  static const double xxs = unit * 0.5;   // 2px
  static const double xs = unit * 1;      // 4px
  static const double sm = unit * 2;      // 8px
  static const double md = unit * 3;      // 12px
  static const double lg = unit * 4;      // 16px
  static const double xl = unit * 5;      // 20px
  static const double xxl = unit * 6;     // 24px
  static const double xxxl = unit * 8;    // 32px
  static const double huge = unit * 12;   // 48px
  static const double massive = unit * 16; // 64px
  
  // ============== SEMANTIC SPACING ==============
  // Padding
  static const double cardPadding = lg;
  static const double cardPaddingLarge = xl;
  static const double sectionPadding = xxl;
  static const double screenPadding = lg;
  static const double screenPaddingHorizontal = lg;
  static const double screenPaddingVertical = xl;
  
  // Gaps
  static const double elementGap = md;
  static const double sectionGap = xxl;
  static const double listItemGap = sm;
  static const double chipGap = sm;
  
  // Margins
  static const double cardMargin = md;
  static const double buttonMargin = md;
  
  // Insets
  static const double buttonPaddingHorizontal = xl;
  static const double buttonPaddingVertical = md;
  static const double inputPaddingHorizontal = lg;
  static const double inputPaddingVertical = md;
  
  // Icon spacing
  static const double iconGap = sm;
  static const double iconPadding = sm;
}
```

### ✅ **Task 1.4: Create AppRadius Class**

```dart
/// lib/core/theme/app_radius.dart

import 'package:flutter/material.dart';

class AppRadius {
  const AppRadius._();
  
  // ============== RADIUS VALUES ==============
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double full = 999;
  
  // ============== SEMANTIC RADIUS ==============
  static const double card = lg;
  static const double cardLarge = xl;
  static const double button = md;
  static const double buttonLarge = lg;
  static const double input = md;
  static const double chip = full;
  static const double bottomSheet = xl;
  static const double dialog = xl;
  static const double image = md;
  static const double avatar = full;
  
  // ============== BORDER RADIUS ==============
  static const BorderRadius noneRadius = BorderRadius.zero;
  
  static const BorderRadius xsRadius = BorderRadius.all(
    Radius.circular(xs),
  );
  
  static const BorderRadius smRadius = BorderRadius.all(
    Radius.circular(sm),
  );
  
  static const BorderRadius mdRadius = BorderRadius.all(
    Radius.circular(md),
  );
  
  static const BorderRadius lgRadius = BorderRadius.all(
    Radius.circular(lg),
  );
  
  static const BorderRadius xlRadius = BorderRadius.all(
    Radius.circular(xl),
  );
  
  static const BorderRadius xxlRadius = BorderRadius.all(
    Radius.circular(xxl),
  );
  
  static const BorderRadius xxxlRadius = BorderRadius.all(
    Radius.circular(xxxl),
  );
  
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
  
  // ============== SEMANTIC BORDER RADIUS ==============
  static const BorderRadius cardRadius = lgRadius;
  static const BorderRadius cardLargeRadius = xlRadius;
  static const BorderRadius buttonRadius = mdRadius;
  static const BorderRadius buttonLargeRadius = lgRadius;
  static const BorderRadius inputRadius = mdRadius;
  static const BorderRadius chipRadius = fullRadius;
  static const BorderRadius bottomSheetRadius = xlRadius;
  static const BorderRadius dialogRadius = xlRadius;
  static const BorderRadius imageRadius = mdRadius;
  static const BorderRadius avatarRadius = fullRadius;
  
  // ============== TOP ONLY RADIUS ==============
  static const BorderRadius topMdRadius = BorderRadius.only(
    topLeft: Radius.circular(md),
    topRight: Radius.circular(md),
  );
  
  static const BorderRadius topLgRadius = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
  );
  
  static const BorderRadius topXlRadius = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
  
  static const BorderRadius topXxlRadius = BorderRadius.only(
    topLeft: Radius.circular(xxl),
    topRight: Radius.circular(xxl),
  );
  
  // ============== BOTTOM ONLY RADIUS ==============
  static const BorderRadius bottomMdRadius = BorderRadius.only(
    bottomLeft: Radius.circular(md),
    bottomRight: Radius.circular(md),
  );
  
  static const BorderRadius bottomLgRadius = BorderRadius.only(
    bottomLeft: Radius.circular(lg),
    bottomRight: Radius.circular(lg),
  );
  
  static const BorderRadius bottomXlRadius = BorderRadius.only(
    bottomLeft: Radius.circular(xl),
    bottomRight: Radius.circular(xl),
  );
  
  static const BorderRadius bottomXxlRadius = BorderRadius.only(
    bottomLeft: Radius.circular(xxl),
    bottomRight: Radius.circular(xxl),
  );
}
```

### ✅ **Task 1.5: Create AppShadows Class**

```dart
/// lib/core/theme/app_shadows.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  const AppShadows._();
  
  // ============== NEUTRAL SHADOWS ==============
  static const BoxShadow xs = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 2,
    offset: Offset(0, 1),
    spreadRadius: 0,
  );
  
  static const BoxShadow sm = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 4,
    offset: Offset(0, 1),
    spreadRadius: 0,
  );
  
  static const BoxShadow md = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
    spreadRadius: -1,
  );
  
  static const BoxShadow lg = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 16,
    offset: Offset(0, 4),
    spreadRadius: -2,
  );
  
  static const BoxShadow xl = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 24,
    offset: Offset(0, 8),
    spreadRadius: -4,
  );
  
  static const BoxShadow xxl = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 40,
    offset: Offset(0, 12),
    spreadRadius: -8,
  );
  
  // ============== COLORED SHADOWS ==============
  static const BoxShadow primary = BoxShadow(
    color: Color(0x40D31225),
    blurRadius: 16,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );
  
  static const BoxShadow primaryStrong = BoxShadow(
    color: Color(0x60D31225),
    blurRadius: 24,
    offset: Offset(0, 8),
    spreadRadius: 0,
  );
  
  static const BoxShadow success = BoxShadow(
    color: Color(0x4010B981),
    blurRadius: 16,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );
  
  static const BoxShadow warning = BoxShadow(
    color: Color(0x40F59E0B),
    blurRadius: 16,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );
  
  static const BoxShadow error = BoxShadow(
    color: Color(0x40EF4444),
    blurRadius: 16,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );
  
  // ============== SHADOW LISTS ==============
  static const List<BoxShadow> cardShadow = [md];
  static const List<BoxShadow> cardShadowHover = [lg];
  static const List<BoxShadow> buttonShadow = [sm];
  static const List<BoxShadow> buttonShadowHover = [md];
  static const List<BoxShadow> bottomNavShadow = [lg];
  static const List<BoxShadow> drawerShadow = [xl];
  static const List<BoxShadow> dialogShadow = [xxl];
  
  // ============== INNER SHADOWS (using multiple shadows) ==============
  static const List<BoxShadow> innerShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
      spreadRadius: -1,
    ),
  ];
}
```

### ✅ **Task 1.6: Create AppAnimations Class**

```dart
/// lib/core/theme/app_animations.dart

class AppAnimations {
  const AppAnimations._();
  
  // ============== DURATIONS ==============
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 700);
  static const Duration slowest = Duration(milliseconds: 1000);
  
  // ============== SEMANTIC DURATIONS ==============
  static const Duration pageTransition = medium;
  static const Duration dialogTransition = normal;
  static const Duration bottomSheetTransition = medium;
  static const Duration buttonPress = fast;
  static const Duration ripple = normal;
  static const Duration cardHover = fast;
  static const Duration tooltipFade = fast;
  static const Duration shimmer = slower;
  
  // ============== CURVES ==============
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve emphasizedDecelerate = Curves.easeOutCubic;
  static const Curve emphasizedAccelerate = Curves.easeInCubic;
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.elasticInOut;
  
  // ============== STAGGER DELAYS ==============
  static const Duration staggerShort = Duration(milliseconds: 50);
  static const Duration staggerMedium = Duration(milliseconds: 100);
  static const Duration staggerLong = Duration(milliseconds: 150);
}
```

---

## 📋 PHASE 2: Component Library
### المرحلة الثانية: بناء مكتبة المكونات

### ✅ **Task 2.1: Modern Bottom Navigation Bar**

```dart
/// lib/core/widgets/modern_bottom_nav.dart

import 'package:flutter/material.dart';
import 'package:lpco_llc/core/theme/app_colors.dart';
import 'package:lpco_llc/core/theme/app_shadows.dart';
import 'package:lpco_llc/core/theme/app_radius.dart';
import 'package:lpco_llc/core/theme/app_animations.dart';

class ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? cartBadgeCount;

  const ModernBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartBadgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.topXxlRadius,
        boxShadow: AppShadows.bottomNavShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'الرئيسية',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'الكتالوج',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.shopping_cart_outlined,
                activeIcon: Icons.shopping_cart_rounded,
                label: 'السلة',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
                badgeCount: cartBadgeCount,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'حسابي',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.smooth,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive 
                ? AppColors.primaryRed.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: AppRadius.lgRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: AppAnimations.fast,
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      color: isActive 
                          ? AppColors.primaryRed 
                          : AppColors.neutral500,
                      size: 24,
                    ),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badgeCount! > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: AppAnimations.fast,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive 
                      ? AppColors.primaryRed 
                      : AppColors.neutral500,
                  fontFamily: 'Cairo',
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### ✅ **Task 2.2: Enhanced App Drawer**

```dart
/// lib/core/widgets/enhanced_app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/core/theme/app_colors.dart';
import 'package:lpco_llc/core/theme/app_typography.dart';
import 'package:lpco_llc/core/theme/app_spacing.dart';
import 'package:lpco_llc/core/theme/app_radius.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';

class EnhancedAppDrawer extends StatelessWidget {
  const EnhancedAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1E25),
              Color(0xFF141821),
              Color(0xFF0F1218),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              _buildHeader(context),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: _buildMenuItems(context),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.read<AuthCubit>().currentUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Name
          Text(
            user?.displayName ?? 'زائر',
            style: AppTypography.headingSmall.copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Email or Role
          if (user?.email.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                user!.email,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          // Stats Row (optional)
          const SizedBox(height: AppSpacing.lg),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('12', 'الطلبات'),
          _buildDivider(),
          _buildStatItem('45', 'المفضلة'),
          _buildDivider(),
          _buildStatItem('380', 'النقاط'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.primaryRedLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      children: [
        _buildSectionTitle('التصفح'),
        _buildMenuItem(
          context,
          icon: Icons.home_rounded,
          label: 'الصفحة الرئيسية',
          route: AppRoutePaths.home,
        ),
        _buildMenuItem(
          context,
          icon: Icons.inventory_2_rounded,
          label: 'المنتجات',
          route: AppRoutePaths.categories,
        ),
        _buildMenuItem(
          context,
          icon: Icons.sell_rounded,
          label: 'العلامات التجارية',
          route: AppRoutePaths.brands,
        ),
        
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle('حسابي'),
        
        _buildMenuItem(
          context,
          icon: Icons.favorite_rounded,
          label: 'المنتجات المحفوظة',
          route: AppRoutePaths.saved,
          badge: 45, // Dynamic
        ),
        _buildMenuItem(
          context,
          icon: Icons.shopping_bag_rounded,
          label: 'الطلبات',
          route: AppRoutePaths.orders,
          badge: 3, // Dynamic
        ),
        _buildMenuItem(
          context,
          icon: Icons.notifications_active_rounded,
          label: 'الإشعارات',
          route: AppRoutePaths.notifications,
          badge: 7, // Dynamic
        ),
        _buildMenuItem(
          context,
          icon: Icons.person_rounded,
          label: 'إعدادات الحساب',
          route: AppRoutePaths.account,
        ),
        
        const SizedBox(height: AppSpacing.lg),
        _buildSectionTitle('المزيد'),
        
        _buildMenuItem(
          context,
          icon: Icons.work_rounded,
          label: 'الوظائف',
          route: AppRoutePaths.jobs,
        ),
        _buildMenuItem(
          context,
          icon: Icons.call_rounded,
          label: 'تواصل معنا',
          route: AppRoutePaths.contact,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
        top: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          color: Colors.white.withValues(alpha: 0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    int? badge,
  }) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isSelected = currentLocation == route || 
                      currentLocation.startsWith('$route/');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            context.go(route);
          },
          borderRadius: AppRadius.lgRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primaryRed.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryRed.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected 
                      ? AppColors.primaryRedLight 
                      : Colors.white.withValues(alpha: 0.7),
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white.withValues(alpha: 0.85),
                      fontWeight: isSelected 
                          ? FontWeight.w700 
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (badge != null && badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: AppRadius.chipRadius,
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Support Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Open support
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonLargeRadius,
                ),
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('الدعم الفني'),
            ),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Logout/Login Button
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLogged = state is Authenticated || 
                              state is GuestAuthenticated;
              
              return TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (isLogged) {
                    // Show logout confirmation dialog
                    _showLogoutDialog(context);
                  } else {
                    context.push(AppRoutePaths.login);
                  }
                },
                icon: Icon(
                  isLogged ? Icons.logout_rounded : Icons.login_rounded,
                  color: isLogged 
                      ? AppColors.error 
                      : AppColors.primaryRedLight,
                ),
                label: Text(
                  isLogged ? 'تسجيل الخروج' : 'تسجيل الدخول',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          
          // App Version
          const SizedBox(height: AppSpacing.xs),
          Text(
            'الإصدار 1.0.0',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthCubit>().logout();
              if (context.mounted) {
                context.go(AppRoutePaths.login);
              }
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
```

---

## 📋 PHASE 3: Screen Redesigns
### المرحلة الثالثة: إعادة تصميم الشاشات

### ✅ **Task 3.1: Modern Home Screen**

**المواصفات المطلوبة:**

1. **App Bar عصري:**
   - Logo في اليسار
   - Search icon
   - Scanner icon (FAB style)
   - Cart badge

2. **Hero Banner محسّن:**
   - Auto-playing carousel
   - Smooth transitions
   - Parallax effect
   - CTAs واضحة
   - Dots indicators

3. **Quick Actions:**
   - 4 action cards
   - Icons جذابة
   - Gradient backgrounds
   - Subtle animations

4. **Categories Section:**
   - Grid 2x3
   - Large images
   - Overlay text
   - Hover effects

5. **Featured Products:**
   - Horizontal carousel
   - Hero images
   - Quick actions (Add to cart, Save)
   - Smooth scrolling

6. **Deals Section:**
   - Special offers
   - Countdown timers
   - Limited badges

7. **Latest Products:**
   - Grid 2 columns
   - Infinite scroll
   - Pull to refresh

### ✅ **Task 3.2: Enhanced Product Card**

**المواصفات:**

```dart
/// lib/features/products/presentation/widgets/enhanced_product_card.dart

class EnhancedProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isGrid; // Grid or List mode
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onAddToCart;

  const EnhancedProductCard({
    super.key,
    required this.product,
    this.isGrid = true,
    required this.isSaved,
    required this.onTap,
    required this.onSave,
    required this.onAddToCart,
  });

  @override
  State<EnhancedProductCard> createState() => _EnhancedProductCardState();
}

// Features to implement:
// 1. Image with gradient overlay
// 2. Floating badges (New, Sale, Hot)
// 3. Heart save button with animation
// 4. Stock indicator
// 5. Price with original price struck through
// 6. Discount percentage
// 7. Rating stars (if available)
// 8. Quick add to cart button
// 9. Hero animation on tap
// 10. Ripple/Scale effect on press
// 11. Shimmer loading state
```

---

## 🎯 DEVELOPMENT GUIDELINES

### **Code Quality Standards:**

1. **Clean Architecture:**
   - Maintain separation of concerns
   - Feature-first organization
   - Clear dependency injection

2. **Performance:**
   - Use const constructors wherever possible
   - Implement proper dispose methods
   - Lazy loading for images
   - Debounce search inputs
   - Pagination for lists

3. **State Management:**
   - BLoC pattern consistently
   - Proper error handling
   - Loading states
   - Empty states

4. **Accessibility:**
   - Semantic labels
   - Touch targets 48x48+
   - Color contrast (WCAG AA)
   - Screen reader support

5. **Responsive Design:**
   - Handle different screen sizes
   - Tablet layouts where needed
   - Landscape orientation

6. **Animations:**
   - Use consistent durations
   - Respect reduced motion preferences
   - Smooth transitions
   - Micro-interactions

### **Testing Requirements:**

1. Unit tests for business logic
2. Widget tests for UI components
3. Integration tests for critical flows
4. Performance profiling

---

## 📦 DEPENDENCIES TO ADD

```yaml
# pubspec.yaml additions

dependencies:
  # Icons
  phosphor_flutter: ^2.1.0
  lucide_icons_flutter: ^1.0.0
  
  # Animations
  animate_do: ^3.3.4
  shimmer: ^3.0.0
  flutter_spinkit: ^5.2.1
  
  # UI Components
  salomon_bottom_bar: ^3.3.2
  flutter_slidable: ^3.1.1
  card_swiper: ^3.0.1
  
  # Better UX
  pull_to_refresh: ^2.0.0
  infinite_scroll_pagination: ^4.0.0
  
  # Utilities
  flutter_animate: ^4.5.0
  smooth_page_indicator: ^1.2.0
```

---

## 🚦 IMPLEMENTATION ROADMAP

### **Week 1: Design System**
- ✅ Create all design token classes
- ✅ Update AppTheme to use tokens
- ✅ Create reusable component library
- ✅ Setup animations library

### **Week 2: Navigation**
- ✅ Implement ModernBottomNav
- ✅ Implement EnhancedAppDrawer
- ✅ Add FAB for scanner
- ✅ Improve transitions

### **Week 3: Home Screen**
- ✅ Redesign Hero Banner
- ✅ Create Quick Actions
- ✅ Implement Categories Grid
- ✅ Enhanced Featured Products
- ✅ Deals Section

### **Week 4: Product Components**
- ✅ Enhanced Product Card
- ✅ Product Details Screen
- ✅ Quick View Dialog
- ✅ Image Gallery

### **Week 5: Cart & Checkout**
- ✅ Modern Cart Screen
- ✅ Improved Checkout Flow
- ✅ Payment UI
- ✅ Order Confirmation

### **Week 6: Polish & Optimization**
- ✅ Performance optimization
- ✅ Animation tuning
- ✅ Accessibility audit
- ✅ Testing
- ✅ Bug fixes

---

## 🎨 DESIGN INSPIRATION RESOURCES

### **مواقع للإلهام:**
- Dribbble (E-commerce designs)
- Behance (Mobile app designs)
- Mobbin (Real app screenshots)
- UI8 (Premium UI kits)

### **نماذج للتطبيقات:**
- Amazon Shopping
- Noon
- Namshi
- Careem/Talabat (for UX flow)
- Zara (for clean design)

---

## ✅ DELIVERABLES CHECKLIST

### **Phase 1: Design System ✓**
- [ ] AppColors class
- [ ] AppTypography class
- [ ] AppSpacing class
- [ ] AppRadius class
- [ ] AppShadows class
- [ ] AppAnimations class
- [ ] Updated AppTheme

### **Phase 2: Components ✓**
- [ ] ModernBottomNav
- [ ] EnhancedAppDrawer
- [ ] EnhancedProductCard
- [ ] ModernSearchBar
- [ ] CategoryCard
- [ ] BrandCard
- [ ] LoadingShimmer
- [ ] EmptyState
- [ ] ErrorState

### **Phase 3: Screens ✓**
- [ ] Modern Home Screen
- [ ] Enhanced Catalog Screen
- [ ] Product Details Screen
- [ ] Cart Screen
- [ ] Checkout Screen
- [ ] Orders Screen
- [ ] Account Screen

### **Phase 4: Polish ✓**
- [ ] Animations throughout
- [ ] Dark mode support
- [ ] Accessibility features
- [ ] Performance optimization
- [ ] Testing coverage
- [ ] Documentation

---

## 🔥 SUCCESS CRITERIA

### **Visual Quality:**
- ✓ Modern, cohesive design
- ✓ Smooth animations (60 FPS)
- ✓ Professional typography
- ✓ Consistent spacing
- ✓ Beautiful color palette

### **User Experience:**
- ✓ Intuitive navigation
- ✓ Fast loading (<2s initial)
- ✓ Clear feedback
- ✓ Error handling
- ✓ Accessibility compliance

### **Performance:**
- ✓ Smooth scrolling
- ✓ Fast search
- ✓ Efficient caching
- ✓ Small app size
- ✓ Battery efficient

### **Code Quality:**
- ✓ Clean architecture
- ✓ Well documented
- ✓ Tested
- ✓ Maintainable
- ✓ Scalable

---

## 💡 IMPLEMENTATION TIPS

1. **Start with Design Tokens:**
   - Don't skip this step
   - It makes everything easier later
   - Consistency is key

2. **Build Component Library First:**
   - Reusable components save time
   - Maintain consistency
   - Easier to update

3. **Test on Real Devices:**
   - Emulators don't show everything
   - Test on different screen sizes
   - Check animations on actual hardware

4. **Iterate Based on Feedback:**
   - Get user feedback early
   - A/B test important changes
   - Measure metrics

5. **Don't Forget Accessibility:**
   - It's not optional
   - Makes app better for everyone
   - Required for many markets

---

## 📞 SUPPORT & RESOURCES

### **Flutter Documentation:**
- https://flutter.dev/docs
- https://api.flutter.dev
- https://pub.dev

### **Design Resources:**
- https://m3.material.io (Material 3)
- https://developer.apple.com/design (iOS guidelines)
- https://inclusive-components.design

### **Arabic RTL Resources:**
- RTL testing tools
- Arabic typography best practices
- Cultural considerations

---

## 🎯 FINAL NOTES

هذا البرومبت شامل ومفصل لتطوير تطبيق LPCO LLC. يجب اتباع المراحل بالترتيب والتأكد من إكمال كل checklist قبل الانتقال للمرحلة التالية.

التركيز يجب أن يكون على:
1. **الجودة** قبل السرعة
2. **تجربة المستخدم** قبل الميزات
3. **الأداء** قبل التعقيد
4. **البساطة** قبل الزخرفة

**Good luck! 🚀**
