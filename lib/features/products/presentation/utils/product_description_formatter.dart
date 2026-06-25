class ProductDescriptionFormatter {
  const ProductDescriptionFormatter._();

  static String toPlainText(String html) {
    var text = html.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    text = _decodeHtmlEntities(text);
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String _decodeHtmlEntities(String value) {
    const named = <String, String>{
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
      'nbsp': ' ',
    };
    return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
      match,
    ) {
      final entity = match.group(1) ?? '';
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      return named[entity.toLowerCase()] ?? match.group(0)!;
    });
  }
}
