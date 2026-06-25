import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';

class HomeBannerSlideData {
  final String id;
  final bool enabled;
  final int imageId;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final AdminBannerActionType actionType;
  final String actionValue;
  final String buttonLink;
  final int sortOrder;
  final String startsAt;
  final String endsAt;
  final List<int> productIds;
  final String updatedAt;
  final bool showTitle;
  final bool showSubtitle;
  final bool showButton;
  final String contentAlignment;
  final String contentVerticalAlignment;
  final String imageFit;
  final int overlayOpacity;
  final String titleColor;
  final String subtitleColor;
  final String buttonBackgroundColor;
  final String buttonTextColor;

  const HomeBannerSlideData({
    required this.id,
    required this.enabled,
    required this.imageId,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.actionType,
    required this.actionValue,
    required this.buttonLink,
    required this.sortOrder,
    required this.startsAt,
    required this.endsAt,
    required this.productIds,
    required this.updatedAt,
    this.showTitle = true,
    this.showSubtitle = true,
    this.showButton = true,
    this.contentAlignment = 'start',
    this.contentVerticalAlignment = 'center',
    this.imageFit = 'cover',
    this.overlayOpacity = 60,
    this.titleColor = '#FFFFFF',
    this.subtitleColor = '#FFFFFF',
    this.buttonBackgroundColor = '#D31225',
    this.buttonTextColor = '#FFFFFF',
  });

  factory HomeBannerSlideData.fromJson(Map<String, dynamic> json) {
    AdminBannerActionType parseAction(String val) {
      final v = val.toLowerCase().trim();
      switch (v) {
        case 'category':
          return AdminBannerActionType.category;
        case 'brand':
          return AdminBannerActionType.brand;
        case 'product':
          return AdminBannerActionType.product;
        case 'search':
          return AdminBannerActionType.search;
        case 'internalroute':
        case 'internal_route':
          return AdminBannerActionType.internalRoute;
        case 'externalurl':
        case 'external_url':
          return AdminBannerActionType.externalUrl;
        default:
          return AdminBannerActionType.none;
      }
    }

    final bool isEnabled = json.containsKey('enabled')
        ? (json['enabled'] == true || '${json['enabled']}' == '1')
        : true;

    return HomeBannerSlideData(
      id: TextSanitizer.fix(json['id']),
      enabled: isEnabled,
      imageId: int.tryParse('${json['image_id'] ?? 0}') ?? 0,
      imageUrl: TextSanitizer.fix(json['image_url'] ?? json['image']),
      title: TextSanitizer.fix(json['title']),
      subtitle: TextSanitizer.fix(json['subtitle']),
      buttonLabel: TextSanitizer.fix(json['button_label']),
      actionType: parseAction(json['action_type'] ?? ''),
      actionValue: TextSanitizer.fix(json['action_value']),
      buttonLink: TextSanitizer.fix(json['button_link'] ?? json['link']),
      sortOrder: int.tryParse('${json['sort_order'] ?? json['order']}') ?? 0,
      startsAt: TextSanitizer.fix(json['starts_at']),
      endsAt: TextSanitizer.fix(json['ends_at']),
      productIds: ((json['product_ids'] as List?) ?? const <dynamic>[])
          .map((e) => int.tryParse('$e') ?? 0)
          .where((id) => id > 0)
          .toList(),
      updatedAt: TextSanitizer.fix(json['updated_at']),
      showTitle: _toBool(json, 'show_title', fallback: true),
      showSubtitle: _toBool(json, 'show_subtitle', fallback: true),
      showButton: _toBool(json, 'show_button', fallback: true),
      contentAlignment: _choice(json['content_alignment'], const <String>{
        'start',
        'center',
        'end',
      }, 'start'),
      contentVerticalAlignment: _choice(
        json['content_vertical_alignment'],
        const <String>{'top', 'center', 'bottom'},
        'center',
      ),
      imageFit: _choice(json['image_fit'], const <String>{
        'cover',
        'contain',
      }, 'cover'),
      overlayOpacity: (int.tryParse('${json['overlay_opacity'] ?? 60}') ?? 60)
          .clamp(0, 100),
      titleColor: TextSanitizer.fix(json['title_color'] ?? '#FFFFFF'),
      subtitleColor: TextSanitizer.fix(json['subtitle_color'] ?? '#FFFFFF'),
      buttonBackgroundColor: TextSanitizer.fix(
        json['button_background_color'] ?? '#D31225',
      ),
      buttonTextColor: TextSanitizer.fix(
        json['button_text_color'] ?? '#FFFFFF',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    String actionString() {
      switch (actionType) {
        case AdminBannerActionType.none:
          return 'none';
        case AdminBannerActionType.category:
          return 'category';
        case AdminBannerActionType.brand:
          return 'brand';
        case AdminBannerActionType.product:
          return 'product';
        case AdminBannerActionType.search:
          return 'search';
        case AdminBannerActionType.internalRoute:
          return 'internalRoute';
        case AdminBannerActionType.externalUrl:
          return 'externalUrl';
      }
    }

    return <String, dynamic>{
      'id': id,
      'enabled': enabled,
      'image_id': imageId,
      'image_url': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'button_label': buttonLabel,
      'action_type': actionString(),
      'action_value': actionValue,
      'button_link': buttonLink,
      'sort_order': sortOrder,
      'starts_at': startsAt,
      'ends_at': endsAt,
      'product_ids': productIds,
      'updated_at': updatedAt,
      'show_title': showTitle,
      'show_subtitle': showSubtitle,
      'show_button': showButton,
      'content_alignment': contentAlignment,
      'content_vertical_alignment': contentVerticalAlignment,
      'image_fit': imageFit,
      'overlay_opacity': overlayOpacity,
      'title_color': titleColor,
      'subtitle_color': subtitleColor,
      'button_background_color': buttonBackgroundColor,
      'button_text_color': buttonTextColor,
    };
  }

  static bool _toBool(
    Map<String, dynamic> json,
    String key, {
    required bool fallback,
  }) {
    if (!json.containsKey(key)) return fallback;
    final value = json[key];
    if (value is bool) return value;
    return const <String>{
      '1',
      'true',
      'yes',
      'on',
    }.contains('$value'.trim().toLowerCase());
  }

  static String _choice(dynamic value, Set<String> allowed, String fallback) {
    final normalized = '$value'.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
  }
}

class HomeLayoutConfig {
  final List<int> sliderProductIds;
  final List<int> featuredProductIds;
  final List<int> latestProductIds;
  final String latestMode;
  final List<Map<String, dynamic>> sections;
  final String revision;
  final String updatedAt;

  const HomeLayoutConfig({
    this.sliderProductIds = const <int>[],
    this.featuredProductIds = const <int>[],
    this.latestProductIds = const <int>[],
    this.latestMode = 'auto',
    this.sections = const <Map<String, dynamic>>[],
    this.revision = '',
    this.updatedAt = '',
  });

  factory HomeLayoutConfig.fromJson(Map<String, dynamic> json) {
    final config = Map<String, dynamic>.from(
      (json['layout_config'] as Map?) ?? const <String, dynamic>{},
    );
    List<int> ids(String key) => ((config[key] as List?) ?? const <dynamic>[])
        .map((value) => int.tryParse('$value') ?? 0)
        .where((id) => id > 0)
        .toList(growable: false);
    return HomeLayoutConfig(
      sliderProductIds: ids('slider_products'),
      featuredProductIds: ids('featured_products'),
      latestProductIds: ids('latest_products'),
      latestMode: '${config['latest_mode'] ?? 'auto'}'.toLowerCase() == 'manual'
          ? 'manual'
          : 'auto',
      sections: ((json['sections'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      revision: TextSanitizer.fix(config['revision'] ?? json['revision']),
      updatedAt: TextSanitizer.fix(config['updated_at'] ?? json['updated_at']),
    );
  }
}
