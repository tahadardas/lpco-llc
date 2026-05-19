# LPCO LLC Mobile App

Production-intended Flutter B2B app for LPCO LLC, integrated with a custom
WordPress/WooCommerce API plugin under `/wp-json/dms/v1`.

## Scope

- Authentication and guest browsing
- Categories, brands, products, and unit-aware pricing
- Group pricing and multi-currency behavior
- Cart, checkout, orders, and invoice flows
- Arabic RTL-first UX

## Development Setup

Follow these simple steps to set up and run the application locally:

### 1. Prerequisites
- Ensure you have the Flutter SDK installed (stable channel).
- Ensure your target emulator or physical device is connected.

### 2. Signing Configuration (Android)
- The production signing keystores and passwords are kept secure and excluded from the repository.
- To configure local signing, copy `android/key.properties.example` to `android/key.properties`:
  ```bash
  cp android/key.properties.example android/key.properties
  ```
- Update `android/key.properties` with your local keystore path, alias, and passwords.

### 3. Fetch Dependencies
Install the package dependencies by running:
```bash
flutter pub get
```

### 4. Code Quality & Tests
Run static analysis and tests to ensure everything is correct:
```bash
flutter analyze
flutter test
```

### 5. Running the App
Run the application on your connected device:
```bash
flutter run
```


## Notifications

- Device tokens are registered to `/dms/v1/device/register` on app startup and
  when auth state changes.
- Notification API requests include `X-Device-Token` automatically when a token
  is available.
