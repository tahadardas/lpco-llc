# Pre-Release App Logic Audit

## 1. App Startup Flow
- **Initialization:** App initializes `StorageService` (Hive and SecureStorage), `DioClient` for networking, and configures push notifications (`PushNotificationService`).
- **Data Preloading:** The app eagerly loads essential data (categories, brands, user profile, catalog layout) from the local cache to provide an instant, skeleton-free UI on first load.
- **Routing:** Deep links and initial paths are parsed by `go_router` in `AppRouter`. The initial entry point evaluates whether the user is a guest, an authenticated user, or if a legal consent screen is required first.

## 2. Auth / Guest / Session Flow
- **Guest Mode:** Non-logged-in users operate with a "guest session" managed via `scopeFor` which attaches a `guest: 1` flag to the API headers/query.
- **Authentication:** Logging in stores a JWT token via `FlutterSecureStorage`.
- **Session Expiration:** Dio interceptors capture 401/403 responses. If a token expires, the interceptor clears the session and forces the app back to guest mode or the login screen.

## 3. Product / Catalog / Category / Brand Flow
- **Display:** `ProductCubit` drives the main home layout, passing data to the UI.
- **Hierarchy:** Categories and brands are decoupled. The newly implemented `BrandCategoryLinker` handles dynamic mapping of generic categories to brands using backend IDs, slugs, and normalized Arabic tokens.
- **Filtering:** Filtering respects `brand_slug` and `category` ID simultaneously, deferring to the API's results when both are supplied, to prevent overly aggressive client-side clipping.

## 4. Cart / Checkout Flow
- **Offline First:** Cart items are cached locally. The app synchronizes them with the backend via `SyncCartCubit`.
- **Pricing:** Wholesale pricing and units (`Piece`, `Pack`, `Carton`) are strictly governed by the API response (`_dms_prices`). The app computes exact package selections dynamically, avoiding hardcoded currency conversions or fallback guesses.

## 5. Admin Modules Flow
- **Routing:** Admin endpoints (`/dms/v1/admin/*`) are protected. Access requires elevated privileges (Shop Manager/Admin).
- **Control Panel:** Settings like ordering, app theme, and popups are saved directly back to WordPress options and update the app's `updatedAt` timestamps.

## 6. Banner / Home-Layout Flow
- **Current State:** The backend API currently supports a single legacy banner (`/dms/v1/home-banner`).
- **Next Step:** Upgrading to a multi-banner carousel (`/dms/v1/home-banners`), requiring new API parsing that accommodates both lists and legacy object responses.

## 7. Cache Layers
- **Dio Cache:** Handled by `dio_cache_interceptor`, respecting `Cache-Control` max-age logic for GET requests.
- **Hive / Local Catalog:** `CatalogLocalStore` manages structured offline storage (`catalogBox`). It scopes keys by auth state (e.g., `idx_p_all::guest`).
- **Settings/Session Box:** Handles simple flags (legal consent, last app update, etc.).
- **In-Memory Cubit State:** Maintains immediate UI reactivity without awaiting IO.

## 8. Deep Link / Navigation Logic
- Supported schemes: `lpco://product/:id`, `lpco://category/:id`, `lpco://brand/:slug`, etc.
- External links are handled securely via `url_launcher`.
- `BannerActionResolver` (to be created) will unify deep linking from the new home banner system.

## 9. Current Risks Before Publishing
- Multi-banner structure requires careful API contract mapping. A backend 404 on the new multi-banner endpoint must gracefully fallback to the single-banner legacy API.
- Pull-to-refresh cache invalidation must propagate exactly to `CatalogLocalStore` and Dio Cache, or banners will appear "stuck".

## 10. Exact Changes Implemented (To Be Updated)
*(This section will be updated after the multi-banner implementation is finished)*

## 11. Manual Release Checklist
- [ ] Fresh installation works without crashes.
- [ ] Offline mode loads cached layout/products.
- [ ] Cart synchronizes correctly on reconnect.
- [ ] Guest vs. Auth state works correctly.
- [ ] Deep links navigate properly.
- [ ] New multi-banner UI renders correctly on home screen.
