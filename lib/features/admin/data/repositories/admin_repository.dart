import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
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

  Future<AdminDiscoveryResult> discoverModules() async {
    try {
      final response = await _dio.get(
        '/dms/v1/admin/capabilities',
        options: DioClient().buildOptions(skipDeviceToken: true),
      );
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
    } catch (_) {
      return AdminDiscoveryResult(
        modules: await _legacyDiscoverModules(),
        discoveredAt: DateTime.now(),
      );
    }
  }

  Future<AdminDashboardModel> fetchDashboard() async {
    final response = await _dio.get(
      '/dms/v1/admin/stats',
      options: DioClient().buildOptions(skipDeviceToken: true),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/stats');
    return AdminDashboardModel.fromJson(_detail(payload));
  }

  Future<AdminDiagnosticsModel> fetchDiagnostics() async {
    final response = await _dio.get(
      '/dms/v1/admin/diagnostics',
      options: DioClient().buildOptions(skipDeviceToken: true),
    );
    final payload = _map(response.data, endpoint: '/dms/v1/admin/diagnostics');
    return AdminDiagnosticsModel.fromJson(_detail(payload));
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
    int? targetUserId,
  }) async {
    await _dio.post(
      '/dms/v1/admin/notifications/send',
      data: <String, dynamic>{
        'title': title.trim(),
        'body': body.trim(),
        'audience': audience.trim(),
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
        'featured': ?featured,
        if (_hasText(status)) 'status': status!.trim(),
      },
    );

    return AdminPagedResponse<AdminProductModel>.fromJson(
      _map(response.data, endpoint: '/dms/v1/admin/products'),
      AdminProductModel.fromJson,
    );
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
      'home-banner': <String>['/dms/v1/admin/home-banner'],
      'home-layout': <String>['/dms/v1/admin/home-layout'],
      'app-theme': <String>['/dms/v1/admin/theme'],
      'popup-config': <String>['/dms/v1/admin/popup'],
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

  bool _bool(dynamic value) {
    if (value is bool) return value;
    return _string(value).toLowerCase() == 'true' || '$value' == '1';
  }

  String _string(dynamic value) => value == null ? '' : '$value'.trim();
  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}
