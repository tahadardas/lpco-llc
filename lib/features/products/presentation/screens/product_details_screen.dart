import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/utils/price_parser.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/widgets/cart_currency_conflict_dialog.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_share_link.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_units_resolver.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final Map<String, String> _selectedAttributes = <String, String>{};
  final ProductRepository _productRepository = ProductRepository();
  final PageController _galleryPageController = PageController();
  late final List<_UnitOption> _unitOptions;
  String? _selectedUnitType;
  String? _selectedColorSlug;
  String? _selectedColorName;
  int _quantity = 1;
  int _imageIndex = 0;
  List<String>? _hydratedImageUrls;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().currentUser;
    final currency = user?.currency ?? 'syp';
    final group = user?.group ?? '';
    _unitOptions = _buildUnits(widget.product, currency, group);
    _selectedUnitType = null;
    _hydrateGalleryImagesIfNeeded();
  }

  @override
  void dispose() {
    _galleryPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final user = context.read<AuthCubit>().currentUser;
    final isGuest = context.read<AuthCubit>().state is! Authenticated;
    final selectedVariation = _resolveVariation(product);
    final currentUnit =
        _unitOptions.any((unit) => unit.type == _selectedUnitType)
        ? _unitOptions.firstWhere((unit) => unit.type == _selectedUnitType)
        : _unitOptions.first;
    final price = selectedVariation != null
        ? PriceParser.parse(
            selectedVariation.price,
            fallback: currentUnit.price,
          )
        : currentUnit.price;
    final regularPrice = PriceParser.parse(product.regularPrice);
    final hasDiscount = regularPrice > price && price > 0;
    final systemBottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return BlocListener<CartCubit, CartState>(
      listenWhen: (previous, current) => current is CartCurrencyConflict,
      listener: (context, state) async {
        if (state is CartCurrencyConflict) {
          await showCartCurrencyConflictDialog(context, state);
        }
      },
      child: Scaffold(
        appBar: BrandAppBar(
          showBack: true,
          actions: [
            IconButton(
              icon: Icon(
                context.read<ProductCubit>().isSaved(product.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              onPressed: () {
                context.read<ProductCubit>().toggleSaved(product.id);
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(text: buildProductShareText(product)),
                );
              },
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 20 + systemBottomInset),
          children: [
            _gallery(product),
            const SizedBox(height: 12),
            _headerDetails(
              product: product,
              price: price,
              regularPrice: regularPrice,
              hasDiscount: hasDiscount,
              isGuest: isGuest,
              currency: user?.currency ?? 'syp',
              unitOptions: _unitOptions,
              selectedUnitType: _selectedUnitType,
              onUnitSelected: (type) =>
                  setState(() => _selectedUnitType = type),
            ),
            const SizedBox(height: 10),
            _colorSection(),
            const SizedBox(height: 10),
            _attributesSection(),
            const SizedBox(height: 10),
            _quantitySection(),
            const SizedBox(height: 10),
            _descriptionSection(product),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: FrostedGlassPanel(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'الإجمالي:',
                        style: TextStyle(
                          color: Color(0xFF6F7786),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isGuest
                            ? 'سجل لعرض السعر'
                            : PriceFormatter.format(
                                price * _quantity,
                                currencyCode: user?.currency ?? 'syp',
                              ),
                        style: const TextStyle(
                          color: GlassStyle.fireRed,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isGuest
                        ? () => context.push(AppRoutePaths.login)
                        : _canAddToCart
                        ? _addToCart
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD31225),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB9C1CD),
                      disabledForegroundColor: const Color(0xFFF4F7FB),
                    ),
                    child: Text(isGuest ? 'تسجيل للدفع' : 'أضف إلى السلة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gallery(ProductModel product) {
    final imageUrls = _resolveGalleryImageUrls(product);
    final activeImageIndex = _imageIndex >= imageUrls.length ? 0 : _imageIndex;
    if (imageUrls.isEmpty) {
      return Container(
        height: 280,
        decoration: GlassStyle.acrylicDecoration(radius: 24),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48),
      );
    }

    return Column(
      children: [
        Container(
          height: 280,
          decoration: GlassStyle.acrylicDecoration(radius: 24),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PageView.builder(
                  key: ValueKey<int>(product.id),
                  controller: _galleryPageController,
                  itemCount: imageUrls.length,
                  onPageChanged: (value) => setState(() => _imageIndex = value),
                  itemBuilder: (context, index) {
                    return AppNetworkImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.contain,
                      errorWidget: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    );
                  },
                ),
              ),
              if (imageUrls.length > 1)
                Positioned(
                  bottom: 10,
                  child: Row(
                    children: List.generate(
                      imageUrls.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: activeImageIndex == index ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: activeImageIndex == index
                              ? GlassStyle.fireRed
                              : const Color(0xFFCCD2DC),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (imageUrls.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = activeImageIndex == index;
                return GestureDetector(
                  onTap: () {
                    _galleryPageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? GlassStyle.fireRed
                            : const Color(0xFFD9DFEA),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AppNetworkImage(
                        imageUrl: imageUrls[index],
                        fit: BoxFit.contain,
                        errorWidget: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  List<String> _resolveGalleryImageUrls(ProductModel product) {
    final hydrated = _hydratedImageUrls;
    if (hydrated != null && hydrated.isNotEmpty) {
      return hydrated;
    }
    return _extractImageUrls(product);
  }

  List<String> _extractImageUrls(ProductModel product) {
    final urls = <String>[];
    for (final image in product.images) {
      final src = image.src.trim();
      if (src.isEmpty || urls.contains(src)) {
        continue;
      }
      urls.add(src);
    }
    if (urls.isEmpty && product.firstImage.trim().isNotEmpty) {
      urls.add(product.firstImage.trim());
    }
    return urls;
  }

  Future<void> _hydrateGalleryImagesIfNeeded() async {
    final initialUrls = _extractImageUrls(widget.product);
    if (initialUrls.length > 1) {
      return;
    }

    final authState = context.read<AuthCubit>().state;
    final isGuest = authState is! Authenticated;

    try {
      final products = await _productRepository.getProductsByIds(<int>[
        widget.product.id,
      ], guest: isGuest);
      if (products.isEmpty || !mounted) {
        return;
      }

      final fetchedUrls = _extractImageUrls(products.first);
      if (fetchedUrls.length <= initialUrls.length) {
        return;
      }

      setState(() {
        _hydratedImageUrls = fetchedUrls;
        if (_imageIndex >= fetchedUrls.length) {
          _imageIndex = 0;
        }
      });
    } catch (_) {}
  }

  Widget _headerDetails({
    required ProductModel product,
    required num price,
    required num regularPrice,
    required bool hasDiscount,
    required bool isGuest,
    required String currency,
    required List<_UnitOption> unitOptions,
    required String? selectedUnitType,
    required ValueChanged<String> onUnitSelected,
  }) {
    final shortDescription = _shortDescriptionText(product);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GlassStyle.acrylicDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.2,
            ),
          ),
          if (shortDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shortDescription,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4C5565),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                product.inStock
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_rounded,
                size: 18,
                color: product.inStock
                    ? const Color(0xFF1B8E4B)
                    : const Color(0xFFD31225),
              ),
              const SizedBox(width: 6),
              Text(
                product.inStock ? 'متوفر في المخزون' : 'غير متوفر حالياً',
                style: TextStyle(
                  color: product.inStock
                      ? const Color(0xFF1B8E4B)
                      : const Color(0xFFD31225),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (unitOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              unitOptions.length > 1 ? 'اختر الوحدة' : 'الوحدة المتاحة',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: unitOptions
                  .map((unit) {
                    final selected = unit.type == selectedUnitType;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onUnitSelected(unit.type),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration:
                              GlassStyle.acrylicDecoration(
                                radius: 14,
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.94)
                                    : Colors.white.withValues(alpha: 0.76),
                              ).copyWith(
                                border: Border.all(
                                  color: selected
                                      ? GlassStyle.fireRed
                                      : const Color(0xFFE1E6EE),
                                ),
                              ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected
                                    ? GlassStyle.fireRed
                                    : const Color(0xFF8C95A4),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      unit.label,
                                      style: TextStyle(
                                        color: selected
                                            ? GlassStyle.fireRed
                                            : const Color(0xFF343A45),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isGuest
                                          ? 'سجل لعرض السعر'
                                          : PriceFormatter.format(
                                              unit.price,
                                              currencyCode: currency,
                                            ),
                                      style: TextStyle(
                                        color: isGuest
                                            ? const Color(0xFF7A8392)
                                            : const Color(0xFF111317),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE3E6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'محدد',
                                    style: TextStyle(
                                      color: GlassStyle.fireRed,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 16),
          if (isGuest)
            const Text(
              'سجل لعرض السعر',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            )
          else ...[
            if (hasDiscount)
              Text(
                PriceFormatter.format(regularPrice, currencyCode: currency),
                style: const TextStyle(
                  color: Color(0xFF9198A6),
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              PriceFormatter.format(price, currencyCode: currency),
              style: const TextStyle(
                color: GlassStyle.fireRed,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: <Widget>[
              Text(
                'SKU: ${product.sku.isEmpty ? 'N/A' : product.sku}',
                style: const TextStyle(
                  color: Color(0xFF6F7786),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_selectedUnitType != null)
                Text(
                  'الوحدة: ${_unitOptions.firstWhere((u) => u.type == _selectedUnitType).label}',
                  style: const TextStyle(
                    color: Color(0xFF6F7786),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (!product.inStock) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'غير متوفر حاليًا',
                style: TextStyle(
                  color: GlassStyle.fireRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorSection() {
    if (widget.product.colorOptions.isEmpty) return const SizedBox.shrink();

    return _section(
      title: 'اللون',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: widget.product.colorOptions.map((color) {
          final selected = color.colorSlug == _selectedColorSlug;
          // Clean the hex, assuming it might have a '#' prefix or just be a word. We'll try to parse it.
          // If empty, map to a default grey.
          Color parsedColor = Colors.grey.shade300;
          if (color.colorHex.isNotEmpty) {
            final hexVal = color.colorHex.replaceAll('#', '');
            if (hexVal.length == 6 || hexVal.length == 8) {
              parsedColor = Color(int.parse('FF$hexVal', radix: 16));
            }
          }

          return TapScale(
            onTap: color.isInStock
                ? () {
                    setState(() {
                      _selectedColorSlug = color.colorSlug;
                      _selectedColorName = color.colorName;
                    });
                  }
                : null,
            child: Opacity(
              opacity: color.isInStock ? 1.0 : 0.4,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: parsedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? GlassStyle.fireRed
                        : const Color(0xFFE1E6EE),
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: GlassStyle.fireRed.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: parsedColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _attributesSection() {
    if (widget.product.attributes.isEmpty) return const SizedBox.shrink();

    return _section(
      title: 'الخيارات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final attribute in widget.product.attributes) ...[
            Text(
              '${attribute.name}${attribute.required ? ' *' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attribute.options.map((option) {
                final selected =
                    _selectedAttributes[attribute.slug] == option ||
                    _selectedAttributes[attribute.name] == option;
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor: Colors.white.withValues(alpha: 0.68),
                  selectedColor: Colors.white.withValues(alpha: 0.92),
                  side: BorderSide(
                    color: selected
                        ? GlassStyle.fireRed
                        : const Color(0xFFE1E6EE),
                  ),
                  label: Text(
                    option,
                    style: TextStyle(
                      color: selected
                          ? GlassStyle.fireRed
                          : const Color(0xFF343A45),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedAttributes[attribute.slug] = option;
                      _selectedAttributes[attribute.name] = option;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _quantitySection() {
    return _section(
      title: 'الكمية',
      child: Row(
        children: [
          _qtyButton(
            icon: Icons.remove_rounded,
            onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
          ),
          const SizedBox(width: 8),
          Container(
            width: 52,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_quantity',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
          const SizedBox(width: 8),
          _qtyButton(
            icon: Icons.add_rounded,
            onTap: () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  Widget _descriptionSection(ProductModel product) {
    return _section(
      title: 'وصف المنتج',
      child: Text(
        product.description.isNotEmpty
            ? _stripHtml(product.description)
            : 'لا يوجد وصف متاح',
        style: const TextStyle(
          color: Color(0xFF4C5565),
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GlassStyle.acrylicDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback? onTap}) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }

  ProductVariation? _resolveVariation(ProductModel product) {
    if (product.variations.isEmpty || _selectedAttributes.isEmpty) {
      return null;
    }

    for (final variation in product.variations) {
      bool match = true;
      if (_selectedColorSlug != null &&
          variation.colorSlug != _selectedColorSlug) {
        match = false;
      }
      if (match && _selectedAttributes.isNotEmpty) {
        for (final entry in _selectedAttributes.entries) {
          final attrValue = variation.attributes[entry.key];
          if (attrValue == null) continue;
          if (attrValue.toString() != entry.value) {
            match = false;
            break;
          }
        }
      }
      if (match) return variation;
    }
    return null;
  }

  bool get _canAddToCart {
    if (!widget.product.inStock) return false;

    if (_selectedUnitType == null) return false;
    _UnitOption? selectedUnit;
    for (final unit in _unitOptions) {
      if (unit.type == _selectedUnitType) {
        selectedUnit = unit;
        break;
      }
    }
    if (selectedUnit == null || selectedUnit.price <= 0) return false;
    if (widget.product.colorOptions.isNotEmpty && _selectedColorSlug == null) {
      return false;
    }

    for (final attr in widget.product.attributes.where(
      (a) => a.required || a.variation,
    )) {
      final value =
          _selectedAttributes[attr.slug] ?? _selectedAttributes[attr.name];
      if (value == null || value.isEmpty) {
        return false;
      }
    }

    return true;
  }

  Future<void> _addToCart() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      await context.push(AppRoutePaths.login);
      return;
    }

    if (_selectedUnitType == null) {
      return;
    }

    final variation = _resolveVariation(widget.product);
    _UnitOption? unit;
    for (final candidate in _unitOptions) {
      if (candidate.type == _selectedUnitType) {
        unit = candidate;
        break;
      }
    }
    if (unit == null) {
      return;
    }

    try {
      await context.read<CartCubit>().addToCart(
        CartItemModel(
          productId: widget.product.id,
          name: widget.product.name,
          price: unit.price.toString(),
          image: widget.product.firstImage,
          selectedVariants: Map<String, dynamic>.from(_selectedAttributes),
          quantity: _quantity,
          unitType: unit.type,
          unitLabel: unit.label,
          currency: authState.user.currency,
          piecesCount: unit.piecesCount,
          variationId: variation?.id,
          colorSlug: _selectedColorSlug ?? variation?.colorSlug,
          colorName: _selectedColorName ?? variation?.colorName,
        ),
      );

      if (!mounted || context.read<CartCubit>().state is CartCurrencyConflict) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة المنتج إلى السلة')),
      );
    } catch (e) {
      if (!mounted) return;
      final safeMessage = ApiContract.safeMessageFromException(
        e,
        fallback: 'تعذر إضافة المنتج إلى السلة حالياً. يرجى إعادة المحاولة.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(safeMessage)));
    }
  }

  List<_UnitOption> _buildUnits(
    ProductModel product,
    String currencyCode,
    String userGroup,
  ) {
    final units =
        resolveProductUnits(
          product: product,
          currencyCode: currencyCode,
          userGroup: userGroup,
        ).map((unit) {
          return _UnitOption(
            type: unit.type,
            label: unit.label,
            price: unit.price,
            piecesCount: unit.piecesCount,
          );
        }).toList();

    units.sort((a, b) {
      final priorityCompare = _unitPriority(
        a.type,
      ).compareTo(_unitPriority(b.type));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.label.compareTo(b.label);
    });

    if (units.isEmpty) {
      units.add(
        _UnitOption(
          type: 'piece',
          label: product.unitDisplayDefaultAr.trim().isNotEmpty
              ? product.unitDisplayDefaultAr.trim()
              : 'قطعة',
          price: product.basePrice,
          piecesCount: 1,
        ),
      );
    }

    return units;
  }

  int _unitPriority(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized == 'piece' ||
        normalized == 'unit' ||
        normalized == 'single') {
      return 0;
    }
    if (normalized == 'pack' ||
        normalized == 'package' ||
        normalized == 'box' ||
        normalized == 'carton' ||
        normalized == 'case') {
      return 1;
    }
    return 2;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _shortDescriptionText(ProductModel product) {
    final raw = product.shortDescription.trim().isNotEmpty
        ? product.shortDescription
        : product.description;
    return _stripHtml(raw);
  }
}

class _UnitOption {
  final String type;
  final String label;
  final num price;
  final int? piecesCount;

  const _UnitOption({
    required this.type,
    required this.label,
    required this.price,
    required this.piecesCount,
  });
}
