import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/navigation/app_back_navigation.dart';

void main() {
  group('AppBackNavigation.resolveFallbackLocation', () {
    test('returns null for home root', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(
          Uri(path: AppRoutePaths.home),
        ),
        isNull,
      );
    });

    test('routes orders details back to orders list', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(
          Uri(path: AppRoutePaths.ordersDetails),
        ),
        AppRoutePaths.orders,
      );
    });

    test('routes orders list back to account', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(
          Uri(path: AppRoutePaths.orders),
        ),
        AppRoutePaths.account,
      );
    });

    test('routes checkout back to cart', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(
          Uri(path: AppRoutePaths.checkout),
        ),
        AppRoutePaths.cart,
      );
    });

    test('routes brand catalog back to brands', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(
          Uri(path: AppRoutePaths.catalog, queryParameters: {'type': 'brand'}),
        ),
        AppRoutePaths.brands,
      );
    });

    test('routes search entry catalog back to home', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(
          Uri(path: AppRoutePaths.catalog, queryParameters: {'focus': '1'}),
        ),
        AppRoutePaths.home,
      );
    });

    test('routes admin order details back to admin dashboard', () {
      expect(
        AppBackNavigation.resolveFallbackLocation(Uri(path: '/admin/order/25')),
        AppRoutePaths.admin,
      );
    });
  });
}
