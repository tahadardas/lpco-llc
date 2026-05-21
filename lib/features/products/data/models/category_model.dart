import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final int parentId;
  final int count;
  final String imageUrl;
  final int menuOrder;
  final bool isFeatured;
  final bool showInApp;
  final bool hidden;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId = 0,
    required this.count,
    required this.imageUrl,
    this.menuOrder = 0,
    this.isFeatured = false,
    this.showInApp = true,
    this.hidden = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    String resolveImage() {
      final dynamic image = json['image'];
      if (image is Map) {
        return (image['src'] ?? image['url'] ?? '').toString();
      }

      return (json['image_url'] ??
              json['thumbnail_url'] ??
              json['thumbnail'] ??
              '')
          .toString();
    }

    return CategoryModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? json['term_id'] ?? ''}') ?? 0,
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
      parentId: json['parent'] is int
          ? json['parent'] as int
          : json['parent_id'] is int
          ? json['parent_id'] as int
          : int.tryParse('${json['parent'] ?? json['parent_id'] ?? '0'}') ?? 0,
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse('${json['count'] ?? '0'}') ?? 0,
      imageUrl: resolveImage().trim(),
      menuOrder: json['menu_order'] is int
          ? json['menu_order'] as int
          : int.tryParse('${json['menu_order'] ?? '0'}') ?? 0,
      isFeatured: _toBool(json['is_featured'] ?? json['featured']),
      showInApp: json.containsKey('show_in_app')
          ? _toBool(json['show_in_app'])
          : !_toBool(json['hidden']),
      hidden: json.containsKey('hidden')
          ? _toBool(json['hidden'])
          : (json.containsKey('show_in_app')
                ? !_toBool(json['show_in_app'])
                : false),
    );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = '$value'.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
}
