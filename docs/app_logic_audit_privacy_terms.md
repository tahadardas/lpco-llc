# Application Logic Audit: Privacy & Terms Implementation

## 1. App Startup Sequence
1. **`main.dart`**: Calls `WidgetsFlutterBinding.ensureInitialized()` and `bootstrap()`, then runs `LpcoWholesaleApp`.
2. **`bootstrap()`**: Initializes `StorageService` (Hive boxes, SharedPreferences, SecureStorage).
3. **`app.dart` (`LpcoWholesaleApp`)**:
   - Initializes core Cubits (`NetworkCubit`, `CartCubit`, `AuthCubit`, `ProductCubit`, `NotificationsBadgeCubit`).
   - Runs `_bootstrapRuntimeServices()` asynchronously for `ReachabilityService`, `SyncCoordinator`, Firebase, and PushNotifications.
   - Listens to `AuthCubit` to synchronize scopes (`guest` vs `user_*`) across services.
   - The `MaterialApp.router` builder manages overlays using a `Stack`:
     - Base `child` (GoRouter navigation shell).
     - Security overlays (`_FullScreenLockNavigator` for `AuthLocked` / `AuthSecuritySetupRequired`).
     - Wrapped inside `NetworkBannerWrapper` and `EasyLoading`.

## 2. Main Navigation Routes
- Routing is handled via `GoRouter` in `app_router.dart` and `app_routes.dart`.
- Includes typical routes: Home, Catalog, Cart, Account, and Product/Category specific routes.

## 3. Existing State Management Flow
- Heavy reliance on `Cubit` (Bloc pattern) for logic.
- Persistence via `StorageService` using a mix of `FlutterSecureStorage` (auth tokens, biometrics), `SharedPreferences` (preferences, scopes), and `Hive` (product caching, sync queue, settings).
- Scoped data access for `guest` vs authenticated `user`.

## 4. Risks Found
- **Routing collisions**: Using `GoRouter` redirects for the consent gate might interfere with deep links or existing auth redirects.
- **Overlay hierarchy**: Adding the consent gate as an overlay in `app.dart` is safest but must be ordered carefully so it doesn't obscure or get obscured by critical lock screens inappropriately. A sibling layer to `lockLayer` in the `app.dart` `Stack` is ideal.
- **Session state**: Consent state must be independent of auth state, meaning logging out should not reset consent.

## 5. Files That Must Not Be Touched
- `ProductCubit`, `ProductRepository`, `Catalog` fetching logic.
- `CartCubit`, cart reconciliation, and checkout logic.
- API endpoints and JSON serialization contracts.
- `SyncCoordinator` and offline cache behavior.

## 6. Exact Changes Implemented
- **Storage**: Add `LegalConsentService` to handle reading/writing the `legal_consent_version` to `StorageService.settingsBox`.
- **UI Screens**:
  - `PrivacyPolicyScreen` (`/privacy-policy`)
  - `TermsOfUseScreen` (`/terms-of-use`)
  - `LegalConsentScreen` (First-launch full-screen gate)
- **App Integration**: Update the `builder` inside `LpcoWholesaleApp` (`app.dart`) to overlay the `LegalConsentScreen` if the user hasn't accepted the current version.
- **Routing**: Register `/privacy-policy` and `/terms-of-use` in `app_router.dart`.
- **Account Settings**: Add links to the legal screens in the Account / Profile screen.

## 7. Manual Test Checklist
1. **Fresh install / cleared storage**:
   - App opens legal consent screen first.
   - "Continue" button disabled until checkbox checked.
   - Privacy Policy and Terms links open correctly.
   - After approval, app continues normally.
2. **Relaunch app**:
   - Consent screen does not appear again.
3. **Change consent version manually**:
   - Consent screen appears again.
4. **Guest mode vs Logged-in user**:
   - Consent works for both and does not cause logouts.
5. **Auth locked / security overlay**:
   - Legal consent does not break lock screen behavior.
6. **Offline**:
   - Consent screen and legal pages work without internet.
7. **Navigation**:
   - `/privacy-policy` and `/terms-of-use` work from Account menu.
8. **Product / Cart flow**:
   - No regressions.
9. **RTL / Arabic**:
   - Text is formatted properly and aligned RTL.
