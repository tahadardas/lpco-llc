import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';

class HomeBannerSlideData {
  final String id;
  final bool enabled;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final AdminBannerActionType actionType;
  final String actionValue;
  final String buttonLink;
  final int sortOrder;
  final List<int> productIds;
  final String updatedAt;

  const HomeBannerSlideData({
    required this.id,
    required this.enabled,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.actionType,
    required this.actionValue,
    required this.buttonLink,
    required this.sortOrder,
    required this.productIds,
    required this.updatedAt,
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
      imageUrl: TextSanitizer.fix(json['image_url'] ?? json['image']),
      title: TextSanitizer.fix(json['title']),
      subtitle: TextSanitizer.fix(json['subtitle']),
      buttonLabel: TextSanitizer.fix(json['button_label']),
      actionType: parseAction(json['action_type'] ?? ''),
      actionValue: TextSanitizer.fix(json['action_value']),
      buttonLink: TextSanitizer.fix(json['button_link'] ?? json['link']),
      sortOrder: int.tryParse('${json['sort_order'] ?? json['order']}') ?? 0,
      productIds: ((json['product_ids'] as List?) ?? const <dynamic>[])
          .map((e) => int.tryParse('$e') ?? 0)
          .where((id) => id > 0)
          .toList(),
      updatedAt: TextSanitizer.fix(json['updated_at']),
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
      'image_url': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'button_label': buttonLabel,
      'action_type': actionString(),
      'action_value': actionValue,
      'button_link': buttonLink,
      'sort_order': sortOrder,
      'product_ids': productIds,
      'updated_at': updatedAt,
    };
  }
}
