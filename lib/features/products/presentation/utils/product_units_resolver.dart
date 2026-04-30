import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/shared/commerce/wholesale/product_units/resolved_product_unit.dart';
import 'package:lpco_llc/shared/commerce/wholesale/product_units/wholesale_product_units_resolver.dart';

export 'package:lpco_llc/shared/commerce/wholesale/product_units/resolved_product_unit.dart'
    show ResolvedProductUnit;

List<ResolvedProductUnit> resolveProductUnits({
  required ProductModel product,
  required String currencyCode,
  required String userGroup,
}) {
  return WholesaleProductUnitsResolver.resolve(
    product: product,
    currencyCode: currencyCode,
    userGroup: userGroup,
  );
}
