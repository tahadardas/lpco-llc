import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/app/shell/navigation_shell.dart';

import 'package:lpco_llc/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_module_screen.dart';
import 'package:lpco_llc/features/admin/presentation/screens/admin_order_details_screen.dart';
import 'package:lpco_llc/features/account/presentation/screens/account_screen.dart';
import 'package:lpco_llc/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:lpco_llc/features/account/presentation/screens/security_settings_screen.dart';
import 'package:lpco_llc/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:lpco_llc/features/auth/presentation/screens/login_screen.dart';
import 'package:lpco_llc/features/auth/presentation/screens/register_screen.dart';
import 'package:lpco_llc/features/cart/presentation/screens/cart_screen.dart';
import 'package:lpco_llc/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:lpco_llc/features/contact/presentation/screens/contact_screen.dart';
import 'package:lpco_llc/features/home/presentation/screens/home_screen.dart';
import 'package:lpco_llc/features/jobs/presentation/screens/jobs_screen.dart';
import 'package:lpco_llc/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:lpco_llc/features/orders/presentation/screens/orders_screen.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/presentation/screens/order_details_screen.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/products/presentation/screens/brands_screen.dart';
import 'package:lpco_llc/features/products/presentation/screens/catalog_products_screen.dart';
import 'package:lpco_llc/features/products/presentation/screens/categories_screen.dart';
import 'package:lpco_llc/features/products/presentation/screens/product_details_screen.dart';
import 'package:lpco_llc/features/products/presentation/screens/saved_products_screen.dart';
import 'package:lpco_llc/features/products/presentation/screens/scanner_screen.dart';
import 'package:lpco_llc/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:lpco_llc/features/legal/presentation/screens/terms_of_use_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<NavigatorState> homeBranchNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> catalogBranchNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> brandsBranchNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> favoritesBranchNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> cartBranchNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> profileBranchNavigatorKey =
      GlobalKey<NavigatorState>();

  static Map<String, String> _safeQueryParameters(Uri uri) {
    try {
      return uri.queryParameters;
    } on ArgumentError {
      return const <String, String>{};
    } on FormatException {
      return const <String, String>{};
    }
  }

  static Widget _catalogBuilder(BuildContext context, GoRouterState state) {
    final qp = _safeQueryParameters(state.uri);
    final type = qp['type'] ?? '';
    final title = qp['title'] ?? 'المنتجات';
    final isSearchEntry = qp['focus'] == '1' && type.isEmpty;
    final initialSearch = qp['search'] ?? '';

    if (type == 'category') {
      return CatalogProductsScreen(
        title: title,
        categoryId: int.tryParse(qp['id'] ?? ''),
      );
    }

    if (type == 'brand') {
      final rawSlug = qp['slug'];
      return CatalogProductsScreen(
        title: title,
        brandSlug: (rawSlug == null || rawSlug.isEmpty) ? null : rawSlug,
        initialCuratedCategoryId: int.tryParse(qp['curatedCategoryId'] ?? ''),
        initialCuratedCategorySlug: qp['curatedCategorySlug'],
        initialCuratedCategoryLabel: qp['curatedCategoryLabel'],
      );
    }

    return CatalogProductsScreen(
      title: title,
      initialSearch: initialSearch,
      requireExplicitSearch: isSearchEntry,
      autoFocusSearch: isSearchEntry,
    );
  }

  static bool _isAdminUser(AuthCubit authCubit) {
    final user = authCubit.currentUser;
    if (user == null || user.isGuest) {
      return false;
    }

    final roles = user.roles.map((e) => e.toLowerCase()).toSet();
    if (roles.contains('administrator') ||
        roles.contains('shop_manager') ||
        roles.contains('editor')) {
      return true;
    }

    final group = user.group.toLowerCase();
    return group.contains('admin') || group.contains('manager');
  }

  static bool _hasAuthenticatedSession(AuthState auth) {
    return auth is Authenticated ||
        auth is AuthLocked ||
        auth is AuthSecuritySetupRequired;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutePaths.home,
    redirect: (context, state) {
      final uri = state.uri;
      final isCatalogPath =
          uri.path == AppRoutePaths.catalog ||
          uri.path == AppRoutePaths.categoriesCatalog ||
          uri.path == AppRoutePaths.brandsCatalog;

      if (isCatalogPath && uri.queryParameters['focus'] == '1') {
        final entry = uri.queryParameters['entry'];
        final explicitEntry =
            entry == 'nav' || entry == 'shortcut' || entry == 'home';
        if (!explicitEntry) {
          return AppRoutePaths.home;
        }
      }

      if (uri.scheme == 'lpco') {
        final queryParameters = _safeQueryParameters(uri);
        final host = uri.host.trim().toLowerCase();
        final segments = uri.pathSegments
            .where((segment) => segment.trim().isNotEmpty)
            .toList(growable: false);

        Uri? mappedUri;
        if (host == 'product' && segments.isNotEmpty) {
          mappedUri = Uri(
            path: '/product/${segments.first}',
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
          );
        } else if (host == 'category' && segments.isNotEmpty) {
          mappedUri = Uri(
            path: '/category/${segments.first}',
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
          );
        } else if (host == 'brand' && segments.isNotEmpty) {
          mappedUri = Uri(
            path: '/brand/${segments.first}',
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
          );
        } else if (host.isEmpty && segments.length >= 2) {
          final entity = segments.first.toLowerCase();
          final value = segments[1];
          if (entity == 'product') {
            mappedUri = Uri(
              path: '/product/$value',
              queryParameters: queryParameters.isEmpty ? null : queryParameters,
            );
          } else if (entity == 'category') {
            mappedUri = Uri(
              path: '/category/$value',
              queryParameters: queryParameters.isEmpty ? null : queryParameters,
            );
          } else if (entity == 'brand') {
            mappedUri = Uri(
              path: '/brand/$value',
              queryParameters: queryParameters.isEmpty ? null : queryParameters,
            );
          }
        }

        if (mappedUri != null) {
          return mappedUri.toString();
        }
      }

      // Handle Legacy Query-based Deep Links (?p=123)
      if (uri.path == '/' || uri.path == '/index.php') {
        final productId = uri.queryParameters['p'];
        if (productId != null && productId.isNotEmpty) {
          return '/product/$productId';
        }
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: homeBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'product',
                    builder: (context, state) {
                      final product = state.extra;
                      if (product is ProductModel) {
                        return ProductDetailsScreen(product: product);
                      }
                      return const _MissingProductScreen();
                    },
                  ),
                  GoRoute(
                    path: 'product-by-id/:id',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) {
                        return const _MissingProductScreen();
                      }
                      return _ProductByIdScreen(productId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: catalogBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.categories,
                builder: (context, state) => const CategoriesScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.categoriesCatalog,
                builder: _catalogBuilder,
              ),
              GoRoute(path: AppRoutePaths.catalog, builder: _catalogBuilder),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: brandsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.brands,
                builder: (context, state) => const BrandsScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.brandsCatalog,
                builder: _catalogBuilder,
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: favoritesBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.saved,
                builder: (context, state) => const SavedProductsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: cartBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutePaths.account,
                builder: (context, state) => const AccountScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.orders,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: 'details',
                    builder: (context, state) {
                      final extra = state.extra;
                      if (extra is! OrderModel) {
                        return const _MissingOrderDetailsScreen();
                      }
                      return OrderDetailsScreen(order: extra);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutePaths.notifications,
                redirect: (context, _) {
                  final auth = context.read<AuthCubit>().state;
                  if (_hasAuthenticatedSession(auth)) return null;
                  return AppRoutePaths.loginRedirect(
                    AppRoutePaths.notifications,
                  );
                },
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.jobs,
                builder: (context, state) => const JobsScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.contact,
                builder: (context, state) => const ContactScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.security,
                redirect: (context, _) {
                  final auth = context.read<AuthCubit>().state;
                  if (auth is Authenticated) return null;
                  return AppRoutePaths.loginRedirect(AppRoutePaths.security);
                },
                builder: (context, state) => const SecuritySettingsScreen(),
              ),
              GoRoute(
                path: AppRoutePaths.editProfile,
                builder: (context, state) => const EditProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutePaths.admin,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final authCubit = context.read<AuthCubit>();
          final auth = authCubit.state;
          if (!_hasAuthenticatedSession(auth)) {
            return AppRoutePaths.loginRedirect(AppRoutePaths.admin);
          }
          if (!_isAdminUser(authCubit)) {
            return AppRoutePaths.account;
          }
          return null;
        },
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'module/:moduleId',
            builder: (context, state) => AdminModuleScreen(
              moduleId: state.pathParameters['moduleId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'order/:id',
            builder: (context, state) {
              final orderId = int.tryParse(state.pathParameters['id'] ?? '');
              if (orderId == null || orderId <= 0) {
                return const _MissingAdminOrderScreen();
              }
              return AdminOrderDetailsScreen(orderId: orderId);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutePaths.scanner,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final qp = _safeQueryParameters(state.uri);
          return ScannerScreen(returnScannedCode: qp['mode'] == 'search');
        },
      ),
      GoRoute(
        path: AppRoutePaths.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            LoginScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: AppRoutePaths.register,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.checkout,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, _) {
          final auth = context.read<AuthCubit>().state;
          if (_hasAuthenticatedSession(auth)) return null;
          return AppRoutePaths.loginRedirect(AppRoutePaths.checkout);
        },
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.termsOfUse,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TermsOfUseScreen(),
      ),
      // --- Standardized Deep Link Entry Points ---
      GoRoute(
        path: '/product/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final param = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          if (extra is ProductModel) {
            final routeId = int.tryParse(param);
            if (routeId == null || routeId == extra.id) {
              return ProductDetailsScreen(product: extra);
            }
          }
          final id = int.tryParse(param);
          if (id != null) {
            return _ProductByIdScreen(productId: id);
          }
          // If not a number, treat as a slug
          return _ProductBySlugScreen(slug: param);
        },
      ),
      GoRoute(
        path: '/category/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return CatalogProductsScreen(
            title: '', // Screen will handle default title
            categoryId: id,
          );
        },
      ),
      GoRoute(
        path: '/brand/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final slug = state.pathParameters['slug'];
          return CatalogProductsScreen(
            title:
                state.uri.queryParameters['title'] ??
                '', // Screen will handle default title
            brandSlug: slug,
            initialCuratedCategoryId: int.tryParse(
              state.uri.queryParameters['curatedCategoryId'] ?? '',
            ),
            initialCuratedCategorySlug:
                state.uri.queryParameters['curatedCategorySlug'],
            initialCuratedCategoryLabel:
                state.uri.queryParameters['curatedCategoryLabel'],
          );
        },
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          return CatalogProductsScreen(
            title: 'البحث',
            initialSearch: query,
            autoFocusSearch: query.isEmpty,
          );
        },
      ),
      GoRoute(
        path: '/cart-direct',
        redirect: (context, state) => AppRoutePaths.cart,
      ),
      GoRoute(
        path: '/account-direct',
        redirect: (context, state) => AppRoutePaths.account,
      ),
    ],
  );
}

class _MissingAdminOrderScreen extends StatelessWidget {
  const _MissingAdminOrderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: const Center(child: Text('تعذر تحديد رقم الطلب')),
    );
  }
}

class _MissingOrderDetailsScreen extends StatelessWidget {
  const _MissingOrderDetailsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: const Center(child: Text('تعذر تحميل تفاصيل الطلب')),
    );
  }
}

class _MissingProductScreen extends StatelessWidget {
  const _MissingProductScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المنتج')),
      body: const Center(child: Text('تعذر تحميل المنتج')),
    );
  }
}

class _ProductByIdScreen extends StatefulWidget {
  final int productId;

  const _ProductByIdScreen({required this.productId});

  @override
  State<_ProductByIdScreen> createState() => _ProductByIdScreenState();
}

class _ProductByIdScreenState extends State<_ProductByIdScreen> {
  @override
  Widget build(BuildContext context) {
    return _ProductLookupScreen(
      cacheKey: 'product-id-${widget.productId}',
      loader: (repository, guest) =>
          repository.getProductById(widget.productId, guest: guest),
    );
  }
}

class _ProductBySlugScreen extends StatefulWidget {
  final String slug;

  const _ProductBySlugScreen({required this.slug});

  @override
  State<_ProductBySlugScreen> createState() => _ProductBySlugScreenState();
}

class _ProductBySlugScreenState extends State<_ProductBySlugScreen> {
  @override
  Widget build(BuildContext context) {
    return _ProductLookupScreen(
      cacheKey: 'product-slug-${widget.slug}',
      loader: (repository, guest) =>
          repository.getProductBySlug(widget.slug, guest: guest),
    );
  }
}

typedef _ProductLookupLoader =
    Future<ProductModel?> Function(ProductRepository repository, bool isGuest);

class _ProductLookupScreen extends StatefulWidget {
  final String cacheKey;
  final _ProductLookupLoader loader;

  const _ProductLookupScreen({required this.cacheKey, required this.loader});

  @override
  State<_ProductLookupScreen> createState() => _ProductLookupScreenState();
}

class _ProductLookupScreenState extends State<_ProductLookupScreen> {
  final ProductRepository _repository = ProductRepository();
  Future<ProductModel?>? _lookupFuture;

  @override
  void initState() {
    super.initState();
    _lookupFuture = _loadProduct();
  }

  @override
  void didUpdateWidget(covariant _ProductLookupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey == widget.cacheKey) {
      return;
    }
    _lookupFuture = _loadProduct();
  }

  Future<ProductModel?> _loadProduct() async {
    final storage = StorageService();
    final user = await storage.getUser();
    final isGuest = user == null || user.isGuest;
    return widget.loader(_repository, isGuest);
  }

  void _retry() {
    setState(() {
      _lookupFuture = _loadProduct();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductModel?>(
      future: _lookupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ProductLookupErrorScreen(onRetry: _retry);
        }

        final product = snapshot.data;
        if (product == null) {
          return const _MissingProductScreen();
        }

        return ProductDetailsScreen(product: product);
      },
    );
  }
}

class _ProductLookupErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProductLookupErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '\u062A\u0641\u0627\u0635\u064A\u0644 \u0627\u0644\u0645\u0646\u062A\u062C',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.wifi_off_rounded, size: 46, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                '\u062A\u0639\u0630\u0631 \u062A\u062D\u0645\u064A\u0644 \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0645\u0646\u062A\u062C. \u062D\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062E\u0631\u0649.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  '\u0625\u0639\u0627\u062F\u0629 \u0627\u0644\u0645\u062D\u0627\u0648\u0644\u0629',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
