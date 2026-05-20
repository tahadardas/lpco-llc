# Cache Freshness Audit

## 1. All Cache Layers Found
- **Dio Cache**: Utilizes `HiveCacheStore` (`lpco_api_cache_v2`) with a maximum staleness of 12 hours. It applies `CachePolicy.refreshForceCache` by default.
- **Hive Boxes**: Various local boxes including `catalog_box`, `db_meta`, `sync_meta_box` (for catalog_revision), `cart_box`, `orders_box`, `settings_box` (for Home Banners), and `behavior_box`.
- **SharedPreferences**: Used primarily for primitive legacy settings, mostly superseded by Hive.
- **In-Memory Cubit State**: `ProductCubit` and `CategoriesCubit` keep loaded products, banners, and categories in memory while active.
- **Local Catalog Store**: `CatalogLocalStore` manages saving/reading of products, brands, and categories inside `catalog_box`.

## 2. Which Data is Cached
- **Products**: Cached locally per scope (user/guest) and per brand/category queries via `CatalogLocalStore`.
- **Categories**: Cached inside `catalog_box` with parent-child relationships and metadata.
- **Brands**: Cached inside `catalog_box`.
- **Home Banner / Layout**: Cached in `settings_box` (e.g., `home_banners_list_guest`, `home_banner_guest`).
- **App Settings / Admin-controlled Data**: Some API response structures (like `home-layout`) are parsed and mapped to banners.
- **Saved Products**: Cached in `behavior_box` (`saved_products_...`).
- **User / Session Data**: Cached in `FlutterSecureStorage` and `session_box`.

## 3. Which Cache Must be Preserved
- **Cart**: Must remain fully functional offline and untouched by content refreshes.
- **Auth / Session**: User tokens and auth state are critical and should never be dropped via content invalidation.
- **Saved Products**: User's wishlist/favorites.
- **Offline Orders / Outbox**: Any pending sync requests in `sync_queue_box` and `orders_box`.
- **User Security Settings**: App lock/PIN details.

## 4. Which Cache May be Refreshed / Invalidated Safely
- **Product Catalog**: Can be cleared when `catalog_revision` changes.
- **Categories**: Can be refreshed/replaced safely without data loss.
- **Brands**: Can be refreshed/replaced safely without data loss.
- **Home Banners**: Must be forcefully updated to reflect admin layout changes.
- **Home Layout / Admin-Controlled Display Settings**: Should refresh immediately when forced (Pull-to-refresh).

## 5. Existing Invalidation Weaknesses
- **Stale Dio Cache**: Dio's cache layer doesn't bypass itself on `pull-to-refresh` for admin content. It requires `CachePolicy.noCache` or a timestamp `_t` query parameter to bypass `refreshForceCache`.
- **Aggressive Local Banner Cache**: `ProductRepository.getCachedHomeBannersData()` and `getHomeBannerData()` can persist old banners. There's no clear timestamp or remote flag that proactively deletes a banner if an admin disables it.
- **No Force-Refresh Param**: Refreshing `ProductCubit` or `CategoriesCubit` just calls `getProducts()` or `getCategories()`, which hit the repository, which often resolves via HTTP caching or local store without aggressively seeking new content.
- **Ignored Disabled States**: If a banner or category is disabled from the admin side, the local app cache might just keep showing it because the remote response simply omits the item, and the app doesn't do a full destructive replace on its cache gracefully for banners.

## 6. Exact Changes Implemented
*(To be populated after execution)*

## 7. Manual Test Checklist
*(To be populated after execution)*
