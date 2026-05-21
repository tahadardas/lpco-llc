import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';

class CatalogVisibilityPolicy {
  const CatalogVisibilityPolicy._();

  static bool isVisibleBrand(BrandModel brand) {
    return !brand.hidden &&
        brand.showInApp &&
        brand.count > 0 &&
        brand.name.trim().isNotEmpty &&
        brand.slug.trim().isNotEmpty;
  }

  static bool isVisibleLeafCategory(CategoryModel category) {
    return isBaseVisibleCategory(category) && category.count > 0;
  }

  static bool isBaseVisibleCategory(CategoryModel category) {
    return !category.hidden &&
        category.showInApp &&
        category.name.trim().isNotEmpty;
  }

  static List<CategoryModel> visibleCategoryChildren(
    CategoryModel parent,
    List<CategoryModel> all,
  ) {
    return all
        .where((category) => category.parentId == parent.id)
        .where(isVisibleLeafCategory)
        .toList(growable: false);
  }

  static bool isVisibleParentCategory(
    CategoryModel parent,
    List<CategoryModel> visibleChildren,
  ) {
    return isBaseVisibleCategory(parent) &&
        (parent.count > 0 || visibleChildren.isNotEmpty);
  }
}
