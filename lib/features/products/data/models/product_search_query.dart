import 'package:lpco_llc/core/config/app_config.dart';

enum ProductSortOption { defaultOrder, priceLowToHigh, priceHighToLow }

class AttributeTermFilter {
  final String attribute;
  final String attributeTerm;

  const AttributeTermFilter({
    required this.attribute,
    required this.attributeTerm,
  });

  bool get isValid =>
      attribute.trim().isNotEmpty && attributeTerm.trim().isNotEmpty;
}

class ProductSearchQuery {
  final String search;
  final num? minPrice;
  final num? maxPrice;
  final List<int> categoryIds;
  final AttributeTermFilter? attributeFilter;
  final String stockStatus;
  final ProductSortOption sortOption;
  final int page;
  final int perPage;
  final Map<String, dynamic> extraParams;

  const ProductSearchQuery({
    this.search = '',
    this.minPrice,
    this.maxPrice,
    this.categoryIds = const <int>[],
    this.attributeFilter,
    this.stockStatus = 'any',
    this.sortOption = ProductSortOption.defaultOrder,
    this.page = 1,
    this.perPage = AppConfig.productsPerPage,
    this.extraParams = const <String, dynamic>{},
  });

  ProductSearchQuery copyWith({
    String? search,
    num? minPrice,
    bool clearMinPrice = false,
    num? maxPrice,
    bool clearMaxPrice = false,
    List<int>? categoryIds,
    AttributeTermFilter? attributeFilter,
    bool clearAttributeFilter = false,
    String? stockStatus,
    ProductSortOption? sortOption,
    int? page,
    int? perPage,
    Map<String, dynamic>? extraParams,
  }) {
    return ProductSearchQuery(
      search: search ?? this.search,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      categoryIds: categoryIds ?? this.categoryIds,
      attributeFilter: clearAttributeFilter
          ? null
          : (attributeFilter ?? this.attributeFilter),
      stockStatus: stockStatus ?? this.stockStatus,
      sortOption: sortOption ?? this.sortOption,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      extraParams: extraParams ?? this.extraParams,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'page': page <= 0 ? 1 : page,
      'per_page': perPage <= 0 ? AppConfig.productsPerPage : perPage,
    };

    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) {
      params['search'] = normalizedSearch;
    }

    final normalizedCategories = categoryIds
        .where((id) => id > 0)
        .toSet()
        .toList();
    if (normalizedCategories.isNotEmpty) {
      params['category'] = normalizedCategories.join(',');
    }

    final normalizedStock = stockStatus.trim().toLowerCase();
    if (normalizedStock.isNotEmpty && normalizedStock != 'any') {
      params['stock_status'] = normalizedStock;
      params['stock'] =
          normalizedStock; // Keeping for compatibility with custom endpoints
      if (normalizedStock == 'instock') {
        params['in_stock'] = 1;
      } else if (normalizedStock == 'outofstock') {
        params['in_stock'] = 0;
      }
    }

    final normalizedMin = _normalizePrice(minPrice);
    final normalizedMax = _normalizePrice(maxPrice);
    if (normalizedMin != null && normalizedMax != null) {
      if (normalizedMin <= normalizedMax) {
        params['min_price'] = _formatPrice(normalizedMin);
        params['max_price'] = _formatPrice(normalizedMax);
        params['minPrice'] = _formatPrice(normalizedMin);
        params['maxPrice'] = _formatPrice(normalizedMax);
      } else {
        params['min_price'] = _formatPrice(normalizedMax);
        params['max_price'] = _formatPrice(normalizedMin);
        params['minPrice'] = _formatPrice(normalizedMax);
        params['maxPrice'] = _formatPrice(normalizedMin);
      }
    } else {
      if (normalizedMin != null) {
        params['min_price'] = _formatPrice(normalizedMin);
        params['minPrice'] = _formatPrice(normalizedMin);
      }
      if (normalizedMax != null) {
        params['max_price'] = _formatPrice(normalizedMax);
        params['maxPrice'] = _formatPrice(normalizedMax);
      }
    }

    final attribute = attributeFilter;
    if (attribute != null && attribute.isValid) {
      params['attribute'] = attribute.attribute.trim();
      params['attribute_term'] = attribute.attributeTerm.trim();
    }

    switch (sortOption) {
      case ProductSortOption.defaultOrder:
        // Respect backend default ordering (Single Source of Truth)
        break;
      case ProductSortOption.priceLowToHigh:
        params['orderby'] = 'price';
        params['order'] = 'asc';
        params['sort'] = 'price_asc';
        break;
      case ProductSortOption.priceHighToLow:
        params['orderby'] = 'price';
        params['order'] = 'desc';
        params['sort'] = 'price_desc';
        break;
    }

    for (final entry in extraParams.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || entry.value == null) {
        continue;
      }
      params[key] = entry.value;
    }

    return params;
  }

  num? _normalizePrice(num? value) {
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      return null;
    }

    return value;
  }

  String _formatPrice(num value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toStringAsFixed(2);
  }
}
