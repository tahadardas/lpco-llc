import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/models/admin_order_details_model.dart';
import 'package:lpco_llc/features/admin/domain/admin_module.dart';

class AdminDiscoveryResult {
  final List<AdminModule> modules;
  final DateTime discoveredAt;

  const AdminDiscoveryResult({
    required this.modules,
    required this.discoveredAt,
  });
}

class AdminRepository {
  AdminRepository({Dio? dio}) : _dio = dio ?? DioClient().dio;

  final Dio _dio;

  Future<AdminDiscoveryResult> discoverModules({
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/dms/v1/admin/capabilities',
        queryParameters: _freshQuery(forceRefresh),
        options: _adminOptions(),
      );
      _logAdminApiResponse('/dms/v1/admin/capabilities', response);
      final payload = _map(
        response.data,
        endpoint: '/dms/v1/admin/capabilities',
      );
      final data = _detail(payload);
      final rawModules = (data['modules'] as List?) ?? const <dynamic>[];
      final byId = <String, Map<String, dynamic>>{
        for (final raw in rawModules.whereType<Map>())
          '${raw['id']}': Map<String, dynamic>.from(raw),
      };

      final modules = kAdminModuleDefinitions.map((definition) {
        final capability = byId[definition.id];
        if (capability == null) {
          return definition.copyWith(
            support: AdminModuleSupport.unavailable,
            canRead: false,
            canWrite: false,
          );
        }
        return definition.copyWith(
          title: _string(capability['title']).isEmpty
              ? definition.title
              : _string(capability['title']),
          support: AdminModuleSupportX.fromApi(_string(capability['support'])),
          canRead: _bool(capability['can_read']),
          canWrite: _bool(capability['can_write']),
          gapMessage: _string(capability['gap_message']).isEmpty
              ? definition.gapMessage
              : _string(capability['gap_message']),
        );
      }).toList();

      return AdminDiscoveryResult(
        modules: modules,
        discoveredAt: DateTime.now(),
      );
    } catch (error) {
      _logAdminApiError('/dms/v1/admin/capabilities', error);
      if (_isAuthorizationError(error)) {
        rethrow;
      }
      return AdminDiscoveryResult(
        modules: await _legacyDiscoverModules(),
        discoveredAt: DateTime.now(),
      );
    }
  }

  Future<AdminDashboardModel> fetchDashboard({
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/dms/v1/admin/stats',
        queryParameters: _freshQuery(forceRefresh),
        options: _adminOptions(),
      );
      _logAdminApiResponse('/dms/v1/admin/stats', response);
      final payload = _map(response.data, endpoint: '/dms/v1/admin/stats');
      return AdminDashboardModel.fromJson(_detail(payload));
    } catch (error) {
      _logAdminApiError('/dms/v1/admin/stats', error);
      rethrow;
    }
  }

  Future<AdminDiagnosticsModel> fetchDiagnostics({
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/dms/v1/admin/diagnostics',
        queryParameters: _freshQuery(forceRefresh),
        options: _adminOptions(),
      );
      _logAdminApiResponse('/dms/v1/admin/diagnostics', response);
      final payload = _map(
        response.data,
        endpoint: '/dms/v1/admin/diagnostics',
      );
      return AdminDiagnosticsModel.fromJson(_detail(payload));
    } catch (error) {
      _logAdminApiError('/dms/v1/admin/diagnostics', error);
      rethrow;
    }
  }

  Future<AdminPagedResponse<AdminOrderSummaryModel>> fetchOrders({
    int page = 1,
    int perPage = 25,
    String? search,
    String? status,
    String? sort,
    String? dateFrom,
    String? dateTo,
    String? warehouseCode,
  }) async {
    final response = await _dio.get(
      '/dms/v1/admin/orders',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (_hasText(search)) 'search': search!.trim(),
        if (_hasText(status)) 'status': status!.trim(),
        if (_hasText(sort)) 'sort': sort!.trim(),
        if (_hasText(dateFrom)) 'date_from': dateFrom!.trim(),
        if (_hasText(dateTo)) 'date_to': dateTo!.trim(),
        if (_hasText(warehouseCode)) 'warehouse': warehouseCode!.trim(),
      },
    );

    return AdminPagedResponse<AdminOrderSummaryModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/orders'),
      AdminOrderSummaryModel.fromJson,
    );
  }

  Future<AdminOrderDetailsModel> fetchOrderDetails(int orderId) async {
    final response = await _dio.get('/dms/v1/admin/orders/$orderId');
    final payload = _map(
      response.data,
      endpoint: '/dms/v1/admin/orders/$orderId',
    );
    return AdminOrderDetailsModel.fromJson(_detail(payload));
  }

  Future<void> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    await _dio.post(
      '/dms/v1/admin/orders/$orderId/status',
      data: <String, dynamic>{'status': status},
    );
  }

  Future<AdminPagedResponse<AdminUserModel>> fetchUsers({
    int page = 1,
    int perPage = 25,
    String? search,
    String? role,
    String? group,
    String? status,
  }) async {
    final response = await _dio.get(
      '/dms/v1/admin/users',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (_hasText(search)) 'search': search!.trim(),
        if (_hasText(role)) 'role': role!.trim(),
        if (_hasText(group)) 'group': group!.trim(),
        if (_hasText(status)) 'status': status!.trim(),
      },
    );
    return AdminPagedResponse<AdminUserModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/users'),
      AdminUserModel.fromJson,
    );
  }

  Future<AdminUserModel> fetchUserDetails(int userId) async {
    final response = await _dio.get('/dms/v1/admin/users/$userId');
    final payload = _map(
      response.data,
      endpoint: '/dms/v1/admin/users/$userId',
    );
    return AdminUserModel.fromJson(_detail(payload));
  }

  Future<AdminPagedResponse<AdminMemberModel>> fetchMembers({
    int page = 1,
    int perPage = 25,
    String? search,
    String? group,
    String? status,
    String? governorate,
  }) async {
    final response = await _dio.get(
      '/dms/v1/admin/members',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (_hasText(search)) 'search': search!.trim(),
        if (_hasText(group)) 'group': group!.trim(),
        if (_hasText(status)) 'status': status!.trim(),
        if (_hasText(governorate)) 'governorate': governorate!.trim(),
      },
    );
    return AdminPagedResponse<AdminMemberModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/members'),
      AdminMemberModel.fromJson,
    );
  }

  Future<AdminMemberModel> fetchMemberDetails(int memberId) async {
    final response = await _dio.get('/dms/v1/admin/members/$memberId');
    final payload = _map(
      response.data,
      endpoint: '/dms/v1/admin/members/$memberId',
    );
    return AdminMemberModel.fromJson(_detail(payload));
  }

  Future<AdminMemberModel> createMember(Map<String, dynamic> payload) async {
    final response = await _dio.post('/dms/v1/admin/members', data: payload);
    final data = _actionData(
      _map(response.data, endpoint: '/dms/v1/admin/members'),
    );
    return AdminMemberModel.fromJson(
      Map<String, dynamic>.from(
        (data['member'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminMemberModel> updateMember(
    int memberId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/members/$memberId',
      data: payload,
    );
    final data = _actionData(
      _map(response.data, endpoint: '/dms/v1/admin/members/$memberId'),
    );
    return AdminMemberModel.fromJson(
      Map<String, dynamic>.from(
        (data['member'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<void> deleteMember(int memberId) async {
    await _dio.delete('/dms/v1/admin/members/$memberId');
  }

  Future<AdminSettingsModel> fetchSettings() async {
    final response = await _dio.get('/dms/v1/admin/settings');
    final payload = _map(response.data, endpoint: '/dms/v1/admin/settings');
    return AdminSettingsModel.fromJson(_detail(payload));
  }

  Future<AdminSettingsModel> updateSettings(AdminSettingsModel settings) async {
    final response = await _dio.post(
      '/dms/v1/admin/settings',
      data: settings.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/settings');
    final data = _actionData(payload);
    return AdminSettingsModel.fromJson(
      Map<String, dynamic>.from(
        (data['settings'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<Map<String, dynamic>> fetchNotificationEmails() async {
    final response = await _dio.get('/dms/v1/admin/notifications/emails');
    final payload = _map(
      response.data,
      endpoint: '/dms/v1/admin/notifications/emails',
    );
    return _detail(payload);
  }

  Future<void> updateNotificationEmails(String emails) async {
    await _dio.post(
      '/dms/v1/admin/notifications/emails',
      data: <String, dynamic>{'emails': emails},
    );
  }

  Future<AdminPagedResponse<AdminNotificationHistoryModel>>
  fetchNotificationsHistory({
    int page = 1,
    int perPage = 25,
    String? search,
    String? audience,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _dio.get(
      '/dms/v1/admin/notifications/history',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (_hasText(search)) 'search': search!.trim(),
        if (_hasText(audience)) 'audience': audience!.trim(),
        if (_hasText(dateFrom)) 'date_from': dateFrom!.trim(),
        if (_hasText(dateTo)) 'date_to': dateTo!.trim(),
      },
    );
    return AdminPagedResponse<AdminNotificationHistoryModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/notifications/history'),
      AdminNotificationHistoryModel.fromJson,
    );
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    required String audience,
    String imageUrl = '',
    String deepLink = '',
    String actionType = 'none',
    String actionValue = '',
    int? targetUserId,
  }) async {
    await _dio.post(
      '/dms/v1/admin/notifications/send',
      data: <String, dynamic>{
        'title': title.trim(),
        'body': body.trim(),
        'audience': audience.trim(),
        'action_type': actionType.trim().isEmpty ? 'none' : actionType.trim(),
        if (_hasText(actionValue)) 'action_value': actionValue.trim(),
        if (_hasText(imageUrl)) 'image_url': imageUrl.trim(),
        if (_hasText(deepLink)) 'deep_link': deepLink.trim(),
        if (targetUserId != null && targetUserId > 0)
          'target_user_id': targetUserId,
      },
    );
  }

  Future<AdminPagedResponse<AdminUserModel>> searchTargetUsers(
    String query,
  ) async {
    final response = await _dio.get(
      '/dms/v1/admin/users/search',
      queryParameters: <String, dynamic>{'q': query},
    );
    return AdminPagedResponse<AdminUserModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/users/search'),
      AdminUserModel.fromJson,
    );
  }

  Future<AdminHomeBannerModel> fetchHomeBanner() async {
    final response = await _dio.get('/dms/v1/admin/home-banner');
    final payload = _map(response.data, endpoint: '/dms/v1/admin/home-banner');
    return AdminHomeBannerModel.fromJson(_detail(payload));
  }

  Future<AdminHomeBannerModel> updateHomeBanner(
    AdminHomeBannerModel banner,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/home-banner',
      data: banner.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/home-banner');
    final data = _actionData(payload);
    return AdminHomeBannerModel.fromJson(
      Map<String, dynamic>.from(
        (data['banner'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminHomeBannersModel> fetchHomeBanners() async {
    try {
      final response = await _dio.get('/dms/v1/admin/home-banners');
      final payload = _map(
        response.data,
        endpoint: '/dms/v1/admin/home-banners',
      );
      return AdminHomeBannersModel.fromJson(_detail(payload));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback gracefully to single banner if the multi-banner endpoint doesn't exist yet
        final legacyBanner = await fetchHomeBanner();
        return AdminHomeBannersModel(
          items: [
            if (legacyBanner.enabled || legacyBanner.imageUrl.isNotEmpty)
              AdminHomeBannerItemModel(
                id: 'legacy',
                enabled: legacyBanner.enabled,
                imageId: legacyBanner.imageId,
                imageUrl: legacyBanner.imageUrl,
                title: legacyBanner.title,
                subtitle: legacyBanner.subtitle,
                buttonLabel: legacyBanner.buttonLabel,
                buttonLink: legacyBanner.buttonLink,
                actionType: AdminBannerActionType.none,
                actionValue: '',
                sortOrder: 1,
                productIds: legacyBanner.productIds,
                updatedAt: '',
                showTitle: true,
                showSubtitle: true,
                showButton: true,
              ),
          ],
          updatedAt: '',
          revision: '',
        );
      }
      rethrow;
    }
  }

  Future<AdminHomeBannersModel> updateHomeBanners(
    AdminHomeBannersModel banners,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/home-banners',
      data: banners.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/home-banners');
    final data = _actionData(payload);
    return AdminHomeBannersModel.fromJson(
      Map<String, dynamic>.from(
        (data['banners'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminHomeLayoutModel> fetchHomeLayout() async {
    final response = await _dio.get('/dms/v1/admin/home-layout');
    final payload = _map(response.data, endpoint: '/dms/v1/admin/home-layout');
    return AdminHomeLayoutModel.fromJson(_detail(payload));
  }

  Future<AdminHomeLayoutModel> updateHomeLayout(
    AdminHomeLayoutModel layout,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/home-layout',
      data: layout.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/home-layout');
    final data = _actionData(payload);
    return AdminHomeLayoutModel.fromJson(
      Map<String, dynamic>.from(
        (data['layout'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminThemeModel> fetchAppTheme() async {
    final response = await _dio.get('/dms/v1/admin/theme');
    final payload = _map(response.data, endpoint: '/dms/v1/admin/theme');
    return AdminThemeModel.fromJson(_detail(payload));
  }

  Future<AdminThemeModel> updateAppTheme(AdminThemeModel theme) async {
    final response = await _dio.post(
      '/dms/v1/admin/theme',
      data: theme.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/theme');
    final data = _actionData(payload);
    return AdminThemeModel.fromJson(
      Map<String, dynamic>.from(
        (data['theme'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminPopupConfigModel> fetchPopupConfig() async {
    final response = await _dio.get('/dms/v1/admin/popup');
    final payload = _map(response.data, endpoint: '/dms/v1/admin/popup');
    return AdminPopupConfigModel.fromJson(_detail(payload));
  }

  Future<AdminPopupConfigModel> updatePopupConfig(
    AdminPopupConfigModel config,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/popup',
      data: config.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/popup');
    final data = _actionData(payload);
    return AdminPopupConfigModel.fromJson(
      Map<String, dynamic>.from(
        (data['popup'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminOrderingConfigModel> fetchOrderingConfig() async {
    final response = await _dio.get('/dms/v1/admin/ordering');
    final payload = _map(response.data, endpoint: '/dms/v1/admin/ordering');
    return AdminOrderingConfigModel.fromJson(_detail(payload));
  }

  Future<AdminOrderingConfigModel> updateOrderingConfig(
    AdminOrderingConfigModel config,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/ordering',
      data: config.toJson(),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/ordering');
    final data = _actionData(payload);
    return AdminOrderingConfigModel.fromJson(<String, dynamic>{
      'config': data['ordering'],
    });
  }

  Future<AdminPagedResponse<AdminProductModel>> fetchProducts({
    int page = 1,
    int perPage = 25,
    String? search,
    String? category,
    String? brand,
    String? stockStatus,
    bool? featured,
    String? status,
  }) async {
    final response = await _dio.get(
      '/dms/v1/admin/products',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (_hasText(search)) 'search': search!.trim(),
        if (_hasText(category)) 'category': category!.trim(),
        if (_hasText(brand)) 'brand': brand!.trim(),
        if (_hasText(stockStatus)) 'stock_status': stockStatus!.trim(),
        if (featured != null) 'featured': featured ? 1 : 0,
        if (_hasText(status)) 'status': status!.trim(),
      },
    );

    return AdminPagedResponse<AdminProductModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/products'),
      AdminProductModel.fromJson,
    );
  }

  Future<AdminBrandCategoryLayoutModel> fetchBrandCategoryLayout() async {
    final response = await _dio.get('/dms/v1/admin/brand-category-layout');
    final payload = _decodePayload(response.data);
    return AdminBrandCategoryLayoutModel.fromPayload(_unwrapData(payload));
  }

  Future<AdminBrandCategoryLayoutModel> updateBrandCategoryLayout(
    AdminBrandCategoryLayoutModel layout,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/brand-category-layout',
      data: layout.toJson(),
    );
    final payload = _decodePayload(response.data);
    final data = _unwrapData(payload);
    final saved = AdminBrandCategoryLayoutModel.fromPayload(<String, dynamic>{
      'layout': data is Map ? data['layout'] : data,
      'available': <String, dynamic>{
        'brands': layout.availableBrands.map((brand) {
          return <String, dynamic>{
            'id': brand.id,
            'name': brand.name,
            'slug': brand.slug,
            'image_url': brand.imageUrl,
            'menu_order': brand.menuOrder,
            'hidden': brand.hidden,
            'show_in_app': brand.showInApp,
          };
        }).toList(),
        'categories': layout.availableCategories.map((category) {
          return <String, dynamic>{
            'id': category.id,
            'name': category.name,
            'slug': category.slug,
            'image_url': category.imageUrl,
            'menu_order': category.menuOrder,
            'hidden': category.hidden,
            'show_in_app': category.showInApp,
          };
        }).toList(),
      },
    });
    return saved.availableBrands.isEmpty && saved.availableCategories.isEmpty
        ? saved.copyWith(
            availableBrands: layout.availableBrands,
            availableCategories: layout.availableCategories,
          )
        : saved;
  }

  Future<AdminProductModel> fetchProductDetails(int productId) async {
    final response = await _dio.get('/dms/v1/admin/products/$productId');
    final payload = _map(
      response.data,
      endpoint: '/dms/v1/admin/products/$productId',
    );
    return AdminProductModel.fromJson(_detail(payload));
  }

  Future<AdminProductModel> updateProduct(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/products/$productId',
      data: payload,
    );
    final data = _actionData(
      _map(response.data, endpoint: '/dms/v1/admin/products/$productId'),
    );
    return AdminProductModel.fromJson(
      Map<String, dynamic>.from(
        (data['product'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<AdminPagedResponse<AdminReviewModel>> fetchReviews({
    int page = 1,
    int perPage = 25,
    String? search,
    String? status,
    int? rating,
  }) async {
    final response = await _dio.get(
      '/dms/v1/admin/reviews',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (_hasText(search)) 'search': search!.trim(),
        if (_hasText(status)) 'status': status!.trim(),
        if (rating != null && rating > 0) 'rating': rating,
      },
    );

    return AdminPagedResponse<AdminReviewModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/reviews'),
      AdminReviewModel.fromJson,
    );
  }

  Future<AdminReviewModel> updateReviewStatus(
    int reviewId,
    String status,
  ) async {
    final response = await _dio.post(
      '/dms/v1/admin/reviews/$reviewId/status',
      data: <String, dynamic>{'status': status},
    );
    final data = _actionData(
      _map(response.data, endpoint: '/dms/v1/admin/reviews/$reviewId/status'),
    );
    return AdminReviewModel.fromJson(
      Map<String, dynamic>.from(
        (data['review'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<List<AdminModule>> _legacyDiscoverModules() async {
    final routes = await _fetchRoutes();
    const supportableRoutes = <String, List<String>>{
      'orders': <String>['/dms/v1/admin/orders'],
      'users': <String>['/dms/v1/admin/users'],
      'members': <String>['/dms/v1/admin/members'],
      'settings': <String>['/dms/v1/admin/settings'],
      'diagnostics': <String>['/dms/v1/admin/diagnostics'],
      'notifications': <String>[
        '/dms/v1/admin/notifications/history',
        '/dms/v1/admin/notifications/send',
      ],
      'home-banner': <String>['/dms/v1/admin/home-banners'],
      'products': <String>['/dms/v1/admin/products'],
      'reviews': <String>['/dms/v1/admin/reviews'],
      'ordering': <String>['/dms/v1/admin/ordering'],
    };

    return kAdminModuleDefinitions.map((definition) {
      if (definition.kind == AdminModuleKind.stats) {
        return definition.copyWith(
          support: AdminModuleSupport.readOnly,
          canRead: true,
        );
      }
      final required = supportableRoutes[definition.id] ?? const <String>[];
      final available =
          required.isNotEmpty &&
          required.every((route) => routes.contains(route));
      return definition.copyWith(
        support: available
            ? AdminModuleSupport.fullControl
            : AdminModuleSupport.unavailable,
        canRead: available,
        canWrite: available,
      );
    }).toList();
  }

  Future<Set<String>> _fetchRoutes() async {
    final response = await _dio.get('/');
    final payload = _map(response.data, endpoint: '/');
    final rawRoutes = payload['routes'];
    if (rawRoutes is! Map) {
      return const <String>{};
    }
    return rawRoutes.keys.map((route) => '$route').toSet();
  }

  Map<String, dynamic> _detail(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return payload;
  }

  Map<String, dynamic> _actionData(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return payload;
  }

  dynamic _decodePayload(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      return jsonDecode(data);
    }
    return data;
  }

  dynamic _unwrapData(dynamic payload) {
    if (payload is Map && payload.containsKey('data')) {
      return payload['data'];
    }
    return payload;
  }

  Map<String, dynamic> _map(dynamic data, {required String endpoint}) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      return ApiContract.expectMap(decoded, endpoint: endpoint);
    }
    return ApiContract.expectMap(data, endpoint: endpoint);
  }

  Options _adminOptions() {
    return DioClient().buildOptions(
      skipDeviceToken: true,
      cachePolicy: CachePolicy.noCache,
    );
  }

  Map<String, dynamic> _freshQuery(bool forceRefresh) {
    if (!forceRefresh) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'force_refresh': 1,
      '_t': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _logAdminApiResponse(String endpoint, Response<dynamic> response) {
    if (!kDebugMode) {
      return;
    }
    final hasAuth = '${response.requestOptions.headers['Authorization'] ?? ''}'
        .trim()
        .isNotEmpty;
    debugPrint(
      '[ADMIN_API] $endpoint status=${response.statusCode} '
      'auth header exists=${hasAuth ? 'yes' : 'no'} '
      'body=${_bodyPreview(response.data)}',
    );
  }

  void _logAdminApiError(String endpoint, Object error) {
    if (!kDebugMode) {
      return;
    }
    if (error is DioException) {
      final hasAuth = '${error.requestOptions.headers['Authorization'] ?? ''}'
          .trim()
          .isNotEmpty;
      debugPrint(
        '[ADMIN_API] $endpoint status=${error.response?.statusCode} '
        'auth header exists=${hasAuth ? 'yes' : 'no'} '
        'body=${_bodyPreview(error.response?.data)} '
        'error=${error.message}',
      );
      return;
    }
    debugPrint('[ADMIN_API] $endpoint error=$error');
  }

  bool _isAuthorizationError(Object error) {
    if (error is! DioException) {
      return false;
    }
    final statusCode = error.response?.statusCode ?? 0;
    return statusCode == 401 || statusCode == 403;
  }

  String _bodyPreview(dynamic data) {
    final text = data is String ? data.trim() : '$data'.trim();
    if (text.length <= 600) {
      return text;
    }
    return '${text.substring(0, 600)}...';
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    return _string(value).toLowerCase() == 'true' || '$value' == '1';
  }

  String _string(dynamic value) => TextSanitizer.fix(value);
  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}
