import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';
import 'package:lpco_llc/core/session/session_manager.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

class AuthRepository {
  final DioClient _client = DioClient();
  final Dio _dio = DioClient().dio;
  final StorageService _storageService = StorageService();
  final SessionManager _sessionManager = SessionManager();
  final ReachabilityService _reachabilityService = ReachabilityService();
  final ProductRepository _productRepository = ProductRepository();

  Future<UserModel> login(String username, String password) async {
    try {
      final normalizedUsername = username.trim();
      final response = await _dio.post(
        '${AppConfig.jwtApiBase}/token',
        options: _client
            .buildOptions(
              skipAuth: true,
              skipDeviceToken: true,
              cachePolicy: CachePolicy.noCache,
            )
            .copyWith(contentType: Headers.formUrlEncodedContentType),
        data: {'username': normalizedUsername, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final payload = ApiContract.expectMap(
          response.data,
          endpoint: '${AppConfig.jwtApiBase}/token',
        );
        final token = (payload['token'] ?? '').toString();
        if (token.isEmpty) {
          throw Exception('No JWT token returned from server');
        }

        final userId = _extractUserId(token, payload);
        if (userId == null) {
          throw Exception('Unable to resolve authenticated user id');
        }

        await _storageService.saveToken(token);
        late final UserModel profile;
        try {
          profile = await getUserData(userId, authToken: token);
        } catch (_) {
          await _storageService.deleteToken();
          rethrow;
        }

        await _sessionManager.persistAuthenticatedSession(
          token: token,
          user: profile,
        );
        _productRepository.invalidateCache();
        return profile;
      }

      throw Exception('Login failed');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final path = e.requestOptions.path;
      if (status == 403 && path.contains('/token')) {
        final serverMessage = ApiContract.extractErrorMessage(e.response?.data);
        throw Exception(
          serverMessage.trim().isEmpty
              ? 'فشل تسجيل الدخول. تحقق من اسم المستخدم أو البريد الإلكتروني وكلمة المرور.'
              : serverMessage,
        );
      }
      if (status == 403 && path.contains('/dms/v1/user/')) {
        final serverMessage = ApiContract.extractErrorMessage(e.response?.data);
        throw Exception(
          TextSanitizer.fix(
            'تم تسجيل الدخول لكن تعذر تحميل بيانات الحساب: $serverMessage',
          ),
        );
      }
      throw Exception(ApiContract.extractErrorMessage(e.response?.data));
    }
  }

  Future<UserModel> getUserData(int userId, {String? authToken}) async {
    final normalizedToken = authToken?.trim() ?? '';
    final response = await _dio.get(
      '/dms/v1/user/$userId',
      options: normalizedToken.isEmpty
          ? null
          : Options(
              headers: <String, dynamic>{
                'Authorization': 'Bearer $normalizedToken',
              },
              extra: const <String, dynamic>{'skipAuth': true},
            ),
    );
    final json = ApiContract.expectMap(
      response.data,
      endpoint: '/dms/v1/user/$userId',
    );
    final rawMeta = json['meta'] ?? json['user_meta'];
    final meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};

    String pickFirstNonEmpty(List<dynamic> values) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
      return '';
    }

    final currency = AppCurrencies.normalizeCode(
      meta['dms_user_currency'] ?? meta['dms_currency'] ?? json['currency'],
    );
    final group = (meta['dms_user_group'] ?? 'default')
        .toString()
        .toLowerCase();
    final symbol = AppCurrencies.resolve(currency).symbol;
    final phone = pickFirstNonEmpty(<dynamic>[
      json['phone'],
      meta['account_whatsapp'],
      meta['billing_phone'],
      meta['phone'],
    ]);
    final address = pickFirstNonEmpty(<dynamic>[
      json['address'],
      meta['billing_address_1'],
      meta['address'],
    ]);
    final city = pickFirstNonEmpty(<dynamic>[
      json['city'],
      meta['billing_city'],
      meta['city'],
      json['governorate'],
      meta['account_governorate'],
      meta['billing_state'],
      meta['province'],
    ]);

    return UserModel(
      id: (json['id'] ?? userId) is int
          ? (json['id'] ?? userId) as int
          : int.tryParse('${json['id'] ?? userId}'),
      username: (json['username'] ?? json['user_login'] ?? '').toString(),
      email: (json['email'] ?? json['user_email'] ?? '').toString(),
      firstName: (json['first_name'] ?? meta['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? meta['last_name'] ?? '').toString(),
      displayName:
          (json['display_name'] ??
                  json['user_nicename'] ??
                  json['username'] ??
                  '')
              .toString(),
      userNicename: (json['user_nicename'] ?? '').toString(),
      group: group,
      currency: currency,
      currencySymbol: symbol,
      status: (meta['dms_account_status'] ?? 'active').toString(),
      companyName: (meta['account_company_name'] ?? meta['company_name'] ?? '')
          .toString(),
      phone: phone,
      address: address,
      city: city,
      roles: (json['roles'] is List)
          ? (json['roles'] as List).map((e) => e.toString()).toList()
          : const <String>['customer'],
      isGuest: false,
    );
  }

  Future<void> updateProfile({
    required int userId,
    required String company,
    required String province,
    required String phone,
    required String address,
  }) async {
    await _dio.post(
      '/dms/v1/user/$userId',
      options: _client.buildOptions(cachePolicy: CachePolicy.noCache),
      data: <String, dynamic>{
        'company': company.trim(),
        'company_name': company.trim(),
        'province': province.trim(),
        'governorate': province.trim(),
        'billing_state': province.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'billing_address_1': address.trim(),
      },
    );
  }

  Future<void> register({
    required String username,
    required String password,
    required String firstName,
    required String company,
    required String province,
    required String phone,
    required String address,
    String? email,
  }) async {
    final normalizedUsername = _normalizeUsernameForRegistration(username);
    final displayName = _resolveDisplayName(
      username: username,
      firstName: firstName,
      company: company,
    );
    final generatedEmail = _normalizeEmail(
      email: email,
      username: normalizedUsername,
      phone: phone,
    );

    try {
      await _dio.post(
        '/dms/v1/register',
        options: _client.buildOptions(
          skipAuth: true,
          skipDeviceToken: true,
          cachePolicy: CachePolicy.noCache,
        ),
        data: <String, dynamic>{
          'username': normalizedUsername,
          'display_name': displayName,
          'password': password,
          'email': generatedEmail,
          'first_name': firstName.trim(),
          'company': company.trim(),
          'province': province.trim(),
          'governorate': province.trim(),
          'billing_state': province.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(
        _extractRegisterErrorMessage(e, attemptedUsername: normalizedUsername),
      );
    }
  }

  Future<UserModel?> restoreSession() async {
    final restored = await _sessionManager.restore(
      online: false,
      refreshRemoteUser: null,
    );
    if (restored == null) {
      return null;
    }

    final user = restored.user;
    if (user.isGuest || user.id == null || user.id! <= 0) {
      return user;
    }

    final reachability = _reachabilityService.current;
    if (reachability.status == ReachabilityStatus.offline) {
      return user;
    }

    try {
      final refreshed = await getUserData(user.id!);
      final snapshot = await _sessionManager.currentSnapshot();
      await _sessionManager.persistAuthenticatedSession(
        token: snapshot?.token ?? await _storageService.getToken() ?? '',
        user: refreshed,
      );
      return refreshed;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        await _sessionManager.clear();
        _productRepository.invalidateCache();
        return null;
      }
      return user;
    } catch (_) {
      return user;
    }
  }

  Future<UserModel> loginAsGuest() async {
    final guest = UserModel.guest();
    await _sessionManager.persistGuestSession(guest);
    _productRepository.invalidateCache();
    return guest;
  }

  Future<void> logout() async {
    await _sessionManager.clear();
    _productRepository.invalidateCache();
  }

  Future<bool> hasToken() async {
    final token = await _storageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<UserModel?> getStoredUser() async {
    return _storageService.getUser();
  }

  String _normalizeEmail({
    String? email,
    required String username,
    required String phone,
  }) {
    final candidate = (email ?? '').trim().toLowerCase();
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (regex.hasMatch(candidate)) {
      return candidate;
    }

    final base = (username.isNotEmpty ? username : phone)
        .replaceAll(RegExp('[^a-zA-Z0-9._-]'), '')
        .toLowerCase();

    return '${base.isEmpty ? 'user' : base}@applpco.com';
  }

  String _normalizeUsernameForRegistration(String rawUsername) {
    final trimmed = rawUsername.trim();
    if (trimmed.isEmpty) {
      throw Exception('يرجى إدخال اسم مستخدم.');
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');

    if (normalized.length < 3) {
      throw Exception('اسم المستخدم يجب أن يكون 3 أحرف إنجليزية على الأقل.');
    }

    return normalized;
  }

  String _resolveDisplayName({
    required String username,
    required String firstName,
    required String company,
  }) {
    final candidate = TextSanitizer.fix(firstName).trim().isNotEmpty
        ? TextSanitizer.fix(firstName).trim()
        : TextSanitizer.fix(company).trim().isNotEmpty
        ? TextSanitizer.fix(company).trim()
        : TextSanitizer.fix(username).trim();
    return candidate.isEmpty ? 'مستخدم جديد' : candidate;
  }

  String _extractRegisterErrorMessage(
    DioException error, {
    required String attemptedUsername,
  }) {
    final payload = error.response?.data;
    final payloadMap = payload is Map
        ? Map<String, dynamic>.from(payload)
        : const <String, dynamic>{};
    final code = TextSanitizer.fix(payloadMap['code']).toLowerCase();
    final serverMessage = TextSanitizer.fix(
      ApiContract.extractErrorMessage(payload),
    ).trim();

    final suggested = _extractSuggestedUsernames(payloadMap);
    if (code == 'username_exists' ||
        serverMessage.toLowerCase().contains('username')) {
      if (suggested.isNotEmpty) {
        return 'اسم المستخدم "$attemptedUsername" مستخدم بالفعل. '
            'جرّب: ${suggested.take(3).join(' / ')}';
      }
      return 'اسم المستخدم "$attemptedUsername" مستخدم بالفعل. اختر اسمًا آخر.';
    }

    if (code == 'email_exists' ||
        serverMessage.toLowerCase().contains('email')) {
      return 'البريد الإلكتروني مستخدم بالفعل. استخدم بريدًا آخر.';
    }

    if (code == 'invalid_username') {
      return 'اسم المستخدم غير صالح. استخدم أحرفًا إنجليزية وأرقامًا فقط.';
    }

    if (code == 'invalid_email') {
      return 'صيغة البريد الإلكتروني غير صحيحة.';
    }

    if (code == 'weak_password') {
      return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
    }

    final safe = ApiContract.safeMessageFromException(
      error,
      fallback: 'تعذر إنشاء الحساب حالياً. يرجى إعادة المحاولة.',
    );
    final normalized = TextSanitizer.fix(safe).trim();
    if (normalized.isNotEmpty &&
        !normalized.toLowerCase().contains('<html') &&
        !normalized.toLowerCase().contains('forbidden')) {
      return normalized;
    }
    return 'تعذر إنشاء الحساب حالياً. يرجى إعادة المحاولة.';
  }

  List<String> _extractSuggestedUsernames(Map<String, dynamic> payloadMap) {
    final direct = payloadMap['suggested_usernames'];
    if (direct is List) {
      return direct
          .map((item) => TextSanitizer.fix(item).trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }

    final nested = payloadMap['data'];
    if (nested is Map) {
      return _extractSuggestedUsernames(Map<String, dynamic>.from(nested));
    }

    return const <String>[];
  }

  int? _extractUserId(String token, Map<String, dynamic> payload) {
    final fromPayload = payload['user_id'] ?? payload['ID'];
    if (fromPayload is int) {
      return fromPayload;
    }
    if (fromPayload != null) {
      final parsed = int.tryParse(fromPayload.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return null;
      }
      final body = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(body) as Map<String, dynamic>;
      final id = map['data']?['user']?['id'] ?? map['sub'];
      if (id is int) {
        return id;
      }
      return int.tryParse(id.toString());
    } catch (_) {
      return null;
    }
  }
}
