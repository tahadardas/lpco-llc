import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lpco_llc/core/utils/formatters.dart';
import 'package:lpco_llc/core/utils/price_parser.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_units_resolver.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card_save_button.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card_stock_chip.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card_unit_selector.dart';

export 'package:lpco_llc/features/products/presentation/widgets/product_card_unit_selector.dart'
    show ProductCardUnit;

class ProductCard extends StatefulWidget {
  static const double loggedInGridExtent = 485;
  static const double guestGridExtent = 450;
  static const double loggedInFeaturedExtent = 480;
  static const double guestFeaturedExtent = 445;

  static double preferredGridExtent({required bool isGuest}) =>
      isGuest ? guestGridExtent : loggedInGridExtent;

  static double preferredFeaturedExtent({required bool isGuest}) =>
      isGuest ? guestFeaturedExtent : loggedInFeaturedExtent;

  final ProductModel product;
  final bool isGuest;
  final bool isSaved;
  final String currencyCode;
  final String userGroup;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;
  final ValueChanged<ProductCardUnit> onAddToCart;
  final VoidCallback onShare;

  const ProductCard({
    super.key,
    required this.product,
    required this.isGuest,
    required this.isSaved,
    required this.currencyCode,
    required this.userGroup,
    required this.onTap,
    required this.onToggleSave,
    required this.onAddToCart,
    required this.onShare,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late List<ProductCardUnit> _units;
  String? _selectedUnitType;
  bool _pressed = false;
  int _imageIndex = 0;

  ProductCardUnit get _fallbackUnit => _units.first;

  ProductCardUnit? get _selectedUnit {
    final type = _selectedUnitType;
    if (type == null) {
      return null;
    }
    for (final unit in _units) {
      if (unit.type == type) {
        return unit;
      }
    }
    return null;
  }

  bool get _requiresUnitSelection => _units.length > 1;

  bool get _showUnitSelector => _requiresUnitSelection;

  ProductCardUnit? get _effectiveUnitForActions {
    if (_showUnitSelector && _selectedUnit == null) {
      return null;
    }
    return _selectedUnit ?? _fallbackUnit;
  }

  bool get _canAddToCart {
    if (!widget.product.inStock) {
      return false;
    }
    if (widget.product.attributes.isNotEmpty) {
      return false;
    }
    if (_requiresUnitSelection && _selectedUnit == null) {
      return false;
    }
    final effectivePrice = _effectiveUnitForActions?.price ?? 0;
    return effectivePrice > 0;
  }

  @override
  void initState() {
    super.initState();
    _setupUnits();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id && _imageIndex != 0) {
      _imageIndex = 0;
    }
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.unitOptions != widget.product.unitOptions ||
        oldWidget.product.price != widget.product.price ||
        oldWidget.currencyCode != widget.currencyCode ||
        oldWidget.userGroup != widget.userGroup) {
      _setupUnits();
    }
  }

  void _setupUnits() {
    final previousSelection = _selectedUnitType;
    final resolved = resolveProductUnits(
      product: widget.product,
      currencyCode: widget.currencyCode,
      userGroup: widget.userGroup,
    );

    _units = resolved
        .map(
          (unit) => ProductCardUnit(
            type: unit.type,
            label: unit.label,
            price: unit.price,
            piecesCount: unit.piecesCount,
          ),
        )
        .toList(growable: false);

    _units.sort((a, b) {
      final priorityCompare = _unitPriority(
        a.type,
      ).compareTo(_unitPriority(b.type));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.label.compareTo(b.label);
    });

    if (_units.isEmpty) {
      _units = <ProductCardUnit>[
        ProductCardUnit(
          type: 'piece',
          label: widget.product.unitDisplayDefaultAr.isNotEmpty
              ? widget.product.unitDisplayDefaultAr
              : 'قطعة',
          price: widget.product.basePrice,
          piecesCount: 1,
        ),
      ];
    }

    final hasPrevious =
        previousSelection != null &&
        _units.any((unit) => unit.type == previousSelection);
    _selectedUnitType = hasPrevious ? previousSelection : null;
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

  @override
  Widget build(BuildContext context) {
    final regularPrice = PriceParser.parse(widget.product.regularPrice);
    final selectedPrice = _selectedUnit?.price ?? _fallbackUnit.price;
    final hasDiscount = regularPrice > selectedPrice && selectedPrice > 0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.985 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (highlighted) {
            if (_pressed != highlighted) {
              setState(() => _pressed = highlighted);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6EAF1)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0F0B1524),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _gridLayout(
              context,
              selectedPrice,
              regularPrice,
              hasDiscount,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridLayout(
    BuildContext context,
    num selectedPrice,
    num regularPrice,
    bool hasDiscount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 178,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: _imageGallery(fit: BoxFit.contain),
                ),
              ),
              if (_imageUrls.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _imageIndicator(
                        activeColor: const Color(0xFFD31225),
                        inactiveColor: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _saveButton(compact: true),
                    const SizedBox(width: 6),
                    _shareButton(compact: true),
                  ],
                ),
              ),
              if (hasDiscount)
                PositionedDirectional(
                  top: 8,
                  end: 10,
                  child: _discountBadge(
                    selectedPrice: selectedPrice,
                    regularPrice: regularPrice,
                  ),
                ),
              if (!widget.product.inStock)
                const PositionedDirectional(
                  bottom: 8,
                  start: 8,
                  child: ProductCardStockChip(),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: _gridDetails(
              selectedPrice: selectedPrice,
              regularPrice: regularPrice,
              hasDiscount: hasDiscount,
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridDetails({
    required num selectedPrice,
    required num regularPrice,
    required bool hasDiscount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.product.name,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.2,
                color: Color(0xFF151920),
              ),
            ),
            const SizedBox(height: 8),
            if (_showUnitSelector) ...<Widget>[
              const Text(
                'اختر الوحدة',
                style: TextStyle(
                  color: Color(0xFF596172),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              _unitsSelector(compact: true),
            ] else if (_units.isNotEmpty) ...<Widget>[
              Text(
                'الوحدة: ${_fallbackUnit.label}',
                style: const TextStyle(
                  color: Color(0xFF596172),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Price Section
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.isGuest)
                const Text(
                  'سجل لعرض السعر',
                  style: TextStyle(
                    color: Color(0xFF596172),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                )
              else ...<Widget>[
                if (hasDiscount)
                  Text(
                    PriceFormatter.format(
                      regularPrice,
                      currencyCode: widget.currencyCode,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8D96A5),
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  PriceFormatter.format(
                    selectedPrice,
                    currencyCode: widget.currencyCode,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111317),
                    fontSize: 21,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Cart Button Section
        _gridCartControl(),
      ],
    );
  }

  Widget _gridCartControl() {
    final cartCubit = _tryReadCartCubit(context);
    if (cartCubit == null) {
      return _buildGridPrimaryActionButton();
    }

    return BlocSelector<CartCubit, CartState, int>(
      selector: _cartQuantityForState,
      builder: (context, quantity) {
        if (quantity <= 0) {
          return _buildGridPrimaryActionButton();
        }
        return _buildGridQuantityStepper(quantity: quantity);
      },
    );
  }

  Widget _buildGridPrimaryActionButton() {
    final onPressed = _resolveGridPrimaryAction();
    final requiresSelection = _requiresUnitSelection && _selectedUnit == null;

    return Tooltip(
      message: requiresSelection ? 'اختر الوحدة أولاً' : 'إضافة إلى السلة',
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: 'إضافة إلى السلة',
        hint: requiresSelection ? 'اختر الوحدة أولاً' : null,
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            key: const ValueKey<String>('product_card_add_button'),
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              backgroundColor: const Color(0xFFD31225),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB9C1CD),
              disabledForegroundColor: const Color(0xFFF4F7FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGridQuantityStepper({required int quantity}) {
    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF4CF2E)),
      ),
      child: Row(
        children: <Widget>[
          _gridQuantityAction(
            icon: Icons.add_rounded,
            onPressed: _canAddToCart ? _incrementSelectedUnit : null,
            roundedSide: 'left',
          ),
          Expanded(
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          _gridQuantityAction(
            icon: Icons.remove_rounded,
            onPressed: _decrementSelectedUnit,
            roundedSide: 'right',
          ),
        ],
      ),
    );
  }

  Widget _gridQuantityAction({
    required IconData icon,
    required VoidCallback? onPressed,
    required String roundedSide,
  }) {
    return SizedBox(
      width: 44,
      height: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.horizontal(
            left: roundedSide == 'left'
                ? const Radius.circular(10)
                : Radius.zero,
            right: roundedSide == 'right'
                ? const Radius.circular(10)
                : Radius.zero,
          ),
          child: Icon(
            icon,
            size: 14,
            color: const Color(
              0xFF1A1A1A,
            ).withValues(alpha: onPressed == null ? 0.4 : 1),
          ),
        ),
      ),
    );
  }

  CartCubit? _tryReadCartCubit(BuildContext context) {
    try {
      return context.read<CartCubit>();
    } catch (_) {
      return null;
    }
  }

  int _cartQuantityForState(CartState state) {
    if (state is! CartLoaded) {
      return 0;
    }
    final unit = _effectiveUnitForActions;
    if (unit == null) {
      return 0;
    }
    final key = _itemKeyForUnit(unit);
    for (final item in state.items) {
      if (item.itemKey == key) {
        return item.quantity;
      }
    }
    return 0;
  }

  String _itemKeyForUnit(ProductCardUnit unit) {
    final probe = CartItemModel(
      productId: widget.product.id,
      name: widget.product.name,
      price: unit.price.toString(),
      image: widget.product.firstImage,
      selectedVariants: const <String, dynamic>{},
      unitType: unit.type,
      unitLabel: unit.label,
      piecesCount: unit.piecesCount,
      currency: widget.currencyCode,
    );
    return probe.itemKey;
  }

  void _incrementSelectedUnit() {
    final unit = _effectiveUnitForActions;
    if (unit == null) {
      return;
    }
    widget.onAddToCart(unit);
  }

  Future<void> _decrementSelectedUnit() async {
    final unit = _effectiveUnitForActions;
    if (unit == null) {
      return;
    }
    await context.read<CartCubit>().decrementItem(_itemKeyForUnit(unit));
  }

  VoidCallback? _resolveGridPrimaryAction() {
    final unit = _effectiveUnitForActions;
    if (_canAddToCart && unit != null) {
      return () => widget.onAddToCart(unit);
    }
    if (widget.product.attributes.isNotEmpty ||
        widget.product.colorOptions.length > 1) {
      return widget.onTap;
    }
    return null;
  }

  Widget _unitsSelector({bool compact = false}) {
    if (!_showUnitSelector) {
      return const SizedBox.shrink();
    }

    final selectableUnits = _units.toList(growable: false)
      ..sort((a, b) => _unitPriority(a.type).compareTo(_unitPriority(b.type)));

    return ProductCardUnitSelector(
      units: selectableUnits,
      selectedUnitType: _selectedUnitType,
      currencyCode: widget.currencyCode,
      isGuest: widget.isGuest,
      compact: compact,
      onSelected: (unitType) => setState(() => _selectedUnitType = unitType),
    );
  }

  Widget _saveButton({required bool compact}) {
    return ProductCardSaveButton(
      compact: compact,
      isSaved: widget.isSaved,
      onPressed: widget.onToggleSave,
    );
  }

  Widget _shareButton({required bool compact}) {
    final isCompact = compact;
    return SizedBox(
      width: isCompact ? 36 : 34,
      height: isCompact ? 36 : 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: isCompact ? Colors.white : const Color(0xFFF4F6FA),
          foregroundColor: const Color(0xFF5E6675),
          shape: isCompact
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: isCompact ? 1.2 : 0,
        ),
        onPressed: widget.onShare,
        icon: const Icon(Icons.share_outlined, size: 20),
      ),
    );
  }

  Widget _discountBadge({
    required num selectedPrice,
    required num regularPrice,
  }) {
    final percent = ((regularPrice - selectedPrice) / regularPrice * 100)
        .round();
    if (percent <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD31225),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '-$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }

  List<String> get _imageUrls {
    final urls = <String>[];
    for (final image in widget.product.images) {
      final src = image.src.trim();
      if (src.isEmpty || urls.contains(src)) {
        continue;
      }
      urls.add(src);
    }

    if (urls.isEmpty && widget.product.firstImage.trim().isNotEmpty) {
      urls.add(widget.product.firstImage.trim());
    }

    return urls;
  }

  Widget _imageGallery({BoxFit fit = BoxFit.contain}) {
    final imageUrls = _imageUrls;
    if (imageUrls.length <= 1) {
      return AppNetworkImage(
        imageUrl: imageUrls.isEmpty ? '' : imageUrls.first,
        fit: fit,
        placeholder: Container(color: const Color(0xFFF4F6FA)),
        errorWidget: Container(
          color: const Color(0xFFF4F6FA),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported),
        ),
      );
    }

    return PageView.builder(
      key: ValueKey<int>(widget.product.id),
      itemCount: imageUrls.length,
      onPageChanged: (value) {
        if (_imageIndex != value && mounted) {
          setState(() => _imageIndex = value);
        }
      },
      itemBuilder: (context, index) {
        return AppNetworkImage(
          imageUrl: imageUrls[index],
          fit: fit,
          placeholder: Container(color: const Color(0xFFF4F6FA)),
          errorWidget: Container(
            color: const Color(0xFFF4F6FA),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported),
          ),
        );
      },
    );
  }

  Widget _imageIndicator({
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final imageUrls = _imageUrls;
    final activeIndex = _imageIndex >= imageUrls.length ? 0 : _imageIndex;
    const baseSize = 6.5;
    const activeWidth = 16.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(imageUrls.length, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 1.8),
          width: active ? activeWidth : baseSize,
          height: baseSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }
}
