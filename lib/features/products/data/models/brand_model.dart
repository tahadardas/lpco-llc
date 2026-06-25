import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/utils/image_url_normalizer.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';

class BrandModel {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String imageUrl;
  final List<int> linkedCategoryIds;
  final List<String> linkedCategorySlugs;
  final List<CategoryModel> linkedCategories;
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
    this.linkedCategories = const <CategoryModel>[],
    this.menuOrder = 0,
    this.showInApp = true,
    this.hidden = false,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    String resolveImage() {
      final candidates = <dynamic>[
        json['image'],
        json['image_url'],
        json['logo_url'],
        json['thumbnail_url'],
        json['brand_image'],
        json['brand_logo'],
        json['icon_url'],
        json['icon'],
        json['logo'],
        json['image_src'],
      ];

      for (final candidate in candidates) {
        final resolved = _resolveImageCandidate(candidate);
        if (resolved.isNotEmpty) {
          return resolved;
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[BRAND_IMAGE] missing image for brand '
          'id=${json['id']} slug=${json['slug']} keys=${json.keys.toList()}',
        );
      }
      return '';
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
      imageUrl: resolveImage(),
      linkedCategoryIds: _parseLinkedCategoryIds(json),
      linkedCategorySlugs: _parseLinkedCategorySlugs(json),
      linkedCategories: _parseLinkedCategories(json),
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

  static String _resolveImageCandidate(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is Map) {
      for (final key in const <String>[
        'src',
        'url',
        'image_url',
        'logo_url',
        'thumbnail_url',
        'brand_image',
        'brand_logo',
        'icon_url',
      ]) {
        final resolved = _resolveImageCandidate(value[key]);
        if (resolved.isNotEmpty) {
          return resolved;
        }
      }
      return '';
    }

    if (value is List) {
      for (final item in value) {
        final resolved = _resolveImageCandidate(item);
        if (resolved.isNotEmpty) {
          return resolved;
        }
      }
      return '';
    }

    final raw = TextSanitizer.fix(value).trim();
    if (raw.isEmpty) {
      return '';
    }
    if (int.tryParse(raw) != null && !raw.contains('/')) {
      return '';
    }

    return ImageUrlNormalizer.normalize(raw).trim();
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

  static List<CategoryModel> _parseLinkedCategories(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    if (rawCategories is! List) {
      return const <CategoryModel>[];
    }

    final categories = <CategoryModel>[];
    final seen = <int>{};
    for (final raw in rawCategories) {
      if (raw is! Map) {
        continue;
      }
      final category = CategoryModel.fromJson(Map<String, dynamic>.from(raw));
      if (category.id <= 0 || !seen.add(category.id)) {
        continue;
      }
      categories.add(category);
    }
    return categories;
  }
}
