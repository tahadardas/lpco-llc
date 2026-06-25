import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';

class ProductImagePreloader {
  ProductImagePreloader._();

  static final Set<String> _scheduledUrls = <String>{};

  static void preloadProducts(
    BuildContext context,
    Iterable<ProductModel> products, {
    int productLimit = 12,
    int imageLimit = 18,
    bool includeGallery = false,
    int galleryImagesPerProduct = 2,
  }) {
    if (productLimit <= 0 || imageLimit <= 0) return;

    final urls = <String>[];
    final seen = <String>{};
    for (final product in products.take(productLimit)) {
      for (final url in _productImageUrls(
        product,
        includeGallery: includeGallery,
        galleryImagesPerProduct: galleryImagesPerProduct,
      )) {
        if (seen.add(url)) {
          urls.add(url);
        }
        if (urls.length >= imageLimit) break;
      }
      if (urls.length >= imageLimit) break;
    }

    for (final url in urls) {
      if (!_scheduledUrls.add(url)) continue;
      unawaited(
        precacheImage(
          AppNetworkImage.imageProviderFor(url),
          context,
        ).catchError((_) {
          _scheduledUrls.remove(url);
        }),
      );
    }
  }

  static Iterable<String> _productImageUrls(
    ProductModel product, {
    required bool includeGallery,
    required int galleryImagesPerProduct,
  }) sync* {
    final maxImages = includeGallery ? galleryImagesPerProduct : 1;
    var emitted = 0;
    for (final image in product.images) {
      final url = AppNetworkImage.normalizeUrl(image.cardSrc);
      if (url.isEmpty) continue;
      yield url;
      emitted++;
      if (emitted >= maxImages) return;
    }

    if (emitted == 0) {
      final fallback = AppNetworkImage.normalizeUrl(product.firstImage);
      if (fallback.isNotEmpty) {
        yield fallback;
      }
    }
  }
}
