import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/utils/price_parser.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/shared/commerce/wholesale/product_units/resolved_product_unit.dart';

class WholesaleProductUnitsResolver {
  static List<ResolvedProductUnit> resolve({
    required ProductModel product,
    required String currencyCode,
    required String userGroup,
  }) {
    final normalizedCurrency = AppCurrencies.normalizeCode(currencyCode);
    final units = <ResolvedProductUnit>[];
    final seenTypes = <String>{};
    final scopedPrices = _resolveScopedPrices(product.metaData, userGroup);

    if (product.unitOptions.isNotEmpty) {
      final seenSignatures = <String>{};
      for (final option in product.unitOptions) {
        final type = option.type.trim();
        if (type.isEmpty) continue;

        final canonicalType = _canonicalUnitType(type);
        final label = _safeLabel(
          option.labelDisplayAr,
          fallback: _safeLabel(
            option.labelDisplayEn,
            fallback: _safeLabel(option.name, fallback: option.label),
          ),
        );

        final piecesCount = option.piecesCount;
        final isPackage = canonicalType == 'package';

        // Group/currency scoped matrix is the source of truth.
        var price = _priceFromScopedMap(
          scopedPrices: scopedPrices,
          normalizedCurrency: normalizedCurrency,
          isPackage: isPackage,
        );
        if (price <= 0) {
          if (isPackage) {
            price = normalizedCurrency == 'usd'
                ? option.usdPack
                : option.sypPack;
          } else {
            price = normalizedCurrency == 'usd'
                ? option.usdPiece
                : option.sypPiece;
          }
        }

        if (price <= 0 && isPackage && (piecesCount ?? 0) > 1) {
          final piecePrice = normalizedCurrency == 'usd'
              ? option.usdPiece
              : option.sypPiece;
          if (piecePrice > 0) {
            price = piecePrice * (piecesCount ?? 1);
          }
        }

        // Generic `price` may come from another currency on some payloads.
        // Only use it as a late fallback.
        if (price <= 0) {
          price = option.unitPrice > 0 ? option.unitPrice : option.genericPrice;
        }

        if (price <= 0) {
          price = _fallbackProductPrice(product, isPackage);
        }

        final resolvedLabel = label.isEmpty
            ? (canonicalType == 'piece' &&
                      product.unitDisplayDefaultAr.trim().isNotEmpty
                  ? product.unitDisplayDefaultAr.trim()
                  : _defaultLabelForType(type))
            : label;
        final signature =
            '${type.toLowerCase()}|${resolvedLabel.trim().toLowerCase()}|${piecesCount ?? 0}|$price';
        if (!seenSignatures.add(signature)) {
          continue;
        }

        units.add(
          ResolvedProductUnit(
            type: type,
            label: resolvedLabel,
            price: price,
            piecesCount: piecesCount,
          ),
        );
        seenTypes.add(canonicalType);
      }

      if (units.isNotEmpty) {
        // API `unit_options` are authoritative for present units; metadata may
        // still complete a missing package unit from the pricing matrix.
        _appendMetaUnitsIfNeeded(
          units: units,
          seenTypes: seenTypes,
          scopedPrices: scopedPrices,
          product: product,
          normalizedCurrency: normalizedCurrency,
        );
        return _normalizeVisibleUnits(units);
      }
    }

    _appendMetaUnitsIfNeeded(
      units: units,
      seenTypes: seenTypes,
      scopedPrices: scopedPrices,
      product: product,
      normalizedCurrency: normalizedCurrency,
    );

    if (units.isEmpty) {
      final fallbackPrice = PriceParser.parse(product.price, fallback: 0);
      if (fallbackPrice > 0) {
        units.add(
          ResolvedProductUnit(
            type: 'piece',
            label: _defaultLabelForType('piece'),
            price: fallbackPrice,
            piecesCount: 1,
          ),
        );
      }
    }

    return _normalizeVisibleUnits(units);
  }

  static num? resolveExpectedUnitPrice({
    required ProductModel product,
    required String unitType,
    required String currencyCode,
    required String userGroup,
  }) {
    final normalizedUnit = _canonicalUnitType(unitType);
    final units = resolve(
      product: product,
      currencyCode: currencyCode,
      userGroup: userGroup,
    );

    for (final unit in units) {
      if (_canonicalUnitType(unit.type) != normalizedUnit) {
        continue;
      }
      if (unit.price > 0) {
        return unit.price;
      }
    }

    if (normalizedUnit == 'piece' && product.pricePerPiece > 0) {
      return product.pricePerPiece;
    }
    if ((normalizedUnit == 'pack' || normalizedUnit == 'package') &&
        product.pricePerPack > 0) {
      return product.pricePerPack;
    }
    if (product.basePrice > 0) {
      return product.basePrice;
    }

    return null;
  }
}

List<ResolvedProductUnit> _normalizeVisibleUnits(
  List<ResolvedProductUnit> units,
) {
  final positiveUnits = units
      .where((unit) => unit.price > 0)
      .toList(growable: false);
  if (positiveUnits.length <= 1) {
    return positiveUnits;
  }

  final piecePrices = positiveUnits
      .where((unit) => _canonicalUnitType(unit.type) == 'piece')
      .map((unit) => unit.price)
      .toList(growable: false);
  if (piecePrices.isEmpty) {
    return positiveUnits;
  }

  return positiveUnits
      .where((unit) {
        if (_canonicalUnitType(unit.type) != 'package') {
          return true;
        }
        return !piecePrices.any(
          (piecePrice) => _pricesEqual(piecePrice, unit.price),
        );
      })
      .toList(growable: false);
}

bool _pricesEqual(num first, num second) {
  return (first.toDouble() - second.toDouble()).abs() < 0.000001;
}

String _canonicalUnitType(String type) {
  final normalized = type.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'piece';
  }

  if (normalized == 'piece' || normalized == 'unit' || normalized == 'single') {
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

num _priceFromScopedMap({
  required Map<String, dynamic>? scopedPrices,
  required String normalizedCurrency,
  required bool isPackage,
}) {
  if (scopedPrices == null || scopedPrices.isEmpty) return 0;

  final pieceKey = normalizedCurrency == 'usd' ? 'usd_piece' : 'syp_piece';
  final packKeys = normalizedCurrency == 'usd'
      ? const <String>['usd_pack', 'usd_package']
      : const <String>['syp_pack', 'syp_package'];

  final piecePrice = PriceParser.parse(scopedPrices[pieceKey], fallback: 0);
  if (!isPackage) {
    return piecePrice;
  }

  for (final key in packKeys) {
    final directPack = PriceParser.parse(scopedPrices[key], fallback: 0);
    if (directPack > 0) {
      return directPack;
    }
  }

  final packageCount = scopedPrices['package_pieces_count'] is int
      ? scopedPrices['package_pieces_count'] as int
      : int.tryParse('${scopedPrices['package_pieces_count'] ?? ''}');
  if (piecePrice > 0 && (packageCount ?? 0) > 1) {
    return piecePrice * (packageCount ?? 1);
  }

  return 0;
}

num _fallbackProductPrice(ProductModel product, bool isPackage) {
  if (isPackage && product.pricePerPack > 0) {
    return product.pricePerPack;
  }
  if (isPackage) {
    return 0;
  }
  if (!isPackage && product.pricePerPiece > 0) {
    return product.pricePerPiece;
  }
  return PriceParser.parse(product.price, fallback: 0);
}

void _appendMetaUnitsIfNeeded({
  required List<ResolvedProductUnit> units,
  required Set<String> seenTypes,
  required Map<String, dynamic>? scopedPrices,
  required ProductModel product,
  required String normalizedCurrency,
}) {
  if (scopedPrices == null || scopedPrices.isEmpty) {
    return;
  }

  var piecePrice = _priceFromScopedMap(
    scopedPrices: scopedPrices,
    normalizedCurrency: normalizedCurrency,
    isPackage: false,
  );
  var packagePrice = _priceFromScopedMap(
    scopedPrices: scopedPrices,
    normalizedCurrency: normalizedCurrency,
    isPackage: true,
  );

  final boxCount = _parsePositiveInt(scopedPrices['box_pieces_count']);
  final packageCount = _parsePositiveInt(scopedPrices['package_pieces_count']);

  if (piecePrice <= 0) {
    piecePrice = _fallbackProductPrice(product, false);
  }

  final rawPieceLabel = scopedPrices['box_unit_name'];
  final rawPackageLabel = scopedPrices['package_unit_name'];
  final pieceLabel = _safeLabel(
    rawPieceLabel,
    fallback: _safeLabel(
      product.unitDisplayDefaultAr,
      fallback: _defaultLabelForType('piece'),
    ),
  );
  final packageLabel = _safeLabel(
    rawPackageLabel,
    fallback: _defaultLabelForType('package'),
  );
  final hasPieceSignal =
      _hasNonEmptyText(rawPieceLabel) || boxCount != null || piecePrice > 0;
  final hasPackageSignal =
      _hasNonEmptyText(rawPackageLabel) ||
      packageCount != null ||
      packagePrice > 0;

  if (!seenTypes.contains('piece') && hasPieceSignal) {
    units.add(
      ResolvedProductUnit(
        type: 'piece',
        label: pieceLabel,
        price: piecePrice,
        piecesCount: boxCount ?? 1,
      ),
    );
    seenTypes.add('piece');
  }

  final fallbackPackageCount = product.packSize > 1 ? product.packSize : null;
  final resolvedPackageCount = packageCount ?? fallbackPackageCount;

  if (packagePrice <= 0 &&
      resolvedPackageCount != null &&
      resolvedPackageCount > 1 &&
      piecePrice > 0) {
    packagePrice = piecePrice * resolvedPackageCount;
  }

  if (packagePrice <= 0 && product.pricePerPack > 0) {
    packagePrice = product.pricePerPack;
  }

  if (!seenTypes.contains('package') && hasPackageSignal) {
    units.add(
      ResolvedProductUnit(
        type: 'package',
        label: packageLabel,
        price: packagePrice,
        piecesCount: resolvedPackageCount,
      ),
    );
    seenTypes.add('package');
  }
}

Map<String, dynamic>? _resolveScopedPrices(
  List<ProductMetaEntry> metaData,
  String userGroup,
) {
  Map<String, dynamic>? matrix;

  for (final entry in metaData) {
    if (entry.key != '_dms_prices') continue;
    final value = entry.value;
    if (value is Map) {
      matrix = Map<String, dynamic>.from(value);
      break;
    }
  }

  if (matrix == null || matrix.isEmpty) {
    return null;
  }

  String? selectedKey;
  Map<String, dynamic>? selected;

  final desired = userGroup.trim().toLowerCase();
  if (desired.isNotEmpty) {
    for (final entry in matrix.entries) {
      if (entry.value is! Map) continue;
      if (entry.key.toString().trim().toLowerCase() == desired) {
        selectedKey = entry.key.toString().trim();
        selected = Map<String, dynamic>.from(entry.value as Map);
        break;
      }
    }
  }

  if (selected == null) {
    const fallbackOrder = <String>['default', 'a+_\$', 'a', 'b', 'c'];
    for (final wanted in fallbackOrder) {
      for (final entry in matrix.entries) {
        if (entry.value is! Map) continue;
        if (entry.key.toString().trim().toLowerCase() == wanted) {
          selectedKey = entry.key.toString().trim();
          selected = Map<String, dynamic>.from(entry.value as Map);
          break;
        }
      }
      if (selected != null) {
        break;
      }
    }
  }

  if (selected == null) {
    for (final entry in matrix.entries) {
      if (entry.value is Map) {
        selectedKey = entry.key.toString().trim();
        selected = Map<String, dynamic>.from(entry.value as Map);
        break;
      }
    }
  }

  if (selected == null) {
    return null;
  }

  final merged = Map<String, dynamic>.from(selected);
  Map<String, dynamic>? defaultMap;
  for (final entry in matrix.entries) {
    if (entry.value is! Map) {
      continue;
    }
    if (entry.key.toString().trim().toLowerCase() == 'default') {
      defaultMap = Map<String, dynamic>.from(entry.value as Map);
      break;
    }
  }

  final presentationKeys = <String>[
    'box_unit_name',
    'box_pieces_count',
    'package_unit_name',
    'package_pieces_count',
  ];

  for (final key in presentationKeys) {
    if (defaultMap != null) {
      final defaultValue = defaultMap[key];
      if (_hasMeaningfulPresentationValue(key, defaultValue)) {
        merged[key] = defaultValue;
        continue;
      }
    }

    if (_hasMeaningfulPresentationValue(key, merged[key])) {
      continue;
    }
    for (final entry in matrix.entries) {
      if (entry.value is! Map) continue;
      final candidateKey = entry.key.toString().trim();
      if (selectedKey != null &&
          candidateKey.toLowerCase() == selectedKey.toLowerCase()) {
        continue;
      }
      final candidateMap = Map<String, dynamic>.from(entry.value as Map);
      final candidateValue = candidateMap[key];
      if (_hasMeaningfulPresentationValue(key, candidateValue)) {
        merged[key] = candidateValue;
        break;
      }
    }
  }

  return merged;
}

String _safeLabel(dynamic value, {required String fallback}) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

bool _hasNonEmptyText(dynamic value) {
  return (value ?? '').toString().trim().isNotEmpty;
}

int? _parsePositiveInt(dynamic value) {
  final parsed = value is int ? value : int.tryParse('${value ?? ''}');
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

bool _hasMeaningfulPresentationValue(String key, dynamic value) {
  if (key.endsWith('_name')) {
    return _hasNonEmptyText(value);
  }
  if (key.endsWith('_count')) {
    return _parsePositiveInt(value) != null;
  }
  return value != null;
}

String _defaultLabelForType(String type) {
  final t = type.toLowerCase();
  if (t == 'piece') return '\u0642\u0637\u0639\u0629';
  if (t == 'pack') return '\u0637\u0631\u062f';
  if (t == 'box') return '\u0643\u0631\u062a\u0648\u0646';
  if (t == 'package') return '\u0637\u0631\u062f';
  return type;
}
