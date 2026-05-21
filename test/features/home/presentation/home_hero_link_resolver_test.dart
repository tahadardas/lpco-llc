import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/features/home/presentation/screens/home_screen.dart';

void main() {
  test(
    'home hero link resolver supports product category brand search catalog',
    () {
      expect(homeHeroInternalRouteForLink('product:12'), '/product/12');
      expect(homeHeroInternalRouteForLink('category:8'), '/category/8');
      expect(
        homeHeroInternalRouteForLink('brand:Deli'),
        AppRoutePaths.brandUrl('deli'),
      );
      expect(
        homeHeroInternalRouteForLink('search:Pencil'),
        AppRoutePaths.searchUrl(query: 'pencil'),
      );
      expect(homeHeroInternalRouteForLink('catalog'), AppRoutePaths.catalog);
    },
  );
}
