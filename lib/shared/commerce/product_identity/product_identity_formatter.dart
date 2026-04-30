import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class ProductIdentityFormatter {
  static const String _fallbackNoUnit =
      '\u0628\u062f\u0648\u0646 \u0648\u062d\u062f\u0629';
  static const String _fallbackPiece = '\u0642\u0637\u0639\u0629';
  static const String _fallbackPackage = '\u0637\u0631\u062f';
  static const String _qtyLabelPrefix = '\u0627\u0644\u0648\u062d\u062f\u0629';
  static const String _countLabel = '\u0627\u0644\u0643\u0645\u064a\u0629';

  static String formatUnitLabel({
    String? unitLabel,
    String? unitType,
    int? piecesCount,
    bool includePiecesCount = true,
  }) {
    final explicitLabel = TextSanitizer.fix(unitLabel).trim();
    if (explicitLabel.isNotEmpty) {
      // Backend label is authoritative; avoid reconstructing/augmenting it.
      return explicitLabel;
    }

    final rawType = TextSanitizer.fix(unitType).trim();
    final normalizedType = _normalizeUnitType(rawType);

    final baseLabel = _fallbackLabelForType(normalizedType, rawType);

    if (!includePiecesCount || piecesCount == null || piecesCount <= 1) {
      return baseLabel;
    }

    if (baseLabel == _fallbackNoUnit || _hasPiecesSuffix(baseLabel)) {
      return baseLabel;
    }

    return '$baseLabel ($piecesCount $_fallbackPiece)';
  }

  static String formatQuantityLabel({
    required int quantity,
    String? unitLabel,
    String? unitType,
  }) {
    if (quantity <= 0) {
      return '-';
    }

    final resolvedUnit = formatUnitLabel(
      unitLabel: unitLabel,
      unitType: unitType,
      includePiecesCount: false,
    );
    if (resolvedUnit == _fallbackNoUnit) {
      return quantity.toString();
    }
    return '$quantity $resolvedUnit';
  }

  static String formatUnitAndQuantity({
    required int quantity,
    String? unitLabel,
    String? unitType,
    int? piecesCount,
  }) {
    final resolvedUnit = formatUnitLabel(
      unitLabel: unitLabel,
      unitType: unitType,
      piecesCount: piecesCount,
    );
    final quantityLabel = quantity > 0 ? quantity.toString() : '-';
    return '$_qtyLabelPrefix: $resolvedUnit | $_countLabel: $quantityLabel';
  }

  static String _fallbackLabelForType(String normalizedType, String rawType) {
    if (normalizedType == 'piece') {
      return _fallbackPiece;
    }
    if (normalizedType == 'package') {
      return _fallbackPackage;
    }
    if (normalizedType.isEmpty) {
      return _fallbackNoUnit;
    }
    return rawType.isNotEmpty ? rawType : _fallbackNoUnit;
  }

  static bool _hasPiecesSuffix(String label) {
    return RegExp(r'\(\s*[0-9٠-٩]+\s+\S+\s*\)$').hasMatch(label.trim());
  }

  static String _normalizeUnitType(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized == 'piece' ||
        normalized == 'unit' ||
        normalized == 'single') {
      return 'piece';
    }
    if (normalized == 'pack' ||
        normalized == 'package' ||
        normalized == 'box' ||
        normalized == 'carton' ||
        normalized == 'case') {
      return 'package';
    }
    return normalized;
  }
}
