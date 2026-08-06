class PhoneNumber {
  const PhoneNumber._();

  static final RegExp _allowedCharacters = RegExp(r'^[+0-9\s().-]+$');

  static String combine({
    required String countryCode,
    required String subscriberNumber,
  }) {
    final local = _toAsciiDigits(subscriberNumber).trim();
    if (local.isEmpty) {
      return '';
    }

    final code = _toAsciiDigits(countryCode).trim();
    return normalize('$code$local');
  }

  static String normalize(String value) {
    final ascii = _toAsciiDigits(value).trim();
    if (ascii.isEmpty) {
      return '';
    }

    final hasLeadingPlus = ascii.startsWith('+');
    final digits = ascii.replaceAll(RegExp(r'\D'), '');
    return '${hasLeadingPlus ? '+' : ''}$digits';
  }

  static String? validateOptional(String? value) {
    final raw = _toAsciiDigits(value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    if (!_allowedCharacters.hasMatch(raw)) {
      return 'صيغة رقم الهاتف غير صحيحة';
    }

    final normalized = normalize(raw);
    final digits = normalized.replaceAll('+', '');
    if (digits.length < 7 || digits.length > 15) {
      return 'رقم الهاتف يجب أن يتكون من 7 إلى 15 رقماً';
    }
    return null;
  }

  static String _toAsciiDigits(String value) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var index = 0; index < 10; index++) {
      result = result
          .replaceAll(arabicIndic[index], '$index')
          .replaceAll(easternArabicIndic[index], '$index');
    }
    return result;
  }
}
