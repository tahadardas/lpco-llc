# Brand Category Linking

## Why This Exists

Brand pages need to show categories that belong to the current WooCommerce brand, then keep products scoped by both the selected brand and selected category.

Example: opening brand `deli` can show `deli-calculators`, `deli-school-supplies`, and `thermal-laminating-machinesd-deli`. Tapping one of them must keep the `deli` brand filter active.

## Linking Rules

The Flutter app computes links from the latest cached or remote brands and categories. It also accepts optional backend fields when the WordPress plugin provides them.

Priority:

1. Backend-provided mappings on the brand:
   - `linked_category_ids`
   - `linked_category_slugs`
   - compatible `categories` or `app_categories` values
2. Exact category slug match with the brand slug, for example brand `deli` and category `deli`.
3. Direct children of the exact brand root category.
4. Safe slug token matches:
   - `deli-calculators`
   - `category-name-deli`
   - `my-deli-category`
5. Safe normalized name matches, for example category names that contain `دلي` or the Latin slug `deli` as a token.
6. Product-derived fallback category IDs from the local product index.

Unsafe substring matching is avoided. Brand `del` does not match category slug `deli-calculators`.

## WordPress Admin Naming Guidance

Keep the brand slug stable after products are live. For brand `deli`, good category slug patterns are:

- `deli-calculators`
- `deli-school-supplies`
- `deli-marker-pens`
- `category-name-deli`

Another supported structure is creating a parent product category with slug `deli`, then placing related categories directly under it.

Avoid changing brand or category slugs after the mobile app has cached catalog data unless the catalog cache is refreshed.

## Example Backend JSON

```json
{
  "id": 123,
  "name": "دلي",
  "slug": "deli",
  "linked_category_ids": [10, 11, 12],
  "linked_category_slugs": [
    "deli-calculators",
    "deli-school-supplies",
    "deli-marker-pens"
  ]
}
```

Flutter does not require these fields. If they are absent, the app computes links locally from category slugs, parent relationships, names, and product-derived category IDs.

## Empty State

If no linked categories are found, the linked-category section is hidden. The brand page still shows all products for the brand.

If a linked category is selected but no products match the brand/category combination, the catalog empty state shows that there are no products in this category for this brand.

## How To Test From Admin

1. Confirm the brand slug, for example `deli`.
2. Create or edit product categories using one of the supported slug patterns.
3. Assign products to the brand and the relevant categories.
4. Refresh catalog data in the app.
5. Open `/brand/deli`.
6. Confirm the linked category chips appear near the top.
7. Tap a category and confirm products remain filtered to both `brand_slug=deli` and the selected category.
8. Tap `الكل` to return to all products for the brand.
