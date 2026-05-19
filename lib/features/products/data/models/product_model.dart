import 'package:lpco_llc/core/utils/price_parser.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class ProductImage {
  final int id;
  final String src;

  const ProductImage({required this.id, required this.src});

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] is int ? json['id'] as int : 0,
      src: (json['src'] ?? json['url'] ?? '').toString().trim(),
    );
  }
}

class ProductCategoryRef {
  final int id;
  final String name;
  final String slug;

  const ProductCategoryRef({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory ProductCategoryRef.fromJson(Map<String, dynamic> json) {
    return ProductCategoryRef(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
    );
  }
}

class ProductBrandRef {
  final int id;
  final String name;
  final String slug;
  final String imageUrl;

  const ProductBrandRef({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
  });

  factory ProductBrandRef.fromJson(Map<String, dynamic> json) {
    return ProductBrandRef(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
      imageUrl: TextSanitizer.fix(json['image_url']),
    );
  }
}

class ProductAttribute {
  final String name;
  final String slug;
  final List<String> options;
  final bool required;
  final bool variation;

  const ProductAttribute({
    required this.name,
    required this.slug,
    required this.options,
    required this.required,
    required this.variation,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    final dynamic options = json['options'];
    return ProductAttribute(
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
      options: options is List
          ? options.map((e) => TextSanitizer.fix(e)).toList()
          : const <String>[],
      required: json['required'] == true,
      variation: json['variation'] == true,
    );
  }
}

class ProductMetaEntry {
  final String key;
  final dynamic value;

  const ProductMetaEntry({required this.key, required this.value});

  factory ProductMetaEntry.fromJson(Map<String, dynamic> json) {
    return ProductMetaEntry(
      key: TextSanitizer.fix(json['key']).toLowerCase(),
      value: json['value'],
    );
  }
}

class UnitOption {
  final String type;
  final String labelDisplayAr;
  final String labelDisplayEn;
  final String name;
  final String label;
  final int? piecesCount;
  final num sypPiece;
  final num usdPiece;
  final num sypPack;
  final num usdPack;
  final num unitPrice;
  final num genericPrice;

  const UnitOption({
    required this.type,
    required this.labelDisplayAr,
    this.labelDisplayEn = '',
    required this.name,
    required this.label,
    required this.piecesCount,
    required this.sypPiece,
    required this.usdPiece,
    required this.sypPack,
    required this.usdPack,
    required this.unitPrice,
    required this.genericPrice,
  });

  factory UnitOption.fromJson(Map<String, dynamic> json) {
    final unitType = TextSanitizer.fix(json['type'] ?? json['unit_type']);
    return UnitOption(
      type: unitType.isEmpty ? 'piece' : unitType,
      labelDisplayAr: TextSanitizer.fix(
        json['label_display_ar'] ?? json['unit_label_display_ar'],
      ),
      labelDisplayEn: TextSanitizer.fix(
        json['label_display_en'] ?? json['unit_label_display_en'],
      ),
      name: TextSanitizer.fix(json['name']),
      label: TextSanitizer.fix(json['label']),
      piecesCount: json['pieces_count'] is int
          ? json['pieces_count'] as int
          : int.tryParse('${json['pieces_count'] ?? ''}'),
      sypPiece: PriceParser.parse(json['syp_piece'], fallback: 0),
      usdPiece: PriceParser.parse(json['usd_piece'], fallback: 0),
      sypPack: PriceParser.parse(
        json['syp_pack'] ?? json['syp_package'],
        fallback: 0,
      ),
      usdPack: PriceParser.parse(
        json['usd_pack'] ?? json['usd_package'],
        fallback: 0,
      ),
      unitPrice: PriceParser.parse(json['unit_price'], fallback: 0),
      genericPrice: PriceParser.parse(json['price'], fallback: 0),
    );
  }
}

class ProductVariation {
  final int id;
  final String price;
  final String regularPrice;
  final String salePrice;
  final String stockStatus;
  final bool isInStock;
  final String colorName;
  final String colorSlug;
  final String colorHex;
  final Map<String, dynamic> attributes;

  const ProductVariation({
    required this.id,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.stockStatus,
    required this.isInStock,
    required this.colorName,
    required this.colorSlug,
    required this.colorHex,
    required this.attributes,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      price: PriceParser.parse(json['price']).toString(),
      regularPrice: PriceParser.parse(json['regular_price']).toString(),
      salePrice: PriceParser.parse(json['sale_price']).toString(),
      stockStatus: TextSanitizer.fix(json['stock_status']).toLowerCase(),
      isInStock:
          json['is_in_stock'] == true ||
          (json['stock_status'] ?? '').toString().toLowerCase() == 'instock',
      colorName: TextSanitizer.fix(json['color_name']),
      colorSlug: TextSanitizer.fix(json['color_slug']),
      colorHex: TextSanitizer.fix(json['color_hex']),
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : <String, dynamic>{},
    );
  }
}

class ColorOption {
  final String colorName;
  final String colorSlug;
  final String colorHex;
  final bool isInStock;
  final int? variationId;

  const ColorOption({
    required this.colorName,
    required this.colorSlug,
    required this.colorHex,
    required this.isInStock,
    required this.variationId,
  });

  factory ColorOption.fromJson(Map<String, dynamic> json) {
    return ColorOption(
      colorName: TextSanitizer.fix(json['color_name'] ?? json['name']),
      colorSlug: TextSanitizer.fix(json['color_slug'] ?? json['slug']),
      colorHex: TextSanitizer.fix(json['color_hex']),
      isInStock:
          json['is_in_stock'] == true ||
          (json['stock_status'] ?? '').toString().toLowerCase() == 'instock',
      variationId: json['variation_id'] is int
          ? json['variation_id'] as int
          : int.tryParse('${json['variation_id'] ?? ''}'),
    );
  }
}

class ProductModel {
  final int id;
  final int customOrder;
  final String name;
  final String slug;
  final String sku;
  final String barcode1;
  final String barcode2;
  final String barcode3;
  final String barcode4;
  final List<String> barcodes;
  final String description;
  final String shortDescription;
  final String permalink;
  final String price;
  final String regularPrice;
  final String salePrice;
  final String stockStatus;
  final bool inStock;
  final int stockQuantity;
  final List<ProductImage> images;
  final List<ProductVariation> variations;
  final List<ColorOption> colorOptions;
  final List<ProductAttribute> attributes;
  final List<ProductCategoryRef> categories;
  final ProductBrandRef? brand;
  final List<ProductMetaEntry> metaData;
  final List<UnitOption> unitOptions;
  final int packSize;
  final num pricePerPiece;
  final num pricePerPack;
  final String unitDisplayDefaultAr;
  final String unitDisplayDefaultEn;
  final bool isFeatured;
  final DateTime? dateCreated;

  const ProductModel({
    required this.id,
    required this.customOrder,
    required this.name,
    required this.slug,
    required this.sku,
    this.barcode1 = '',
    this.barcode2 = '',
    this.barcode3 = '',
    this.barcode4 = '',
    this.barcodes = const <String>[],
    required this.description,
    required this.shortDescription,
    required this.permalink,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.stockStatus,
    required this.inStock,
    required this.stockQuantity,
    required this.images,
    required this.variations,
    required this.colorOptions,
    required this.attributes,
    required this.categories,
    this.brand,
    required this.metaData,
    required this.unitOptions,
    required this.packSize,
    required this.pricePerPiece,
    required this.pricePerPack,
    required this.unitDisplayDefaultAr,
    this.unitDisplayDefaultEn = '',
    this.isFeatured = false,
    this.dateCreated,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<ProductImage> imageUrls = <ProductImage>[];
    if (json['images'] is List) {
      imageUrls = (json['images'] as List)
          .whereType<Map>()
          .map((img) => ProductImage.fromJson(Map<String, dynamic>.from(img)))
          .where((img) => img.src.isNotEmpty)
          .toList();
    }
    final primaryImageUrl = TextSanitizer.fix(json['image_url']).trim();
    if (primaryImageUrl.isNotEmpty) {
      final existingIndex = imageUrls.indexWhere(
        (image) => image.src == primaryImageUrl,
      );
      if (existingIndex < 0) {
        imageUrls = <ProductImage>[
          ProductImage(id: 0, src: primaryImageUrl),
          ...imageUrls,
        ];
      } else if (existingIndex > 0) {
        final primary = imageUrls[existingIndex];
        imageUrls = <ProductImage>[
          primary,
          for (var i = 0; i < imageUrls.length; i++)
            if (i != existingIndex) imageUrls[i],
        ];
      }
    }

    List<ProductVariation> parsedVariations = <ProductVariation>[];
    if (json['variations'] is List) {
      parsedVariations = (json['variations'] as List)
          .whereType<Map>()
          .map((v) => ProductVariation.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }

    List<ColorOption> parsedColors = <ColorOption>[];
    if (json['color_options'] is List) {
      parsedColors = (json['color_options'] as List)
          .whereType<Map>()
          .map((c) => ColorOption.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    List<ProductAttribute> parsedAttributes = <ProductAttribute>[];
    if (json['attributes'] is List) {
      parsedAttributes = (json['attributes'] as List)
          .whereType<Map>()
          .map(
            (attr) =>
                ProductAttribute.fromJson(Map<String, dynamic>.from(attr)),
          )
          .toList();
    }

    List<ProductCategoryRef> parsedCategories = <ProductCategoryRef>[];
    if (json['categories'] is List) {
      parsedCategories = (json['categories'] as List)
          .whereType<Map>()
          .map(
            (cat) =>
                ProductCategoryRef.fromJson(Map<String, dynamic>.from(cat)),
          )
          .toList();
    }

    ProductBrandRef? parsedBrand;
    if (json['brand'] is Map) {
      parsedBrand = ProductBrandRef.fromJson(
        Map<String, dynamic>.from(json['brand'] as Map),
      );
    }

    List<ProductMetaEntry> parsedMetaData = <ProductMetaEntry>[];
    if (json['meta_data'] is List) {
      parsedMetaData = (json['meta_data'] as List)
          .whereType<Map>()
          .map((e) => ProductMetaEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final parsedBarcode1 = TextSanitizer.fix(json['barcode_1']);
    final parsedBarcode2 = TextSanitizer.fix(json['barcode_2']);
    final parsedBarcode3 = TextSanitizer.fix(json['barcode_3']);
    final parsedBarcode4 = TextSanitizer.fix(json['barcode_4']);
    final parsedBarcodes = _parseProductBarcodes(json, parsedMetaData, <String>[
      parsedBarcode1,
      parsedBarcode2,
      parsedBarcode3,
      parsedBarcode4,
    ]);

    List<UnitOption> parsedUnitOptions = <UnitOption>[];
    if (json['unit_options'] is List) {
      parsedUnitOptions = (json['unit_options'] as List)
          .whereType<Map>()
          .map((e) => UnitOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final stockStatus = (json['stock_status'] ?? '').toString().toLowerCase();

    // Parse dateCreated from various common WooCommerce API fields
    DateTime? parsedDate;
    final dynamic rawDate =
        json['date_created_gmt'] ?? json['date_created'] ?? json['date'];
    if (rawDate != null) {
      try {
        parsedDate = DateTime.parse(rawDate.toString());
      } catch (_) {
        // Fallback or ignore
      }
    }

    return ProductModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      customOrder: json['custom_order'] is int
          ? json['custom_order'] as int
          : int.tryParse('${json['custom_order'] ?? ''}') ?? 999999,
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
      sku: TextSanitizer.fix(json['sku']),
      barcode1: parsedBarcode1,
      barcode2: parsedBarcode2,
      barcode3: parsedBarcode3,
      barcode4: parsedBarcode4,
      barcodes: parsedBarcodes,
      description: TextSanitizer.fix(json['description']),
      shortDescription: TextSanitizer.fix(json['short_description']),
      permalink: TextSanitizer.fix(json['permalink']),
      price: PriceParser.parse(json['price']).toString(),
      regularPrice: PriceParser.parse(json['regular_price']).toString(),
      salePrice: PriceParser.parse(json['sale_price']).toString(),
      stockStatus: stockStatus,
      inStock:
          json['in_stock'] == true ||
          stockStatus == 'instock' ||
          stockStatus == 'onbackorder',
      stockQuantity: json['stock_quantity'] is int
          ? json['stock_quantity'] as int
          : int.tryParse('${json['stock_quantity'] ?? '0'}') ?? 0,
      images: imageUrls,
      variations: parsedVariations,
      colorOptions: parsedColors,
      attributes: parsedAttributes,
      categories: parsedCategories,
      brand: parsedBrand,
      metaData: parsedMetaData,
      unitOptions: parsedUnitOptions,
      packSize: json['pack_size'] is int
          ? json['pack_size'] as int
          : int.tryParse('${json['pack_size'] ?? '0'}') ?? 0,
      pricePerPiece: PriceParser.parse(json['price_per_piece']),
      pricePerPack: PriceParser.parse(json['price_per_pack']),
      unitDisplayDefaultAr: TextSanitizer.fix(json['unit_display_default_ar']),
      unitDisplayDefaultEn: TextSanitizer.fix(json['unit_display_default_en']),
      isFeatured: _parseFeaturedFlag(json['is_featured'] ?? json['featured']),
      dateCreated: parsedDate,
    );
  }

  String get firstImage => images.isNotEmpty ? images.first.src : '';

  num get basePrice => PriceParser.parse(price);

  static bool _parseFeaturedFlag(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'featured';
  }
}

List<String> _parseProductBarcodes(
  Map<String, dynamic> json,
  List<ProductMetaEntry> metaData,
  List<String> directValues,
) {
  final seen = <String>{};
  final values = <String>[];

  void add(dynamic raw) {
    final value = TextSanitizer.fix(raw).trim();
    if (value.isEmpty) return;
    final key = value.toLowerCase();
    if (seen.add(key)) {
      values.add(value);
    }
  }

  for (final value in directValues) {
    add(value);
  }

  final rawBarcodes = json['barcodes'];
  if (rawBarcodes is List) {
    for (final value in rawBarcodes) {
      add(value);
    }
  }
  add(json['barcode']);

  for (final meta in metaData) {
    final key = meta.key.toLowerCase();
    if (key.contains('barcode') || key == 'ean' || key == 'upc') {
      add(meta.value);
    }
  }

  return values;
}
