import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class ApiFailure {
  final String code;
  final String message;
  final int status;
  final String endpoint;

  const ApiFailure({
    required this.code,
    required this.message,
    required this.status,
    required this.endpoint,
  });

  @override
  String toString() {
    return '$message (code: $code, status: $status, endpoint: $endpoint)';
  }
}

class ApiContractException implements Exception {
  final ApiFailure failure;

  const ApiContractException(this.failure);

  @override
  String toString() => 'ApiContractException: ${failure.toString()}';
}

class ApiContract {
  static const String genericLoadFailure =
      'تعذر تحميل البيانات، يرجى إعادة المحاولة.';
  static const String sessionExpiredFailure =
      'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.';
  static const String serverUnavailableFailure =
      'تعذر الوصول إلى الخادم حالياً.';
  static const String deviceTokenFailure =
      'يجب تهيئة معرف الجهاز للإشعارات. تأكد من الاتصال ثم أعد المحاولة.';

  static Map<String, dynamic> expectMap(
    dynamic payload, {
    required String endpoint,
  }) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }

    throw ApiContractException(
      ApiFailure(
        code: 'invalid_payload',
        message: 'استجابة الخادم غير متوقعة.',
        status: 500,
        endpoint: endpoint,
      ),
    );
  }

  static List<dynamic> expectList(
    dynamic payload, {
    required String endpoint,
    List<String> envelopeKeys = const <String>[],
  }) {
    if (payload is List) {
      return payload;
    }

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in envelopeKeys) {
        final value = map[key];
        if (value is List) {
          return value;
        }
      }
    }

    throw ApiContractException(
      ApiFailure(
        code: 'invalid_payload',
        message: 'صيغة بيانات غير مدعومة من الخادم.',
        status: 500,
        endpoint: endpoint,
      ),
    );
  }

  static String extractErrorMessage(dynamic payload, {int? statusCode}) {
    final status = statusCode ?? _extractStatusCode(payload);

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final code = TextSanitizer.fix(map['code']).toLowerCase();
      final message = _cleanServerText(
        TextSanitizer.fix(map['message'] ?? map['error'] ?? map['detail']),
      );
      final lowered = message.toLowerCase();

      if (_isAuthFailure(code, lowered) || status == 401) {
        return sessionExpiredFailure;
      }

      if (code.contains('invalid_username')) {
        return 'اسم المستخدم أو البريد الإلكتروني غير مسجل.';
      }

      if (code.contains('incorrect_password')) {
        return 'كلمة المرور غير صحيحة.';
      }

      if (_isDeviceTokenFailure(code, lowered)) {
        return deviceTokenFailure;
      }

      if (_looksLikeForbiddenDocument(message) || status == 403) {
        return _messageByStatus(status);
      }

      if (_isSafeUserMessage(message)) {
        return message;
      }
    }

    if (payload is String) {
      final message = _cleanServerText(TextSanitizer.fix(payload));
      final normalized = message.toLowerCase();
      if (_isDeviceTokenFailure('', normalized)) {
        return deviceTokenFailure;
      }
      if (_looksLikeForbiddenDocument(payload) ||
          _looksLikeForbiddenDocument(message) ||
          status == 403) {
        return _messageByStatus(status);
      }
      if (_isSafeUserMessage(message)) {
        return message;
      }
    }

    return _messageByStatus(status);
  }

  static String safeMessageFromException(
    Object error, {
    String fallback = genericLoadFailure,
  }) {
    if (error is ApiContractException) {
      final message = extractErrorMessage(
        error.failure.message,
        statusCode: error.failure.status,
      );
      return _isSafeUserMessage(message) ? message : fallback;
    }

    final raw = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
        .trim();
    if (raw.isEmpty) {
      return fallback;
    }

    final message = _cleanServerText(TextSanitizer.fix(raw));
    if (_isSafeUserMessage(message)) {
      return message;
    }
    return fallback;
  }

  static String _stripHtml(String value) {
    return value.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  static String _cleanServerText(String value) {
    return _stripHtml(value)
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\s*forbidden\s*', caseSensitive: false), '')
        .trim();
  }

  static bool _isAuthFailure(String code, String message) {
    if (code.contains('jwt') ||
        code.contains('token') ||
        code.contains('rest_forbidden') ||
        code.contains('forbidden')) {
      return true;
    }
    return message.contains('authorization') ||
        message.contains('bearer') ||
        message.contains('unauthorized') ||
        message.contains('expired token') ||
        message.contains('invalid token');
  }

  static bool _isDeviceTokenFailure(String code, String message) {
    return code == 'token_missing' ||
        code == 'token_not_found' ||
        code == 'invalid_token' ||
        message.contains('device token is required') ||
        message.contains('unknown device token');
  }

  static bool _looksLikeForbiddenDocument(String value) {
    final lowered = value.toLowerCase();
    if (lowered.contains('<html') ||
        lowered.contains('<body') ||
        lowered.contains('<!doctype') ||
        lowered.contains('@media') ||
        lowered.contains('background-color') ||
        lowered.contains('forbidden access to this resource') ||
        lowered.contains('access denied') ||
        lowered.contains('mod_security') ||
        lowered.contains('cloudflare')) {
      return true;
    }
    return false;
  }

  static bool _isSafeUserMessage(String value) {
    final message = value.trim();
    if (message.isEmpty) {
      return false;
    }
    if (message.length > 240) {
      return false;
    }
    if (_looksLikeForbiddenDocument(message)) {
      return false;
    }
    return true;
  }

  static String _messageByStatus(int? status) {
    if (status == 401) {
      return sessionExpiredFailure;
    }
    if (status == 403 || status == 404 || status == 502 || status == 503) {
      return serverUnavailableFailure;
    }
    return genericLoadFailure;
  }

  static int? _extractStatusCode(dynamic payload) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final status = map['status'];
      if (status is int) {
        return status;
      }
      if (status is String) {
        return int.tryParse(status);
      }
      final data = map['data'];
      if (data is Map) {
        final nested = data['status'];
        if (nested is int) {
          return nested;
        }
        if (nested is String) {
          return int.tryParse(nested);
        }
      }
    }
    return null;
  }
}
