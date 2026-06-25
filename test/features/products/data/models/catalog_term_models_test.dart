import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/config/app_config.dart';
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

  test('BrandModel normalizes fallback brand image keys', () {
    final brand = BrandModel.fromJson(<String, dynamic>{
      'id': 9,
      'name': 'Deli',
      'slug': 'deli',
      'count': 3,
      'brand_image': '/wp-content/uploads/2026/06/deli.png',
    });

    expect(
      brand.imageUrl,
      '${AppConfig.baseUrl}/wp-content/uploads/2026/06/deli.png',
    );
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

  test('HomeBannerSlideData preserves WordPress presentation controls', () {
    final slide = HomeBannerSlideData.fromJson(<String, dynamic>{
      'id': 'image-only',
      'enabled': true,
      'show_title': false,
      'show_subtitle': false,
      'show_button': false,
      'content_alignment': 'center',
      'content_vertical_alignment': 'bottom',
      'image_fit': 'contain',
      'overlay_opacity': 0,
      'title_color': '#112233',
      'subtitle_color': '#445566',
      'button_background_color': '#778899',
      'button_text_color': '#AABBCC',
    });

    expect(slide.showTitle, isFalse);
    expect(slide.showSubtitle, isFalse);
    expect(slide.showButton, isFalse);
    expect(slide.contentAlignment, 'center');
    expect(slide.contentVerticalAlignment, 'bottom');
    expect(slide.imageFit, 'contain');
    expect(slide.overlayOpacity, 0);
    expect(slide.toJson()['show_button'], isFalse);
  });

  test('HomeLayoutConfig reads ordered home product selections', () {
    final config = HomeLayoutConfig.fromJson(<String, dynamic>{
      'layout_config': <String, dynamic>{
        'slider_products': <dynamic>[3, '1', 2],
        'featured_products': <dynamic>[8, 5],
        'latest_products': <dynamic>[13, 11],
        'latest_mode': 'manual',
        'revision': 'layout-revision',
        'updated_at': '2026-06-20T12:00:00Z',
      },
      'sections': <dynamic>[
        <String, dynamic>{'type': 'banner'},
      ],
    });

    expect(config.sliderProductIds, <int>[3, 1, 2]);
    expect(config.featuredProductIds, <int>[8, 5]);
    expect(config.latestProductIds, <int>[13, 11]);
    expect(config.latestMode, 'manual');
    expect(config.revision, 'layout-revision');
    expect(config.sections, hasLength(1));
  });
}
