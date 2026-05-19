import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/widgets/app_drawer.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';
import 'package:lpco_llc/core/widgets/app_skeleton.dart';
import 'package:lpco_llc/core/widgets/brand_app_bar.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/products/data/models/category_model.dart';
import 'package:lpco_llc/features/products/presentation/cubit/categories_cubit.dart';

Map<int, List<CategoryModel>> _buildChildrenMap(
  List<CategoryModel> categories,
) {
  final map = <int, List<CategoryModel>>{};
  for (final category in categories) {
    if (category.parentId <= 0) {
      continue;
    }
    map.putIfAbsent(category.parentId, () => <CategoryModel>[]).add(category);
  }

  return map;
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isGuest = context.read<AuthCubit>().state is! Authenticated;

    return BlocProvider(
      create: (_) => CategoriesCubit(isGuest: isGuest)..initialize(),
      child: const _CategoriesView(),
    );
  }
}

class _CategoriesView extends StatefulWidget {
  const _CategoriesView();

  @override
  State<_CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<_CategoriesView> {
  final Set<int> _expandedIds = <int>{};

  double _topContentPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        BrandAppBar.toolbarHeightValue +
        14;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BrandAppBar(
        title: 'التصفح',
        showMenu: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'فتح البحث',
            onPressed: () => context.go(
              AppRoutePaths.catalogSearchEntry(
                entry: 'shortcut',
                basePath: AppRoutePaths.categoriesCatalog,
              ),
            ),
          ),
        ],
      ),
      drawer: const AppSideDrawer(),
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          if (state.status == CategoriesStatus.loading &&
              state.categories.isEmpty) {
            return AppSkeleton(
              enabled: true,
              child: const _CategoriesSkeleton(),
            );
          }

          if (state.status == CategoriesStatus.error &&
              state.categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.error_outline_rounded, size: 42),
                    const SizedBox(height: 10),
                    Text(
                      state.errorMessage.isEmpty
                          ? 'تعذر تحميل الأقسام حالياً.'
                          : state.errorMessage,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.read<CategoriesCubit>().refresh(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = state.categories;
          final mainCategories = categories
              .where((c) => c.parentId <= 0)
              .toList();
          final childrenMap = _buildChildrenMap(categories);

          return RefreshIndicator(
            onRefresh: () => context.read<CategoriesCubit>().refresh(),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                14,
                _topContentPadding(context),
                14,
                24,
              ),
              itemCount: mainCategories.isEmpty ? 2 : mainCategories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _CategoriesHeaderBlock(),
                  );
                }

                if (mainCategories.isEmpty) {
                  return const _EmptyCategories();
                }

                final parent = mainCategories[index - 1];
                final children =
                    childrenMap[parent.id] ?? const <CategoryModel>[];
                final isExpanded = _expandedIds.contains(parent.id);
                final hasChildren = children.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _CategoryParentTile(
                        category: parent,
                        hasChildren: hasChildren,
                        isExpanded: isExpanded,
                        onTap: () => _openCategory(parent),
                        onArrowTap: hasChildren
                            ? () => _toggleExpand(parent.id)
                            : null,
                      ),
                      _AnimatedChildrenSection(
                        isExpanded: isExpanded,
                        children: children,
                        onChildTap: _openCategory,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _toggleExpand(int parentId) {
    setState(() {
      if (_expandedIds.contains(parentId)) {
        _expandedIds.remove(parentId);
      } else {
        _expandedIds.add(parentId);
      }
    });
  }

  void _openCategory(CategoryModel category) {
    final uri = AppRoutePaths.catalogListing(
      basePath: AppRoutePaths.categoriesCatalog,
      type: 'category',
      id: '${category.id}',
      title: category.name,
    );
    context.push(uri);
  }
}

class _CategoriesHeaderBlock extends StatelessWidget {
  const _CategoriesHeaderBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C222D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C3441)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              SizedBox(
                width: 56,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x22FFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Icon(
                    Icons.account_tree_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تصفح الأقسام الرئيسية وافتح الأقسام الفرعية من السهم، تماماً بمنطق تصفح أوضح وأسرع.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AppRoutePaths.home),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE7ECF4)),
            ),
            child: const Text('الرئيسية'),
          ),
          const SizedBox(height: 14),
          const Text(
            'الأقسام الرئيسية',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryParentTile extends StatelessWidget {
  final CategoryModel category;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onArrowTap;

  const _CategoryParentTile({
    required this.category,
    required this.hasChildren,
    required this.isExpanded,
    required this.onTap,
    required this.onArrowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: AppNetworkImage(
                            imageUrl: category.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: const Color(0xFFF1F4F8),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.grid_view_rounded,
                                size: 20,
                              ),
                            ),
                            errorWidget: Container(
                              color: const Color(0xFFF1F4F8),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.grid_view_rounded,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${category.count} منتج',
                              style: const TextStyle(
                                color: Color(0xFF737C8A),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasChildren)
            IconButton(
              tooltip: isExpanded
                  ? 'إغلاق الأقسام الفرعية'
                  : 'عرض الأقسام الفرعية',
              onPressed: onArrowTap,
              icon: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: Color(0xFF6B7280),
                ),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _AnimatedChildrenSection extends StatelessWidget {
  final bool isExpanded;
  final List<CategoryModel> children;
  final ValueChanged<CategoryModel> onChildTap;

  const _AnimatedChildrenSection({
    required this.isExpanded,
    required this.children,
    required this.onChildTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: !isExpanded || children.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey<String>('expanded_children'),
              padding: const EdgeInsetsDirectional.only(start: 26, top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children
                    .map((child) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CategoryChildTile(
                          category: child,
                          onTap: () => onChildTap(child),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
    );
  }
}

class _CategoryChildTile extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryChildTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E9F1)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.subdirectory_arrow_left_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${category.count}',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.grid_view_rounded, size: 46, color: Color(0xFF8C95A4)),
            SizedBox(height: 10),
            Text(
              'لا توجد أقسام متاحة حالياً',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        14,
        MediaQuery.paddingOf(context).top + BrandAppBar.toolbarHeightValue + 14,
        14,
        24,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SkeletonBlock(height: 78),
        );
      },
    );
  }
}
