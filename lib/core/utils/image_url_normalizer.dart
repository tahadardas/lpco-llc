import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class ImageUrlNormalizer {
  const ImageUrlNormalizer._();

  static String normalize(dynamic value) {
    var url = TextSanitizer.fix(value).trim();
    if (url.isEmpty) return '';

    url = url.replaceAll(r'\/', '/').replaceAll('\\', '/');
    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (url.startsWith('/')) {
      url = '${AppConfig.baseUrl}$url';
    }

    final parsed = Uri.tryParse(url);
    if (parsed == null) return url;
    if (!parsed.hasScheme || parsed.host.isEmpty) return url;
    return parsed.toString();
  }
}
