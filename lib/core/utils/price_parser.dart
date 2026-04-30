class PriceParser {
  static num parse(dynamic value, {num fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value;

    var raw = value.toString().trim();
    if (raw.isEmpty) return fallback;

    raw = _normalizeDigits(raw);
    raw = raw
        .replaceAll('\u00A0', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^0-9,.\-]'), '');

    if (raw.isEmpty || raw == '-' || raw == '.' || raw == ',') {
      return fallback;
    }

    final commaCount = ','.allMatches(raw).length;
    final dotCount = '.'.allMatches(raw).length;

    if (commaCount > 0 && dotCount > 0) {
      final lastComma = raw.lastIndexOf(',');
      final lastDot = raw.lastIndexOf('.');
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final thousandSeparator = decimalSeparator == ',' ? '.' : ',';

      raw = raw.replaceAll(thousandSeparator, '');
      if (decimalSeparator == ',') {
        raw = raw.replaceAll(',', '.');
      }
    } else if (commaCount > 0) {
      raw = _normalizeSingleSeparator(raw, ',');
    } else if (dotCount > 1) {
      raw = _normalizeSingleSeparator(raw, '.');
    }

    final parsed = num.tryParse(raw);
    return parsed ?? fallback;
  }

  static String _normalizeSingleSeparator(String value, String separator) {
    final occurrences = separator.allMatches(value).length;
    if (occurrences == 1) {
      final index = value.lastIndexOf(separator);
      final decimals = value.length - index - 1;
      if (decimals > 0 && decimals <= 2) {
        return value.replaceAll(separator, '.');
      }
      return value.replaceAll(separator, '');
    }

    final last = value.lastIndexOf(separator);
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final ch = value[i];
      if (ch == separator) {
        if (i == last) {
          buffer.write('.');
        }
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  static String _normalizeDigits(String value) {
    const arabic = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    var normalized = value;
    arabic.forEach((key, val) {
      normalized = normalized.replaceAll(key, val);
    });
    return normalized;
  }
}
