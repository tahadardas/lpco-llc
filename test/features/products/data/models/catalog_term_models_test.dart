import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/home_banner_model.dart';

void main() {
  test('CategoryModel reads parent and parent_id', () {
    final parent = CategoryModel.fromJson(<String, dynamic>{
      'id': 10,
      'name': '\u0623\u0628',
      'slug': 'parent',
      'parent': '2',
      'count': 1,
      'image_url': '',
    });
    final parentId = CategoryModel.fromJson(<String, dynamic>{
      'id': 11,
      'name': '\u0641\u0631\u0639',
      'slug': 'child',
      'parent_id': 10,
      'count': 1,
      'image_url': '',
    });

    expect(parent.parentId, 2);
    expect(parentId.parentId, 10);
  });

  test('BrandModel reads linked category ids and slugs', () {
    final brand = BrandModel.fromJson(<String, dynamic>{
      'id': 4,
      'name': 'Brand',
      'slug': 'brand',
      'count': 2,
      'linked_category_ids': <dynamic>[7, '8'],
      'linked_category_slugs': <dynamic>['pens', 'paper'],
    });

    expect(brand.linkedCategoryIds, <int>[7, 8]);
    expect(brand.linkedCategorySlugs, <String>['pens', 'paper']);
  });

  test('HomeBannerSlideData reads action type and value', () {
    final slide = HomeBannerSlideData.fromJson(<String, dynamic>{
      'id': 'banner-1',
      'enabled': true,
      'image_id': 22,
      'image_url': 'https://example.test/banner.jpg',
      'action_type': 'internalRoute',
      'action_value': '/catalog',
      'starts_at': '2026-05-01T00:00:00Z',
      'ends_at': '2026-05-31T23:59:59Z',
    });

    expect(slide.actionType, AdminBannerActionType.internalRoute);
    expect(slide.actionValue, '/catalog');
    expect(slide.imageId, 22);
    expect(slide.startsAt, '2026-05-01T00:00:00Z');
    expect(slide.endsAt, '2026-05-31T23:59:59Z');
  });
}
