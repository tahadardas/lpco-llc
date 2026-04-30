import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class BrandModel {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String imageUrl;

  const BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    required this.imageUrl,
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
    );
  }
}
