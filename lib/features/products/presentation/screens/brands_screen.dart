import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/theme/app_colors.dart';
import 'package:lpco_llc/core/widgets/app_drawer.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/features/products/data/models/brand_model.dart';
import 'package:lpco_llc/features/products/domain/catalog_visibility_policy.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';
import 'package:lpco_llc/features/products/presentation/utils/brand_scoped_category_resolver.dart';
import 'package:lpco_llc/features/products/presentation/widgets/brand_quick_categories_tile.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BrandScopedCategoryResolver _brandCategoryResolver =
      const BrandScopedCategoryResolver();
  final RefreshController _refreshController = RefreshController();

  double _topContentPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        BrandAppBar.toolbarHeightValue +
        14;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final productCubit = context.read<ProductCubit>();
      final productState = productCubit.state;
      if (productState.brands.isEmpty || productState.categories.isEmpty) {
        productCubit.initialize(forceRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onPullToRefresh() async {
    await context.read<ProductCubit>().refresh(forceRemote: true);
    if (!mounted) {
      return;
    }
    final state = context.read<ProductCubit>().state;
    if (state.status == ProductStatus.error && state.brands.isEmpty) {
      _refreshController.refreshFailed();
    } else {
      _refreshController.refreshCompleted();
    }
  }

  List<BrandModel> _filter(List<BrandModel> visibleBrands) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return visibleBrands;
    }
    return visibleBrands
        .where((brand) => brand.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BrandAppBar(
        title: 'العلامات التجارية',
        showMenu: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'فتح البحث',
            onPressed: () => context.go(
              AppRoutePaths.catalogSearchEntry(
                entry: 'shortcut',
                basePath: AppRoutePaths.brandsCatalog,
              ),
            ),
          ),
        ],
      ),
      drawer: const AppSideDrawer(),
      body: BlocBuilder<ProductCubit, ProductState>(
        builder: (context, state) {
          final visibleBrands = state.brands
              .where(CatalogVisibilityPolicy.isVisibleBrand)
              .toList(growable: false);
          final filtered = _filter(visibleBrands);
          final isLoading =
              state.status == ProductStatus.loading && state.brands.isEmpty;

          if (isLoading) {
            return AppSkeleton(enabled: true, child: _skeleton());
          }

          return SmartRefresher(
            controller: _refreshController,
            enablePullDown: true,
            onRefresh: _onPullToRefresh,
            header: const WaterDropHeader(
              complete: Icon(Icons.check_rounded, color: AppColors.success),
              failed: Icon(Icons.error_outline, color: AppColors.error),
            ),
            child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    _topContentPadding(context),
                    14,
                    10,
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'ابحث داخل العلامات',
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
                ),
              ),
              SliverToBoxAdapter(
                child: _BrandsHeaderBlock(
                  onGoHome: () => context.go(AppRoutePaths.home),
                ),
              ),
              if (visibleBrands.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyBrowseState(
                    icon: Icons.sell_rounded,
                    title: 'لا توجد علامات متاحة',
                    subtitle: 'سيتم عرض العلامات التجارية هنا عند توفرها.',
                    ctaLabel: 'العودة للرئيسية',
                    onPressed: () => context.go(AppRoutePaths.home),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyBrowseState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج مطابقة',
                    subtitle: 'غيّر عبارة البحث أو امسحها لعرض كل العلامات.',
                    ctaLabel: 'مسح البحث',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                )
              else ...<Widget>[
                SliverToBoxAdapter(
                  child: _TopBrandsStrip(
                    brands: visibleBrands.take(12).toList(growable: false),
                    onTapBrand: (brand) =>
                        context.push(AppRoutePaths.brandUrl(brand.slug)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  sliver: SliverToBoxAdapter(
                    child: _SimpleBrandListTile(
                      title: 'كل العلامات',
                      subtitle: '${visibleBrands.length} علامة',
                      onTap: () => context.push(
                        AppRoutePaths.catalogListing(
                          basePath: AppRoutePaths.brandsCatalog,
                          type: 'brand',
                          title: 'كل العلامات',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final brand = filtered[index];
                      final normalizedBrandSlug =
                          BrandScopedCategoryResolver.normalizeBrandKey(
                            brand.slug,
                          );
                      final productDerivedCategoryIds = context
                          .read<ProductCubit>()
                          .getActiveCategoryIdsForBrand(brand.slug);
                      final rawResolvedMenu = _brandCategoryResolver.resolve(
                        brand: brand,
                        brandSlug: brand.slug,
                        brandTitle: brand.name,
                        categories: state.categories,
                        productDerivedCategoryIds: productDerivedCategoryIds,
                      );
                      final fallbackAvailableCategoryIds =
                          rawResolvedMenu?.items
                              .where((item) => item.category.count > 0)
                              .map((item) => item.categoryId)
                              .toSet() ??
                          const <int>{};
                      final finalAvailableCategoryIds = <int>{
                        ...fallbackAvailableCategoryIds,
                        ...productDerivedCategoryIds,
                      };
                      final filteredMenu = rawResolvedMenu == null
                          ? null
                          : _brandCategoryResolver.filterByAvailableCategories(
                              menu: rawResolvedMenu,
                              availableCategoryIds: finalAvailableCategoryIds,
                            );
                      final displayedMenu =
                          filteredMenu ?? rawResolvedMenu;
                      _logBrandCategoryResolution(
                        brandSlug: normalizedBrandSlug,
                        brandName: brand.name,
                        rawMenu: rawResolvedMenu,
                        productDerivedCategoryIds: productDerivedCategoryIds,
                        fallbackAvailableCategoryIds:
                            fallbackAvailableCategoryIds,
                        finalAvailableCategoryIds: finalAvailableCategoryIds,
                        displayedMenu: displayedMenu,
                      );
                      return BrandQuickCategoriesTile(
                        brandSlug: brand.slug,
                        title: brand.name,
                        subtitle: '${brand.count} منتج',
                        imageUrl: brand.imageUrl,
                        resolvedCuratedMenu: displayedMenu,
                        onTapBrand: () {
                          context.push(
                            AppRoutePaths.brandUrl(normalizedBrandSlug),
                          );
                        },
                        onTapCategory: displayedMenu == null
                            ? null
                            : (cat) => context.push(
                                AppRoutePaths.brandUrl(
                                  normalizedBrandSlug,
                                  title: '${brand.name} - ${cat.name}',
                                  curatedCategoryId: cat.id,
                                  curatedCategorySlug: cat.slug,
                                  curatedCategoryLabel: cat.name,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ],
            ),
          );
        },
      ),
    );
  }

  void _logBrandCategoryResolution({
    required String brandSlug,
    required String brandName,
    required ResolvedBrandScopedCategoryMenu? rawMenu,
    required Set<int> productDerivedCategoryIds,
    required Set<int> fallbackAvailableCategoryIds,
    required Set<int> finalAvailableCategoryIds,
    required ResolvedBrandScopedCategoryMenu? displayedMenu,
  }) {
    if (!kDebugMode) {
      return;
    }

    final rawSlugs =
        rawMenu?.items
            .map((item) => item.categorySlug)
            .toList(growable: false) ??
        const <String>[];
    final displayedSlugs =
        displayedMenu?.items
            .map((item) => item.categorySlug)
            .toList(growable: false) ??
        const <String>[];

    debugPrint(
      '[BRAND_CATEGORY_LINK] brand="$brandName" slug=$brandSlug',
    );
    debugPrint(
      '[BRAND_CATEGORY_LINK]   rawResolvedMenu slugs: $rawSlugs',
    );
    debugPrint(
      '[BRAND_CATEGORY_LINK]   productDerivedCategoryIds: $productDerivedCategoryIds',
    );
    debugPrint(
      '[BRAND_CATEGORY_LINK]   fallbackAvailableCategoryIds: $fallbackAvailableCategoryIds',
    );
    debugPrint(
      '[BRAND_CATEGORY_LINK]   finalAvailableCategoryIds (union): $finalAvailableCategoryIds',
    );
    debugPrint(
      '[BRAND_CATEGORY_LINK]   final displayed slugs: $displayedSlugs',
    );
  }

  Widget _skeleton() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(14, _topContentPadding(context), 14, 22),
      itemCount: 7,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => const SkeletonBlock(height: 78),
    );
  }
}

class _BrandsHeaderBlock extends StatelessWidget {
  final VoidCallback onGoHome;

  const _BrandsHeaderBlock({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C222D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C3441)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'اختر العلامة التجارية للوصول إلى منتجاتها بسرعة، ويمكنك أيضاً فتح التصنيفات الجاهزة من السهم.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onGoHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE7ECF4)),
              ),
              child: const Text('الرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBrandsStrip extends StatelessWidget {
  final List<BrandModel> brands;
  final ValueChanged<BrandModel> onTapBrand;

  const _TopBrandsStrip({required this.brands, required this.onTapBrand});

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final brand = brands[index];
          return ActionChip(
            avatar: const Icon(Icons.sell_rounded, size: 16),
            label: Text(brand.name),
            onPressed: () => onTapBrand(brand),
          );
        },
      ),
    );
  }
}

class _SimpleBrandListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SimpleBrandListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E9F1)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0E0B1524),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.sell_rounded, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF737C8A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF9BA4B2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBrowseState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onPressed;

  const _EmptyBrowseState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 46, color: const Color(0xFF8C95A4)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6E7786),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: onPressed, child: Text(ctaLabel)),
          ],
        ),
      ),
    );
  }
}
