import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/services/push_notification_service.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/notifications/data/models/app_notification_model.dart';

class NotificationsRepository {
  static const String _fallbackTokenPrefix = 'lpco-notifications-fallback-';

  final Dio _dio;
  final PushNotificationService _pushNotificationService;
  final StorageService _storageService;

  NotificationsRepository({
    Dio? dio,
    PushNotificationService? pushNotificationService,
    StorageService? storageService,
  }) : _dio = dio ?? DioClient().dio,
       _pushNotificationService =
           pushNotificationService ?? PushNotificationService(),
       _storageService = storageService ?? StorageService();

  Future<List<AppNotificationModel>> getNotifications({int limit = 30}) async {
    try {
      final response = await _withDeviceTokenRetry(
        (deviceToken) => _dio.get(
          '/dms/v1/notifications',
          queryParameters: <String, dynamic>{
            'limit': limit,
            'device_token': deviceToken,
          },
          options: _deviceOptions(deviceToken),
        ),
      );

      final list = ApiContract.expectList(
        response.data,
        endpoint: '/dms/v1/notifications',
        envelopeKeys: const <String>['data', 'items', 'notifications'],
      );

      return list
          .whereType<Map>()
          .map(
            (e) => AppNotificationModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _withDeviceTokenRetry(
        (deviceToken) => _dio.get(
          '/dms/v1/notifications/unread-count',
          queryParameters: <String, dynamic>{'device_token': deviceToken},
          options: _deviceOptions(deviceToken),
        ),
      );
      final data = ApiContract.expectMap(
        response.data,
        endpoint: '/dms/v1/notifications/unread-count',
      );
      return int.tryParse('${data['count'] ?? '0'}') ?? 0;
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<void> markRead(int notificationId) async {
    try {
      await _withDeviceTokenRetry(
        (deviceToken) => _dio.post(
          '/dms/v1/notifications/read',
          data: <String, dynamic>{
            'notification_id': notificationId,
            'device_token': deviceToken,
          },
          options: _deviceOptions(deviceToken),
        ),
      );
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<void> markUnread(int notificationId) async {
    try {
      await _withDeviceTokenRetry(
        (deviceToken) => _dio.post(
          '/dms/v1/notifications/unread',
          data: <String, dynamic>{
            'notification_id': notificationId,
            'device_token': deviceToken,
          },
          options: _deviceOptions(deviceToken),
        ),
      );
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<void> markAllRead() async {
    try {
      await _withDeviceTokenRetry(
        (deviceToken) => _dio.post(
          '/dms/v1/notifications/read-all',
          data: <String, dynamic>{'device_token': deviceToken},
          options: _deviceOptions(deviceToken),
        ),
      );
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _withDeviceTokenRetry(
        (deviceToken) => _dio.post(
          '/dms/v1/notifications/delete',
          data: <String, dynamic>{
            'notification_id': notificationId,
            'device_token': deviceToken,
          },
          options: _deviceOptions(deviceToken),
        ),
      );
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<void> deleteAll() async {
    try {
      await _withDeviceTokenRetry(
        (deviceToken) => _dio.post(
          '/dms/v1/notifications/delete-all',
          data: <String, dynamic>{'device_token': deviceToken},
          options: _deviceOptions(deviceToken),
        ),
      );
    } on DioException catch (e) {
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<Response<dynamic>> _withDeviceTokenRetry(
    Future<Response<dynamic>> Function(String deviceToken) request,
  ) async {
    final token = await _ensureDeviceToken();

    try {
      return await request(token);
    } on DioException catch (error) {
      if (!_isDeviceTokenError(error)) {
        rethrow;
      }

      final refreshedToken = await _ensureDeviceToken(force: true);
      await _registerTokenIfNeeded(refreshedToken, force: true);
      return request(refreshedToken);
    }
  }

  Future<String> _ensureDeviceToken({bool force = false}) async {
    String token = (await _storageService.getDeviceToken() ?? '').trim();
    if (token.isEmpty || force) {
      await _pushNotificationService.syncDeviceRegistration();
      token = (await _storageService.getDeviceToken() ?? '').trim();
    }

    if (token.isEmpty) {
      token = _buildFallbackToken();
      await _storageService.saveDeviceToken(token);
    }

    await _registerTokenIfNeeded(token, force: force);
    return token;
  }

  Future<void> _registerTokenIfNeeded(
    String token, {
    bool force = false,
  }) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    final authToken = (await _storageService.getToken() ?? '').trim();
    final userIdRaw = (await _storageService.getUserId() ?? '').trim();
    final userId = int.tryParse(userIdRaw);
    final hasAuthenticatedSession = authToken.isNotEmpty && userId != null;

    final payload = <String, dynamic>{
      'token': normalized,
      'platform': _platformName(),
      'app_version': 'flutter',
      'is_guest': !hasAuthenticatedSession,
      if (hasAuthenticatedSession) 'user_id': userId,
      if (force) 'force': 1,
    };

    try {
      await _dio.post(
        '/dms/v1/device/register',
        data: payload,
        options: Options(
          headers: <String, dynamic>{'X-Device-Token': normalized},
          extra: <String, dynamic>{
            'skipAuth': !hasAuthenticatedSession,
            'includeDeviceToken': true,
          },
        ),
      );
    } catch (_) {
      // Keep silent; notifications request itself will surface actionable errors.
    }
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _buildFallbackToken() {
    final millis = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rnd = Random().nextInt(1 << 32).toRadixString(36);
    return '$_fallbackTokenPrefix${_platformName()}-$millis-$rnd';
  }

  Options _deviceOptions(String token) {
    return Options(
      headers: <String, dynamic>{'X-Device-Token': token},
      extra: const <String, dynamic>{'includeDeviceToken': true},
    );
  }

  bool _isDeviceTokenError(DioException error) {
    final payload = error.response?.data;
    if (payload is Map) {
      final code = '${payload['code'] ?? ''}'.toLowerCase();
      final message = '${payload['message'] ?? payload['error'] ?? ''}'
          .toLowerCase();
      if (code == 'token_missing' ||
          code == 'token_not_found' ||
          code == 'invalid_token') {
        return true;
      }
      return message.contains('device token is required') ||
          message.contains('unknown device token');
    }
    return false;
  }
}
