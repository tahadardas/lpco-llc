import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';

Uri buildProductShareUri(ProductModel product) {
  return Uri.parse(
    '${AppConfig.baseUrl}${AppRoutePaths.productUrl(product.id)}',
  );
}

String buildProductShareText(ProductModel product) {
  final link = buildProductShareUri(product).toString();
  final name = product.name.trim();
  if (name.isEmpty) {
    return link;
  }
  return '$name\n$link';
}
