import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricCapability {
  final bool available;
  final bool canCheckBiometrics;
  final bool hasDeviceSupport;
  final List<BiometricType> enrolledTypes;

  const BiometricCapability({
    required this.available,
    required this.canCheckBiometrics,
    required this.hasDeviceSupport,
    required this.enrolledTypes,
  });

  static const BiometricCapability unavailable = BiometricCapability(
    available: false,
    canCheckBiometrics: false,
    hasDeviceSupport: false,
    enrolledTypes: <BiometricType>[],
  );
}

class BiometricAuthResult {
  final bool success;
  final String message;

  const BiometricAuthResult({required this.success, this.message = ''});
}

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  Future<BiometricCapability> getCapability() async {
    if (kIsWeb) {
      return BiometricCapability.unavailable;
    }

    try {
      final hasSupport = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final enrolled = await _auth.getAvailableBiometrics();
      return BiometricCapability(
        available: hasSupport && enrolled.isNotEmpty,
        canCheckBiometrics: canCheck,
        hasDeviceSupport: hasSupport,
        enrolledTypes: enrolled,
      );
    } catch (_) {
      return BiometricCapability.unavailable;
    }
  }

  Future<BiometricAuthResult> authenticate({
    String reason = 'يرجى تأكيد البصمة أو التحقق الحيوي للمتابعة',
  }) async {
    if (kIsWeb) {
      return const BiometricAuthResult(
        success: false,
        message: 'المصادقة الحيوية غير مدعومة على الويب.',
      );
    }

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        return const BiometricAuthResult(success: true);
      }
      return const BiometricAuthResult(
        success: false,
        message: 'تعذر إتمام التحقق الحيوي. حاول مرة أخرى.',
      );
    } on LocalAuthException catch (error) {
      return BiometricAuthResult(
        success: false,
        message: _messageForException(error),
      );
    } catch (_) {
      return const BiometricAuthResult(
        success: false,
        message: 'تعذر تشغيل المصادقة الحيوية على هذا الجهاز حاليًا.',
      );
    }
  }

  String _messageForException(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.userCanceled:
        return 'تم إلغاء المصادقة الحيوية.';
      case LocalAuthExceptionCode.timeout:
        return 'انتهت مهلة المصادقة الحيوية. حاول مرة أخرى.';
      case LocalAuthExceptionCode.systemCanceled:
        return 'أوقف النظام المصادقة الحيوية مؤقتًا. أعد المحاولة.';
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'لا توجد بصمة أو طريقة تحقق حيوية مفعلة على هذا الجهاز.';
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'ميزة البصمة أو التحقق الحيوي غير متاحة على هذا الجهاز حاليًا.';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'تم قفل المصادقة الحيوية مؤقتًا. استخدم رمز PIN ثم حاول لاحقًا.';
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'اختر المستخدم طريقة بديلة بدل المصادقة الحيوية.';
      case LocalAuthExceptionCode.authInProgress:
        return 'هناك محاولة تحقق حيوية قيد التنفيذ بالفعل.';
      case LocalAuthExceptionCode.uiUnavailable:
        return 'تعذر عرض واجهة المصادقة الحيوية على الجهاز.';
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'حدث خطأ غير متوقع أثناء المصادقة الحيوية.';
    }
  }
}
