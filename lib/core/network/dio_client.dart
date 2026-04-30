import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  late Dio dio;
  late CacheOptions cacheOptions;
  final StorageService _storageService = StorageService();

  // In-flight request tracking for deduplication
  final Map<String, Completer<Response<dynamic>>> _inFlightRequests = {};

  DioClient._internal();

  /// Call this when the app initializes
  Future<void> init() async {
    String? path;
    if (!kIsWeb) {
      // Use ApplicationSupportDirectory instead of TemporaryDirectory for persistent cache
      final dir = await getApplicationSupportDirectory();
      path = dir.path;
    }
    final cacheStore = HiveCacheStore(path, hiveBoxName: 'lpco_api_cache_v2');

    cacheOptions = CacheOptions(
      store: cacheStore,
      policy: CachePolicy.refreshForceCache,
      hitCacheOnErrorExcept: [401, 403],
      maxStale: const Duration(
        hours: 12,
      ), // Increased from 2h to 12h for better offline resilience
      priority: CachePriority.normal,
      cipher: null,
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
      allowPostMethod: false,
    );

    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.wpApiBase,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        },
      ),
    );

    // 0. Logging Interceptor (First to capture all changes)
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: false,
          responseHeader: true,
          responseBody: false,
          error: true,
        ),
      );
    }

    // 1. In-flight Deduplication Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.method != 'GET') return handler.next(options);

          final key = _inFlightKey(options);
          options.extra['inflight_key'] = key;
          final existing = _inFlightRequests[key];
          if (existing != null) {
            try {
              final response = await existing.future;
              final replayed = Response<dynamic>(
                requestOptions: options,
                data: response.data,
                headers: response.headers,
                isRedirect: response.isRedirect,
                redirects: response.redirects,
                statusCode: response.statusCode,
                statusMessage: response.statusMessage,
                extra: response.extra,
              );
              return handler.resolve(replayed);
            } catch (e) {
              // If the original request failed, let this one proceed as a new attempt
              _inFlightRequests.remove(key);
            }
          }

          options.extra['inflight_owner'] = true;
          _inFlightRequests[key] = Completer<Response<dynamic>>();
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (_isUnexpectedNonJsonApiResponse(response)) {
            final apiError = DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              message: ApiContract.extractErrorMessage(
                response.data,
                statusCode: response.statusCode,
              ),
            );
            _rejectInFlight(response.requestOptions, apiError);
            return handler.reject(apiError);
          }
          _resolveInFlightResponse(response.requestOptions, response);
          handler.next(response);
        },
        onError: (err, handler) {
          _rejectInFlight(err.requestOptions, err);
          handler.next(err);
        },
      ),
    );

    // 2. Cache Interceptor
    dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));

    // 3. Auth & Retry Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getToken();
          final deviceToken = await _storageService.getDeviceToken();

          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth && token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          final skipDeviceToken = options.extra['skipDeviceToken'] == true;
          final includeDeviceToken =
              options.extra['includeDeviceToken'] == true;
          if (!skipDeviceToken &&
              includeDeviceToken &&
              deviceToken != null &&
              deviceToken.isNotEmpty) {
            options.headers['X-Device-Token'] = deviceToken;
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          if (!_shouldRetry(error)) {
            return handler.next(error);
          }

          final attempt =
              (error.requestOptions.extra['retry_attempt'] as int? ?? 0) + 1;
          if (attempt > _retryDelays.length) {
            return handler.next(error);
          }

          final delay = _retryDelays[attempt - 1];
          await Future<void>.delayed(delay);

          error.requestOptions.extra['retry_attempt'] = attempt;

          try {
            final response = await dio.fetch<dynamic>(error.requestOptions);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  String _inFlightKey(RequestOptions options) {
    return '${options.method}:${options.uri}:${options.data}:${options.queryParameters}';
  }

  void _resolveInFlightResponse(
    RequestOptions request,
    Response<dynamic> response,
  ) {
    if (request.extra['inflight_owner'] != true) {
      return;
    }

    final key =
        request.extra['inflight_key']?.toString() ?? _inFlightKey(request);
    final completer = _inFlightRequests.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  void _rejectInFlight(RequestOptions request, DioException error) {
    if (request.extra['inflight_owner'] != true) {
      return;
    }

    final key =
        request.extra['inflight_key']?.toString() ?? _inFlightKey(request);
    final completer = _inFlightRequests.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  Options buildOptions({
    bool skipAuth = false,
    bool skipDeviceToken = false,
    bool includeDeviceToken = false,
    CachePolicy? cachePolicy,
    Duration? maxStale,
    Map<String, dynamic>? extra,
  }) {
    final resolved = cacheOptions.copyWith(
      policy: cachePolicy ?? cacheOptions.policy,
      maxStale: Nullable<Duration>(maxStale ?? cacheOptions.maxStale),
    );
    final options = resolved.toOptions();
    return options.copyWith(
      extra: <String, dynamic>{
        ...(options.extra ?? const <String, dynamic>{}),
        if (skipAuth) 'skipAuth': true,
        if (skipDeviceToken) 'skipDeviceToken': true,
        if (includeDeviceToken) 'includeDeviceToken': true,
        ...?extra,
      },
    );
  }

  bool _isUnexpectedNonJsonApiResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 204 || status == 304) {
      return false;
    }

    final request = response.requestOptions;
    if (!_isApiRequest(request)) {
      return false;
    }

    final data = response.data;
    if (data == null || data is Map || data is List) {
      return false;
    }

    if (data is String) {
      final text = data.trim();
      if (text.isEmpty) {
        return false;
      }
      if (text.startsWith('{') || text.startsWith('[')) {
        return false;
      }
      final contentType =
          (response.headers.value(Headers.contentTypeHeader) ?? '')
              .toLowerCase();
      final isJsonContentType =
          contentType.contains('application/json') ||
          contentType.contains('application/problem+json') ||
          contentType.contains('application/vnd.api+json');
      if (isJsonContentType) {
        return false;
      }
      return true;
    }

    return false;
  }

  bool _isApiRequest(RequestOptions request) {
    final path = request.path.toLowerCase();
    final uriPath = request.uri.path.toLowerCase();
    return path.contains('/wp-json/') ||
        path.startsWith('/dms/') ||
        path.contains('/jwt-auth/') ||
        uriPath.contains('/wp-json/') ||
        uriPath.contains('/dms/') ||
        uriPath.contains('/jwt-auth/');
  }

  bool _shouldRetry(DioException error) {
    if (error.type == DioExceptionType.cancel) return false;

    final statusCode = error.response?.statusCode ?? 0;
    // Don't retry client errors except specific ones like 408/429
    if (statusCode >= 400 && statusCode < 500) {
      return statusCode == 408 || statusCode == 429;
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.unknown =>
        error.error != null, // Network issues usually fall here
      _ => statusCode >= 500,
    };
  }
}
