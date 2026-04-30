# LPCO LLC Mobile App

Production-intended Flutter B2B app for LPCO LLC, integrated with a custom
WordPress/WooCommerce API plugin under `/wp-json/dms/v1`.

## Scope

- Authentication and guest browsing
- Categories, brands, products, and unit-aware pricing
- Group pricing and multi-currency behavior
- Cart, checkout, orders, and invoice flows
- Arabic RTL-first UX

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Notifications

- Device tokens are registered to `/dms/v1/device/register` on app startup and
  when auth state changes.
- Notification API requests include `X-Device-Token` automatically when a token
  is available.
