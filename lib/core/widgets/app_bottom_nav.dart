import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final index = _indexForRoute(currentRoute);
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_rounded),
        label: TextSanitizer.fix('الرئيسية'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.grid_view_rounded),
        label: TextSanitizer.fix('التصنيفات'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.favorite_border_rounded),
        label: TextSanitizer.fix('المفضلة'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.sell_rounded),
        label: TextSanitizer.fix('العلامات'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_cart_checkout_rounded),
        label: TextSanitizer.fix('السلة'),
      ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A111827),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        currentIndex: index,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedItemColor: const Color(0xFFD31225),
        unselectedItemColor: const Color(0xFF8B909A),
        onTap: (value) {
          switch (value) {
            case 0:
              context.go(AppRoutePaths.home);
              break;
            case 1:
              context.go(AppRoutePaths.categories);
              break;
            case 2:
              context.go(AppRoutePaths.saved);
              break;
            case 3:
              context.go(AppRoutePaths.brands);
              break;
            case 4:
              context.go(AppRoutePaths.cart);
              break;
          }
        },
        items: items,
      ),
    );
  }

  int _indexForRoute(String route) {
    if (route.startsWith(AppRoutePaths.categories)) return 1;
    if (route.startsWith(AppRoutePaths.saved)) return 2;
    if (route.startsWith(AppRoutePaths.brands)) return 3;
    if (route.startsWith(AppRoutePaths.cart) ||
        route.startsWith(AppRoutePaths.checkout)) {
      return 4;
    }
    return 0;
  }
}
