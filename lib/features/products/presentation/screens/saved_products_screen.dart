import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/widgets/app_drawer.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/widgets/cart_currency_conflict_dialog.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_share_link.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({super.key});

  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ProductModel>> _future;

  double _topContentPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        BrandAppBar.toolbarHeightValue +
        14;
  }

  void _syncScope() {
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      final user = authState.user;
      context.read<ProductCubit>().setScope(
        userScope: 'user_${user.id ?? user.username}',
        isGuest: false,
      );
      return;
    }
    context.read<ProductCubit>().setScope(userScope: 'guest', isGuest: true);
  }

  @override
  void initState() {
    super.initState();
    _syncScope();
    _future = context.read<ProductCubit>().loadSavedProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<ProductCubit>().loadSavedProducts();
    });
    await _future;
  }

  List<ProductModel> _filter(List<ProductModel> products) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return products;
    }
    return products
        .where((product) {
          final name = product.name.toLowerCase();
          final sku = product.sku.toLowerCase();
          return name.contains(query) || sku.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.read<AuthCubit>().state is! Authenticated;

    return MultiBlocListener(
      listeners: [
        BlocListener<ProductCubit, ProductState>(
          listenWhen: (previous, current) =>
              previous.userScope != current.userScope ||
              previous.isGuest != current.isGuest ||
              !setEquals(previous.savedProductIds, current.savedProductIds),
          listener: (context, state) => _reload(),
        ),
        BlocListener<CartCubit, CartState>(
          listenWhen: (previous, current) => current is CartCurrencyConflict,
          listener: (context, state) async {
            if (state is CartCurrencyConflict) {
              await showCartCurrencyConflictDialog(context, state);
            }
          },
        ),
      ],
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: BrandAppBar(
          title: 'المحفوظات',
          showMenu: true,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _reload,
            ),
          ],
        ),
        drawer: const AppSideDrawer(),
        body: FutureBuilder<List<ProductModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppSkeleton(enabled: true, child: _skeleton());
            }

            if (snapshot.hasError) {
              return _SavedEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'تعذر تحميل المحفوظات',
                subtitle: 'تحقق من الاتصال ثم حاول مرة أخرى.',
                ctaLabel: 'إعادة المحاولة',
                onPressed: _reload,
              );
            }

            final products = snapshot.data ?? <ProductModel>[];
            final filtered = _filter(products);

            if (products.isEmpty) {
              return _SavedEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'لا توجد منتجات محفوظة',
                subtitle: 'احفظ المنتجات المهمة لتعود إليها بسرعة.',
                ctaLabel: 'تصفح المنتجات',
                onPressed: () =>
                    context.go(AppRoutePaths.catalogListing(title: 'المنتجات')),
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      _topContentPadding(context),
                      14,
                      10,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'ابحث في المحفوظات',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: 'مسح',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'العناصر: ${filtered.length}',
                            style: const TextStyle(
                              color: Color(0xFF6B7482),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SavedEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'لا توجد نتائج مطابقة',
                        subtitle: 'امسح البحث لعرض جميع العناصر المحفوظة.',
                        ctaLabel: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        compact: true,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: ProductCard.preferredGridExtent(
                            isGuest: isGuest,
                          ),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final product = filtered[index];
                          return ProductCard(
                            product: product,
                            isGuest: isGuest,
                            isSaved: true,
                            currencyCode:
                                context
                                    .read<AuthCubit>()
                                    .currentUser
                                    ?.currency ??
                                'syp',
                            userGroup:
                                context.read<AuthCubit>().currentUser?.group ??
                                '',
                            onTap: () => context.push(
                              AppRoutePaths.productUrl(product.id),
                              extra: product,
                            ),
                            onToggleSave: () async {
                              await context.read<ProductCubit>().toggleSaved(
                                product.id,
                              );
                              await _reload();
                            },
                            onAddToCart: (unit) => _addToCart(product, unit),
                            onShare: () => SharePlus.instance.share(
                              ShareParams(text: buildProductShareText(product)),
                            ),
                          );
                        }, childCount: filtered.length),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _skeleton() {
    final isGuest = context.read<AuthCubit>().state is! Authenticated;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14, _topContentPadding(context), 14, 10),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SkeletonBlock(
          height: ProductCard.preferredGridExtent(isGuest: isGuest),
        ),
      ),
    );
  }

  Future<void> _addToCart(ProductModel product, ProductCardUnit unit) async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      await context.push(AppRoutePaths.login);
      return;
    }

    await context.read<CartCubit>().addToCart(
      CartItemModel(
        productId: product.id,
        name: product.name,
        price: unit.price.toString(),
        image: product.firstImage,
        selectedVariants: const <String, dynamic>{},
        unitType: unit.type,
        unitLabel: unit.label,
        piecesCount: unit.piecesCount,
        currency: authState.user.currency,
      ),
    );

    if (!mounted || context.read<CartCubit>().state is CartCurrencyConflict) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تمت الإضافة إلى السلة')));
  }
}

class _SavedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onPressed;
  final bool compact;

  const _SavedEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          compact ? 8 : 18,
          16,
          compact ? 8 : 18,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4E9F1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: compact ? 34 : 44,
                color: const Color(0xFF8E97A6),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 16 : 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6F7888),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onPressed, child: Text(ctaLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
