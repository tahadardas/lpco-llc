# Backend Recommendations: Brand-Category Filtering

## Problem

`category.count` in WooCommerce is the **global** product count for a category across
all brands. When displayed inside a brand page it misleads users — e.g. "pencils (53)"
when only 1 pencil belongs to this brand.

The Flutter app currently hides the count to avoid showing incorrect numbers.
To show **accurate** brand-scoped counts, the backend should provide them.

## Recommended Endpoint

### Option A — Dedicated brand-category map

```
GET /dms/v1/brand-category-map?brand_slug=deli
```

Response:

```json
{
  "brand_slug": "deli",
  "categories": [
    {
      "id": 123,
      "name": "أقلام رصاص deli",
      "slug": "deli-pencils",
      "count": 3
    },
    {
      "id": 456,
      "name": "آلات حاسبة ديلي",
      "slug": "calculators",
      "count": 12
    }
  ]
}
```

`count` here is the number of products that belong to **both** the brand and the category.

### Option B — Extend `/dms/v1/brands` response

Add fields to each brand object:

```json
{
  "id": 99,
  "name": "Deli",
  "slug": "deli",
  "linked_category_ids": [123, 456],
  "linked_category_slugs": ["deli-pencils", "calculators"],
  "category_counts": {
    "123": 3,
    "456": 12
  }
}
```

The app already parses `linked_category_ids` and `linked_category_slugs` from the
brands API response. Adding `category_counts` would enable accurate display.

### Option C — Use existing products-plus envelope meta

The app can already call:

```
GET /dms/v1/products-plus?brand_slug=deli&category=123&per_page=1&envelope=1
```

And read `meta.total` from the response to get the brand-scoped count.
This works today but requires N API calls (one per category chip).
A batch endpoint (Option A) would be more efficient.

## Current App Behavior

- Brand-scoped category chips show category names **without** counts.
- The app can optionally call `getBrandCategoryProductCount()` per category if
  desired, but this is not enabled by default to avoid N extra API calls.
- When backend provides `linked_category_ids` or `linked_category_slugs` in the
  brands response, they take priority over heuristic slug/name matching.

## WooCommerce Category Slug Conventions

For the dynamic linker to auto-discover brand-category relationships, use these slug
patterns in WordPress:

| Pattern | Example | Match rule |
|---|---|---|
| `{brand}-{category}` | `deli-calculators` | startsWith "deli-" |
| `{category}-{brand}` | `thermal-laminating-machinesd-deli` | endsWith "-deli" |
| `{prefix}-{brand}-{suffix}` | `office-deli-pens` | contains "-deli-" |
| Exact brand slug | `deli` | exact match (brand root) |

Categories using these patterns are automatically linked to the brand without needing
explicit backend mapping.
