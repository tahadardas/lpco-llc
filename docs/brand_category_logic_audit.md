# Brand/Category Logic Audit

## What Was Wrong

### 1. Misleading Count Display

The brand-scoped category menu showed `category.count` from WooCommerce as if it
were the brand-scoped count. For example, "أقلام رصاص (53)" appeared for Deli, but
only 1 pencil product actually belonged to Deli. The 53 was the **global** count
across all brands.

**Location**: `BrandScopedCategoryMenu._labelFor()` in
`lib/features/products/presentation/widgets/brand_scoped_category_menu.dart`

### 2. Hardcoded Config Mapped Generic Categories

`LocalBrandScopedCategoryMenuSource` in `brand_scoped_category_config.dart` contained
78 hardcoded mappings for 3 brands (Deli, Zero, Zidny). Many mapped generic category
slugs like `pencils`, `notebooks`, `calculators` to specific brands. These generic
categories have high global counts unrelated to the brand.

The dynamic `BrandCategoryLinker` (in `domain/brand_category_linker.dart`) correctly
uses slug-token matching that would NOT match `pencils` to `deli` (since `pencils`
does not contain a `deli` token). But the hardcoded config bypassed this safety.

### 3. Client-Side Over-Filtering

When the API request included both `brand_slug=deli` and `category=42`, the backend
already filtered correctly. But `_applyScopedFilters()` in `SearchFilterCubit`
re-filtered the results using a 4-tier client-side strategy (ID → slug → Arabic name
→ product name). If a product's `ProductCategoryRef` metadata was incomplete or
differently structured, valid products were discarded.

## Difference: Global vs Brand-Scoped Count

| Source | Meaning | Example |
|---|---|---|
| `CategoryModel.count` | Total products in this category across ALL brands | 53 |
| `CatalogResponseMeta.total` from `brand_slug=X&category=Y` | Products in category Y that belong to brand X | 1 |

## New Linking Rules

The `BrandCategoryLinker` uses this priority order:

1. **Explicit backend mapping** — `BrandModel.linkedCategoryIds` / `linkedCategorySlugs`
2. **Exact brand root** — `category.slug == brand.slug`
3. **Children of brand root** — categories whose `parentId` matches a brand root category
4. **Safe slug-token match** — `startsWith("brand-")`, `endsWith("-brand")`, `contains("-brand-")`
5. **Name-token match** — Arabic-normalized category name contains brand name
6. **Product-derived fallback** — categories found in actual brand products

The hardcoded config (`LocalBrandScopedCategoryMenuSource`) is kept as a legacy
fallback but is **not used** by default (`allowConfiguredFallback: false`).

## Backend Trust Strategy

When the API request includes both `brand_slug` AND `category` (primary path):
- The backend returns products already filtered by both
- The app trusts these results and only applies brand slug verification
- No 4-tier client-side category re-filtering

When the API returns empty and the app falls back to brand-only queries:
- The 4-tier category filter runs client-side
- Multi-page scanning (up to 50 pages) finds matching products

## Testing Checklist

- [x] Generic slugs (pencils, notebooks) do NOT match brands by slug token
- [x] Brand-prefixed slugs (deli-calculators) correctly match
- [x] Brand-suffixed slugs (thermal-laminating-machinesd-deli) correctly match
- [x] Unsafe substrings (del ≠ deli) do not match
- [x] Arabic name normalization (أ→ا, ة→ه, ى→ي) works
- [x] Product-derived category IDs are included as fallback
- [x] Backend explicit IDs/slugs take priority
- [x] Brand root children are included
- [x] Sorting: root first → menuOrder → name
- [x] Global count is never shown as brand-scoped count
- [x] Backend-confirmed brand+category results are not re-filtered
