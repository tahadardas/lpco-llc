import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:lpco_llc/app/router/app_router.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (DefaultFirebaseOptions.isConfigured && Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Ignore background init failures.
    }
  }
  debugPrint('Handling a background message: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() => _instance;

  PushNotificationService._internal();

  static const String _fallbackTokenStorageKey = 'fallback_device_token';
  static const String _fallbackTokenPrefix = 'lpco-fallback-';
  static const String _notificationChannelId = 'LPCO_Notifications';
  static const String _notificationChannelName = 'LPCO Notifications';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: 'Order and account notifications',
        importance: Importance.high,
        playSound: true,
      );

  FirebaseMessaging? _fcm;
  final Dio _dio = DioClient().dio;
  final StorageService _storageService = StorageService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _loggedDisabledOnce = false;
  bool _listenersAttached = false;
  bool _localNotificationsReady = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_canInitializePush()) {
      _debugConfigSkipOnce();
      await _ensureFallbackDeviceRegistration();
      return;
    }

    if (!await _ensureFirebaseReady()) {
      await _ensureFallbackDeviceRegistration();
      return;
    }

    await _initializeLocalNotifications();

    final messaging = _fcm ?? FirebaseMessaging.instance;
    _fcm = messaging;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Push notifications permission granted');
      } else {
        debugPrint('Push notifications permission denied or not granted');
      }
    } catch (e) {
      debugPrint('Push notifications request permission failed: $e');
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    if (!_listenersAttached) {
      _listenersAttached = true;

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Foreground push received: ${message.messageId}');
        await _showForegroundNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleDeepLink(message.data);
      });

      messaging.onTokenRefresh.listen((token) async {
        final normalized = token.trim();
        if (normalized.isEmpty) {
          return;
        }
        await _storageService.saveDeviceToken(normalized);
        await _storageService.deleteSecure(_fallbackTokenStorageKey);
        await _registerDeviceToken(normalized);
      });
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        _handleDeepLink(initialMessage.data);
      });
    }

    await _consumeInitialLocalNotificationLaunch();
    await syncDeviceRegistration();
  }

  Future<void> syncDeviceRegistration() async {
    if (!_canInitializePush()) {
      _debugConfigSkipOnce();
      await _ensureFallbackDeviceRegistration();
      return;
    }

    if (!await _ensureFirebaseReady()) {
      _debugConfigSkipOnce();
      await _ensureFallbackDeviceRegistration();
      return;
    }

    final messaging = _fcm ?? FirebaseMessaging.instance;
    _fcm = messaging;

    final storedToken = (await _storageService.getDeviceToken() ?? '').trim();
    var resolvedToken = storedToken;

    try {
      final firebaseToken = (await messaging.getToken() ?? '').trim();
      if (firebaseToken.isNotEmpty) {
        resolvedToken = firebaseToken;
        await _storageService.deleteSecure(_fallbackTokenStorageKey);
      }
    } catch (e) {
      debugPrint('Failed to retrieve push token: $e');
    }

    if (resolvedToken.isEmpty) {
      resolvedToken = await _resolveFallbackToken();
    }

    if (resolvedToken.isNotEmpty && resolvedToken != storedToken) {
      await _storageService.saveDeviceToken(resolvedToken);
    }

    await _registerDeviceToken(resolvedToken);
  }

  Future<void> _registerDeviceToken(
    String token, {
    bool forceGuest = false,
  }) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    final user = await _storageService.getUser();
    final authToken = (await _storageService.getToken() ?? '').trim();
    final storedUserId = (await _storageService.getUserId() ?? '').trim();
    final parsedUserId = int.tryParse(storedUserId);

    final isAuthenticated =
        !forceGuest &&
        authToken.isNotEmpty &&
        parsedUserId != null &&
        parsedUserId > 0 &&
        user?.isGuest != true;

    final payload = <String, dynamic>{
      'token': normalized,
      'platform': _platformName(),
      'app_version': 'flutter',
      'is_guest': !isAuthenticated,
      if (isAuthenticated) 'user_id': parsedUserId,
    };

    try {
      await _dio.post(
        '/dms/v1/device/register',
        data: payload,
        options: Options(
          headers: <String, dynamic>{'X-Device-Token': normalized},
          extra: <String, dynamic>{
            'skipAuth': !isAuthenticated,
            'includeDeviceToken': true,
          },
        ),
      );
    } on DioException catch (e) {
      debugPrint(
        'Device register failed: ${ApiContract.extractErrorMessage(e.response?.data, statusCode: e.response?.statusCode)}',
      );

      if (isAuthenticated && _isAuthOrBindingFailure(e)) {
        await _registerDeviceToken(normalized, forceGuest: true);
      }
    } catch (e) {
      debugPrint('Device register failed: $e');
    }
  }

  bool _isAuthOrBindingFailure(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status == 401) {
      return true;
    }

    final payload = error.response?.data;
    if (payload is Map) {
      final code = TextSanitizer.fix(payload['code']).toLowerCase();
      if (code == 'forbidden_user_binding' ||
          code.contains('jwt') ||
          code.contains('token') ||
          code == 'rest_forbidden') {
        return true;
      }
    }

    if (status != 403) {
      return false;
    }

    final message = ApiContract.extractErrorMessage(
      payload,
      statusCode: status,
    ).toLowerCase();
    return message.contains('session') ||
        message.contains('authorization') ||
        message.contains('authenticated user does not match');
  }

  Future<void> _ensureFallbackDeviceRegistration() async {
    String token = (await _storageService.getDeviceToken() ?? '').trim();
    if (token.isEmpty) {
      token = await _resolveFallbackToken();
      if (token.isEmpty) {
        return;
      }
      await _storageService.saveDeviceToken(token);
    }
    await _registerDeviceToken(token);
  }

  Future<String> _resolveFallbackToken() async {
    final existing =
        (await _storageService.readSecure(_fallbackTokenStorageKey) ?? '')
            .trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final rawUserId = (await _storageService.getUserId() ?? '').trim();
    final userId = rawUserId.isEmpty ? 'guest' : rawUserId;
    final entropy = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final token = '$_fallbackTokenPrefix${_platformName()}-$userId-$entropy';
    await _storageService.writeSecure(_fallbackTokenStorageKey, token);
    return token;
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
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<bool> _ensureFirebaseReady() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      return false;
    }
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (error) {
      debugPrint('Firebase initialization unavailable for push: $error');
      return false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb || _localNotificationsReady) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationPayload(response.payload);
      },
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(_androidChannel);
      await android.requestNotificationsPermission();
    }

    final ios = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      await ios.requestPermissions(alert: true, badge: true, sound: true);
    }

    final macos = _localNotifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macos != null) {
      await macos.requestPermissions(alert: true, badge: true, sound: true);
    }

    _localNotificationsReady = true;
  }

  Future<void> _consumeInitialLocalNotificationLaunch() async {
    if (kIsWeb || !_localNotificationsReady) {
      return;
    }

    final details = await _localNotifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return;
    }

    _handleLocalNotificationPayload(details?.notificationResponse?.payload);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb || !_localNotificationsReady) {
      return;
    }

    final title = TextSanitizer.fix(
      message.notification?.title ?? message.data['title'],
    );
    final body = TextSanitizer.fix(
      message.notification?.body ??
          message.data['body'] ??
          message.data['message'],
    );

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final target = _resolveTarget(message.data);
    final payload = <String, dynamic>{
      if (target.isNotEmpty) 'target': target,
      if (TextSanitizer.fix(message.data['deep_link']).isNotEmpty)
        'deep_link': TextSanitizer.fix(message.data['deep_link']),
      if (TextSanitizer.fix(message.data['notification_id']).isNotEmpty)
        'notification_id': TextSanitizer.fix(message.data['notification_id']),
    };

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: _notificationIdFor(message),
      title: title.isEmpty ? 'LPCO' : title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: payload.isEmpty ? null : jsonEncode(payload),
    );
  }

  int _notificationIdFor(RemoteMessage message) {
    final raw = '${message.messageId ?? DateTime.now().microsecondsSinceEpoch}';
    return raw.hashCode & 0x7fffffff;
  }

  void _handleLocalNotificationPayload(String? payload) {
    final raw = (payload ?? '').trim();
    if (raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _handleDeepLink(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {
      // Payload may be a direct target string.
    }

    handleNavigationTarget(raw);
  }

  bool _canInitializePush() {
    if (!DefaultFirebaseOptions.isConfigured) {
      return false;
    }

    if (!kIsWeb) {
      return true;
    }

    final host = Uri.base.host.toLowerCase();
    final scheme = Uri.base.scheme.toLowerCase();
    final isLocalhost =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final isSecureContext = scheme == 'https' || isLocalhost;
    return isSecureContext;
  }

  void _debugConfigSkipOnce() {
    if (!kDebugMode || _loggedDisabledOnce) {
      return;
    }
    _loggedDisabledOnce = true;
    debugPrint(
      'Push notifications are disabled because Firebase config is missing or unsupported in this environment.',
    );
  }

  void _handleDeepLink(Map<String, dynamic> data) {
    final target = _resolveTarget(data);
    if (target.isEmpty) {
      return;
    }
    handleNavigationTarget(target);
  }

  String _resolveTarget(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return '';
    }

    final candidates = <dynamic>[
      data['target'],
      data['deep_link'],
      data['deeplink'],
      data['link'],
      data['url'],
      data['route'],
    ];

    for (final candidate in candidates) {
      final normalized = _normalizeTarget(TextSanitizer.fix(candidate));
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    final notificationId = TextSanitizer.fix(data['notification_id']);
    if (notificationId.isNotEmpty) {
      return 'notifications';
    }

    return '';
  }

  String _normalizeTarget(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }

    final lowered = value.toLowerCase();
    if (lowered == 'notifications' ||
        lowered == 'orders' ||
        lowered == 'cart' ||
        lowered == 'account') {
      return lowered;
    }

    if (lowered.startsWith('product:') ||
        lowered.startsWith('category:') ||
        lowered.startsWith('brand:')) {
      return value;
    }

    if (lowered.startsWith('http://') ||
        lowered.startsWith('https://') ||
        lowered.startsWith('lpco://')) {
      try {
        final uri = Uri.parse(value);
        final fromPath = _normalizeTargetFromPath(
          uri.path,
          uri.queryParameters,
        );
        if (fromPath.isNotEmpty) {
          return fromPath;
        }
      } catch (_) {
        return '';
      }
      return '';
    }

    if (value.startsWith('/')) {
      return _normalizeTargetFromPath(value, const <String, String>{});
    }

    if (lowered.startsWith('product/') ||
        lowered.startsWith('category/') ||
        lowered.startsWith('brand/') ||
        lowered.startsWith('product-brand/')) {
      return _normalizeTargetFromPath('/$value', const <String, String>{});
    }

    return value;
  }

  String _normalizeTargetFromPath(String path, Map<String, String> query) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    Uri uri;
    try {
      uri = Uri.parse(trimmed.startsWith('/') ? trimmed : '/$trimmed');
    } catch (_) {
      return '';
    }

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return '';
    }

    final first = segments.first.toLowerCase();
    if (first == 'notifications') {
      return 'notifications';
    }
    if (first == 'orders' ||
        (first == 'my-account' &&
            segments.length > 1 &&
            segments[1] == 'orders')) {
      return 'orders';
    }
    if (first == 'cart') {
      return 'cart';
    }
    if (first == 'account' || first == 'my-account') {
      return 'account';
    }

    if (first == 'product' && segments.length >= 2) {
      final id = int.tryParse(segments[1]);
      if (id != null) {
        return 'product:$id';
      }
      final queryId = int.tryParse(query['id'] ?? query['product_id'] ?? '');
      if (queryId != null) {
        return 'product:$queryId';
      }
    }

    if ((first == 'category' || first == 'product-category') &&
        segments.length >= 2) {
      final id = int.tryParse(segments[1]);
      if (id != null) {
        return 'category:$id';
      }
    }

    if ((first == 'brand' || first == 'product-brand') &&
        segments.length >= 2) {
      return 'brand:${segments[1]}';
    }

    return '';
  }

  void handleNavigationTarget(String target, {BuildContext? context}) {
    final normalized = _normalizeTarget(target);
    if (normalized.isEmpty) {
      return;
    }

    final resolvedContext =
        context ?? AppRouter.rootNavigatorKey.currentContext;
    if (resolvedContext == null) {
      return;
    }

    if (normalized.startsWith('product:')) {
      final id = int.tryParse(normalized.split(':').last);
      if (id != null) {
        resolvedContext.go(AppRoutePaths.productUrl(id));
      }
      return;
    }

    if (normalized.startsWith('category:')) {
      final id = int.tryParse(normalized.split(':').last);
      if (id != null) {
        resolvedContext.go(AppRoutePaths.categoryUrl(id));
      }
      return;
    }

    if (normalized.startsWith('brand:')) {
      final slug = normalized.split(':').last.trim();
      if (slug.isNotEmpty) {
        resolvedContext.go(AppRoutePaths.brandUrl(slug));
      }
      return;
    }

    switch (normalized) {
      case 'notifications':
        resolvedContext.go(AppRoutePaths.notifications);
        return;
      case 'orders':
        resolvedContext.go(AppRoutePaths.orders);
        return;
      case 'cart':
        resolvedContext.go(AppRoutePaths.cart);
        return;
      case 'account':
        resolvedContext.go(AppRoutePaths.account);
        return;
      default:
        if (normalized.startsWith('/')) {
          resolvedContext.go(normalized);
        }
        return;
    }
  }
}
