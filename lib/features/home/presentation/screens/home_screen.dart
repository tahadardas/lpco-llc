import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:share_plus/share_plus.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lpco_llc/app/router/app_routes.dart';

import 'package:lpco_llc/core/theme/app_colors.dart';
import 'package:lpco_llc/core/theme/app_radius.dart';
import 'package:lpco_llc/core/theme/app_spacing.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/core/widgets/app_drawer.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/core/widgets/glass.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/cart/data/models/cart_item_model.dart';
import 'package:lpco_llc/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lpco_llc/features/cart/presentation/widgets/cart_currency_conflict_dialog.dart';
import 'package:lpco_llc/features/notifications/presentation/cubit/notifications_badge_cubit.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/utils/product_share_link.dart';
import 'package:lpco_llc/features/products/presentation/widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final RefreshController _refreshController = RefreshController();
  bool _initialized = false;
  int _activeHeroIndex = 0;

  bool get _isGuest => context.read<AuthCubit>().state is! Authenticated;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _syncScope();
    context.read<ProductCubit>().initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onPullToRefresh() async {
    await context.read<ProductCubit>().refresh();
    if (!mounted) {
      return;
    }
    final state = context.read<ProductCubit>().state;
    if (state.status == ProductStatus.error) {
      _refreshController.refreshFailed();
    } else {
      _refreshController.refreshCompleted();
    }
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

  void _onScroll() {
    final state = context.read<ProductCubit>().state;
    if (state.status == ProductStatus.loadingMore ||
        state.status == ProductStatus.loading ||
        !state.hasMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 280) {
      context.read<ProductCubit>().loadMore();
    }
  }

  Future<void> _scanFromHome() async {
    final code = await context.push<String>(AppRoutePaths.scannerSearchEntry());
    if (!mounted || code == null) return;
    final normalized = code.trim();
    if (normalized.isEmpty) return;
    context.push(
      AppRoutePaths.catalogSearchEntry(
        entry: 'home',
        search: normalized,
        basePath: AppRoutePaths.catalog,
      ),
    );
  }

  void _openSearchHub() {
    context.push(
      AppRoutePaths.catalogSearchEntry(
        entry: 'home',
        basePath: AppRoutePaths.catalog,
      ),
    );
  }

  void _openCategoryListing(int categoryId, String title) {
    context.push(AppRoutePaths.categoryUrl(categoryId));
  }

  void _openBrandListing(String brandSlug, String title) {
    context.push(AppRoutePaths.brandUrl(brandSlug));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            _syncScope();
            context.read<ProductCubit>().refresh();
          },
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
        extendBody: false,
        extendBodyBehindAppBar: false,
        appBar: BrandAppBar(
          showMenu: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: _scanFromHome,
            ),
            BlocBuilder<NotificationsBadgeCubit, int>(
              builder: (context, unreadCount) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_active_rounded),
                      onPressed: () => context.go(AppRoutePaths.notifications),
                    ),
                    if (unreadCount > 0)
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD31225),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_rounded),
              onPressed: () => context.go(AppRoutePaths.account),
            ),
          ],
        ),
        drawer: const AppSideDrawer(),
        body: BlocBuilder<ProductCubit, ProductState>(
          builder: (context, productState) {
            if (productState.status == ProductStatus.loading &&
                productState.products.isEmpty &&
                productState.categories.isEmpty &&
                productState.brands.isEmpty) {
              return _loadingStateView(productState: productState);
            }

            if (productState.status == ProductStatus.error &&
                productState.products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productState.errorMessage,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.read<ProductCubit>().refresh(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            final products = productState.products;

            return SmartRefresher(
              controller: _refreshController,
              enablePullDown: true,
              onRefresh: _onPullToRefresh,
              header: const WaterDropHeader(
                complete: Icon(Icons.check_rounded, color: AppColors.success),
                failed: Icon(Icons.error_outline, color: AppColors.error),
              ),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _searchBar()),
                  SliverToBoxAdapter(
                    child: _sectionCard(child: _heroBanner(productState)),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      title: 'تصفح الأقسام',
                      child: _quickCategories(productState),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      title: 'تسوق حسب العلامة',
                      child: _quickBrands(productState),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      title: 'منتجات مميزة',
                      child: _featuredProducts(
                        products: products,
                        productState: productState,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Row(
                        children: [
                          const Text(
                            'أحدث المنتجات',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
                    sliver: products.isNotEmpty
                        ? SliverGrid(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = products[index];
                              return ProductCard(
                                product: product,
                                isGuest: _isGuest,
                                isSaved: productState.savedProductIds.contains(
                                  product.id,
                                ),
                                currencyCode:
                                    context
                                        .read<AuthCubit>()
                                        .currentUser
                                        ?.currency ??
                                    'syp',
                                userGroup:
                                    context
                                        .read<AuthCubit>()
                                        .currentUser
                                        ?.group ??
                                    '',
                                onTap: () => context.push(
                                  AppRoutePaths.productUrl(product.id),
                                  extra: product,
                                ),
                                onToggleSave: () => context
                                    .read<ProductCubit>()
                                    .toggleSaved(product.id),
                                onAddToCart: (unit) =>
                                    _addToCart(product, unit),
                                onShare: () => _shareProduct(product),
                              );
                            }, childCount: products.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent:
                                      ProductCard.preferredGridExtent(
                                        isGuest: _isGuest,
                                      ),
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                          )
                        : (!productState.initialSyncDone
                              ? SliverGrid(
                                  delegate: SliverChildListDelegate.fixed(
                                    <Widget>[
                                      SkeletonBlock(
                                        height: ProductCard.preferredGridExtent(
                                          isGuest: _isGuest,
                                        ),
                                      ),
                                      SkeletonBlock(
                                        height: ProductCard.preferredGridExtent(
                                          isGuest: _isGuest,
                                        ),
                                      ),
                                      SkeletonBlock(
                                        height: ProductCard.preferredGridExtent(
                                          isGuest: _isGuest,
                                        ),
                                      ),
                                      SkeletonBlock(
                                        height: ProductCard.preferredGridExtent(
                                          isGuest: _isGuest,
                                        ),
                                      ),
                                    ],
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisExtent:
                                            ProductCard.preferredGridExtent(
                                              isGuest: _isGuest,
                                            ),
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                )
                              : const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text(
                                        'لا توجد منتجات حالياً',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                )),
                  ),
                  if (productState.status == ProductStatus.loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Center(child: CircularProgressIndicator()),
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

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: TextField(
        controller: _searchController,
        readOnly: true,
        onTap: _openSearchHub,
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج أو SKU أو باركود...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: _openSearchHub,
          ),
        ),
      ),
    );
  }

  Widget _heroBanner(ProductState state) {
    final slides = _buildHeroSlides(state);
    final activeIndex = _activeHeroIndex >= slides.length
        ? 0
        : _activeHeroIndex;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 178,
        child: Stack(
          children: <Widget>[
            Swiper(
              itemCount: slides.length,
              autoplay: slides.length > 1,
              autoplayDelay: 4600,
              duration: 440,
              viewportFraction: 1,
              scale: 1,
              onTap: (index) => slides[index].onTap(),
              onIndexChanged: (index) {
                if (!mounted) {
                  return;
                }
                setState(() => _activeHeroIndex = index);
              },
              itemBuilder: (context, index) {
                final slide = slides[index];
                return DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF28344B), Color(0xFF111827)],
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Opacity(
                          opacity: 1.0,
                          child: AppNetworkImage(
                            imageUrl: slide.imageUrl,
                            fit: BoxFit.contain,
                            placeholder: Container(color: Colors.transparent),
                            errorWidget: const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (slide.title.trim().isNotEmpty)
                              Text(
                                TextSanitizer.fix(slide.title),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                            if (slide.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                TextSanitizer.fix(slide.subtitle),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (slide.ctaLabel.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 34,
                                child: FilledButton.tonal(
                                  onPressed: slide.onTap,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    TextSanitizer.fix(slide.ctaLabel),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            PositionedDirectional(
              start: 16,
              bottom: 12,
              child: AnimatedSmoothIndicator(
                activeIndex: activeIndex,
                count: slides.length,
                effect: WormEffect(
                  dotWidth: 8,
                  dotHeight: 8,
                  spacing: 6,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white.withValues(alpha: 0.42),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_HeroSlideData> _buildHeroSlides(ProductState state) {
    final slides = <_HeroSlideData>[];

    final banners = state.homeBanners.where((b) => b.enabled).take(30).toList();
    for (final banner in banners) {
      slides.add(
        _HeroSlideData(
          imageUrl: banner.imageUrl,
          title: banner.title.isNotEmpty ? banner.title : 'عروض المتجر الكبرى',
          subtitle: banner.subtitle.isNotEmpty
              ? banner.subtitle
              : 'تحديثات يومية للمنتجات والعروض',
          ctaLabel: banner.buttonLabel.isNotEmpty
              ? banner.buttonLabel
              : 'تسوق الآن',
          onTap: () => _openHeroLink(banner.buttonLink),
        ),
      );
    }

    if (slides.isEmpty) {
      final bannerImage = state.homeBannerImageUrl.trim();
      final bannerTitle = state.homeBannerTitle.trim();
      final bannerSubtitle = state.homeBannerSubtitle.trim();
      final bannerButtonLabel = state.homeBannerButtonLabel.trim();
      final bannerLink = state.homeBannerButtonLink.trim();

      if (state.homeBannerEnabled &&
          (bannerImage.isNotEmpty ||
              bannerTitle.isNotEmpty ||
              bannerSubtitle.isNotEmpty ||
              state.products.isEmpty)) {
        slides.add(
          _HeroSlideData(
            imageUrl: bannerImage,
            title: bannerTitle.isNotEmpty ? bannerTitle : 'عروض المتجر الكبرى',
            subtitle: bannerSubtitle.isNotEmpty
                ? bannerSubtitle
                : 'تحديثات يومية للمنتجات والعروض',
            ctaLabel: bannerButtonLabel.isNotEmpty
                ? bannerButtonLabel
                : 'تسوق الآن',
            onTap: () => _openHeroLink(bannerLink),
          ),
        );
      }
    }

    // 2. Banner Products (Dynamic/Manual)
    if (slides.isEmpty) {
      final List<ProductModel> productsToShow = state.bannerProducts.isNotEmpty
          ? state.bannerProducts
          : state.products.where((product) => product.inStock).take(4).toList();

      for (final product in productsToShow) {
        final categoryName = product.categories.isNotEmpty
            ? product.categories.first.name
            : 'منتج مميز';
        slides.add(
          _HeroSlideData(
            imageUrl: product.firstImage,
            title: product.name,
            subtitle: categoryName,
            ctaLabel: 'عرض المنتج',
            onTap: () => context.push(
              AppRoutePaths.productUrl(product.id),
              extra: product,
            ),
          ),
        );
      }
    }

    if (slides.isEmpty) {
      slides.add(
        _HeroSlideData(
          imageUrl: '',
          title: 'اكتشف الكتالوج',
          subtitle: 'ابحث عن المنتجات حسب الاسم أو الباركود',
          ctaLabel: 'ابدأ البحث',
          onTap: _openSearchHub,
        ),
      );
    }

    return slides;
  }

  Future<void> _openHeroLink(String rawLink) async {
    final link = rawLink.trim();
    if (link.isEmpty) {
      _openSearchHub();
      return;
    }

    final lower = link.toLowerCase();
    if (lower.startsWith('product:')) {
      final id = int.tryParse(lower.replaceFirst('product:', ''));
      if (id != null) {
        context.push(AppRoutePaths.productUrl(id));
        return;
      }
    } else if (lower.startsWith('category:')) {
      final id = int.tryParse(lower.replaceFirst('category:', ''));
      if (id != null) {
        context.push(AppRoutePaths.categoryUrl(id));
        return;
      }
    } else if (lower.startsWith('brand:')) {
      final slug = lower.replaceFirst('brand:', '').trim();
      if (slug.isNotEmpty) {
        context.push(AppRoutePaths.brandUrl(slug));
        return;
      }
    } else if (lower.startsWith('search:')) {
      final term = lower.replaceFirst('search:', '').trim();
      if (term.isNotEmpty) {
        context.push(AppRoutePaths.searchUrl(query: term));
        return;
      }
    } else if (lower == 'catalog') {
      context.push(AppRoutePaths.catalog);
      return;
    } else if (lower == 'categories') {
      context.push(AppRoutePaths.categories);
      return;
    } else if (lower == 'brands') {
      context.push(AppRoutePaths.brands);
      return;
    } else if (lower == 'cart') {
      context.push(AppRoutePaths.cart);
      return;
    } else if (lower == 'account') {
      context.push(AppRoutePaths.account);
      return;
    }

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (link.startsWith('/')) {
      context.push(link);
      return;
    }

    _openSearchHub();
  }

  Widget _quickCategories(ProductState state) {
    final categories = _mainCategoriesForHome(state.categories);
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return SizedBox(
            width: 86,
            child: TapScale(
              onTap: () => _openCategoryListing(category.id, category.name),
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE4E9F1)),
                    ),
                    child: ClipOval(
                      child: AppNetworkImage(
                        imageUrl: category.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: const Color(0xFFF0F2F6),
                          alignment: Alignment.center,
                          child: const Icon(Icons.grid_view_rounded, size: 20),
                        ),
                        errorWidget: Container(
                          color: const Color(0xFFF0F2F6),
                          alignment: Alignment.center,
                          child: const Icon(Icons.grid_view_rounded, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<CategoryModel> _mainCategoriesForHome(List<CategoryModel> categories) {
    return categories
        .where((category) => category.parentId <= 0)
        .toList(growable: false);
  }

  Widget _quickBrands(ProductState state) {
    final brands = state.brands
        .where((brand) => brand.name.isNotEmpty)
        .take(10)
        .toList(growable: false);
    if (brands.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final brand = brands[index];
          return ActionChip(
            avatar: const Icon(Icons.sell_rounded, size: 16),
            label: Text(
              brand.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => _openBrandListing(brand.slug, brand.name),
          );
        },
      ),
    );
  }

  Widget _featuredProducts({
    required List<ProductModel> products,
    required ProductState productState,
  }) {
    final inStockProducts = products
        .where((product) => product.inStock)
        .toList(growable: false);
    final featured = inStockProducts
        .where((product) => product.isFeatured)
        .take(8)
        .toList(growable: false);
    final featuredProducts = featured.isNotEmpty
        ? featured
        : (inStockProducts.length > 8
              ? inStockProducts.reversed.take(8).toList(growable: false)
              : inStockProducts.take(8).toList(growable: false));

    if (featuredProducts.isEmpty) {
      if (!productState.initialSyncDone) {
        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, _) => const SkeletonBlock(width: 214, height: 210),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Text('لا توجد منتجات مميزة حالياً')),
      );
    }

    return SizedBox(
      height: ProductCard.preferredFeaturedExtent(isGuest: _isGuest),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: featuredProducts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = featuredProducts[index];
          return SizedBox(
            width: 214,
            child: ProductCard(
              product: product,
              isGuest: _isGuest,
              isSaved: productState.savedProductIds.contains(product.id),
              currencyCode:
                  context.read<AuthCubit>().currentUser?.currency ?? 'syp',
              userGroup: context.read<AuthCubit>().currentUser?.group ?? '',
              onTap: () => context.push(
                AppRoutePaths.productUrl(product.id),
                extra: product,
              ),
              onToggleSave: () =>
                  context.read<ProductCubit>().toggleSaved(product.id),
              onAddToCart: (unit) => _addToCart(product, unit),
              onShare: () => _shareProduct(product),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard({String? title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: const Color(0xFFE6EAF1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120B1524),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title.trim().isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _loadingStateView({required ProductState productState}) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _searchBar()),
        SliverToBoxAdapter(
          child: _sectionCard(child: _heroBanner(productState)),
        ),
        SliverToBoxAdapter(
          child: _sectionCard(
            title: 'تصفح الأقسام',
            child: _quickCategories(productState),
          ),
        ),
        SliverToBoxAdapter(
          child: _sectionCard(
            title: 'تسوق حسب العلامة',
            child: const SkeletonBlock(height: 42),
          ),
        ),
        SliverToBoxAdapter(
          child: _sectionCard(
            title: 'منتجات مميزة',
            child: const SkeletonBlock(height: 210),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Text(
              'جاري تحميل المنتجات',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate.fixed(<Widget>[
              SkeletonBlock(
                height: ProductCard.preferredGridExtent(isGuest: _isGuest),
              ),
              SkeletonBlock(
                height: ProductCard.preferredGridExtent(isGuest: _isGuest),
              ),
              SkeletonBlock(
                height: ProductCard.preferredGridExtent(isGuest: _isGuest),
              ),
              SkeletonBlock(
                height: ProductCard.preferredGridExtent(isGuest: _isGuest),
              ),
            ]),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: ProductCard.preferredGridExtent(
                isGuest: _isGuest,
              ),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          ),
        ),
      ],
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
        selectedVariants: const {},
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
    ).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى السلة')));
  }

  void _shareProduct(ProductModel product) {
    SharePlus.instance.share(ShareParams(text: buildProductShareText(product)));
  }
}

class _HeroSlideData {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  const _HeroSlideData({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });
}
