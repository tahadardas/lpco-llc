import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class BrandModel {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String imageUrl;
  final List<int> linkedCategoryIds;
  final List<String> linkedCategorySlugs;
  final int menuOrder;
  final bool showInApp;
  final bool hidden;

  const BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    required this.imageUrl,
    this.linkedCategoryIds = const <int>[],
    this.linkedCategorySlugs = const <String>[],
    this.menuOrder = 0,
    this.showInApp = true,
    this.hidden = false,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    String resolveImage() {
      final dynamic image = json['image'];
      if (image is Map) {
        return (image['src'] ?? image['url'] ?? '').toString();
      }

      return (json['image_url'] ??
              json['logo_url'] ??
              json['thumbnail_url'] ??
              '')
          .toString();
    }

    return BrandModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse('${json['count'] ?? '0'}') ?? 0,
      imageUrl: resolveImage().trim(),
      linkedCategoryIds: _parseLinkedCategoryIds(json),
      linkedCategorySlugs: _parseLinkedCategorySlugs(json),
      menuOrder: json['menu_order'] is int
          ? json['menu_order'] as int
          : int.tryParse('${json['menu_order'] ?? 0}') ?? 0,
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

  static List<int> _parseLinkedCategoryIds(Map<String, dynamic> json) {
    final ids = <int>{};

    void add(dynamic value) {
      if (value is int) {
        if (value > 0) ids.add(value);
        return;
      }
      if (value is num) {
        final parsed = value.toInt();
        if (parsed > 0) ids.add(parsed);
        return;
      }
      final parsed = int.tryParse('${value ?? ''}'.trim());
      if (parsed != null && parsed > 0) {
        ids.add(parsed);
      }
    }

    void read(dynamic value) {
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            add(item['id'] ?? item['term_id'] ?? item['category_id']);
          } else {
            add(item);
          }
        }
        return;
      }
      add(value);
    }

    read(json['linked_category_ids']);
    read(json['categories']);
    read(json['app_categories']);

    return ids.toList(growable: false);
  }

  static List<String> _parseLinkedCategorySlugs(Map<String, dynamic> json) {
    final slugs = <String>{};

    void add(dynamic value) {
      final normalized = TextSanitizer.fix(value).trim();
      if (normalized.isNotEmpty && int.tryParse(normalized) == null) {
        slugs.add(normalized);
      }
    }

    void read(dynamic value) {
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            add(item['slug'] ?? item['category_slug']);
          } else {
            add(item);
          }
        }
        return;
      }
      add(value);
    }

    read(json['linked_category_slugs']);
    read(json['categories']);
    read(json['app_categories']);

    return slugs.toList(growable: false);
  }
}
