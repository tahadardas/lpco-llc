import 'package:lpco_llc/core/security/biometric_service.dart';
import 'package:lpco_llc/core/security/pin_service.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';

abstract class AppLockSettingsStore {
  Map<String, dynamic> getSettings(String userScope);
  Future<void> saveSettings(String userScope, Map<String, dynamic> payload);
}

class HiveAppLockSettingsStore implements AppLockSettingsStore {
  final StorageService _storage;

  HiveAppLockSettingsStore({StorageService? storage})
    : _storage = storage ?? StorageService();

  @override
  Map<String, dynamic> getSettings(String userScope) {
    return _storage.getAppLockSettings(userScope);
  }

  @override
  Future<void> saveSettings(String userScope, Map<String, dynamic> payload) {
    return _storage.saveAppLockSettings(userScope, payload);
  }
}

class AppLockSettings {
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool pinEnabled;
  final DateTime? lastBiometricAt;
  final DateTime? lastUnlockAt;
  final int failedPinAttempts;
  final DateTime? lockoutUntil;
  final int inactivityTimeoutMinutes;

  const AppLockSettings({
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.pinEnabled,
    required this.lastBiometricAt,
    required this.lastUnlockAt,
    required this.failedPinAttempts,
    required this.lockoutUntil,
    required this.inactivityTimeoutMinutes,
  });

  factory AppLockSettings.defaults() {
    return const AppLockSettings(
      appLockEnabled: false,
      biometricEnabled: false,
      pinEnabled: false,
      lastBiometricAt: null,
      lastUnlockAt: null,
      failedPinAttempts: 0,
      lockoutUntil: null,
      inactivityTimeoutMinutes: 10,
    );
  }

  factory AppLockSettings.fromJson(Map<String, dynamic> json) {
    return AppLockSettings(
      appLockEnabled: json['app_lock_enabled'] == true,
      biometricEnabled: json['biometric_enabled'] == true,
      pinEnabled: json['pin_enabled'] == true,
      lastBiometricAt: DateTime.tryParse(
        (json['last_biometric_at'] ?? '').toString(),
      ),
      lastUnlockAt: DateTime.tryParse(
        (json['last_unlock_at'] ?? '').toString(),
      ),
      failedPinAttempts: json['failed_pin_attempts'] is int
          ? json['failed_pin_attempts'] as int
          : int.tryParse('${json['failed_pin_attempts'] ?? '0'}') ?? 0,
      lockoutUntil: DateTime.tryParse((json['lockout_until'] ?? '').toString()),
      inactivityTimeoutMinutes: json['inactivity_timeout_minutes'] is int
          ? json['inactivity_timeout_minutes'] as int
          : int.tryParse('${json['inactivity_timeout_minutes'] ?? '10'}') ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'app_lock_enabled': appLockEnabled,
      'biometric_enabled': biometricEnabled,
      'pin_enabled': pinEnabled,
      'last_biometric_at': lastBiometricAt?.toUtc().toIso8601String(),
      'last_unlock_at': lastUnlockAt?.toUtc().toIso8601String(),
      'failed_pin_attempts': failedPinAttempts,
      'lockout_until': lockoutUntil?.toUtc().toIso8601String(),
      'inactivity_timeout_minutes': inactivityTimeoutMinutes,
    };
  }

  AppLockSettings copyWith({
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? pinEnabled,
    DateTime? lastBiometricAt,
    DateTime? lastUnlockAt,
    int? failedPinAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
    int? inactivityTimeoutMinutes,
  }) {
    return AppLockSettings(
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      lastBiometricAt: lastBiometricAt ?? this.lastBiometricAt,
      lastUnlockAt: lastUnlockAt ?? this.lastUnlockAt,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
      inactivityTimeoutMinutes:
          inactivityTimeoutMinutes ?? this.inactivityTimeoutMinutes,
    );
  }
}

class UnlockRequirement {
  final bool requiresUnlock;
  final bool requiresBiometric;
  final bool canUseBiometric;
  final bool canUsePin;
  final bool inLockout;
  final DateTime? lockoutUntil;

  const UnlockRequirement({
    required this.requiresUnlock,
    required this.requiresBiometric,
    required this.canUseBiometric,
    required this.canUsePin,
    required this.inLockout,
    required this.lockoutUntil,
  });
}

class AppLockManager {
  static const Duration biometricReverifyWindow = Duration(hours: 24);
  static const int maxFailedPinAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  final AppLockSettingsStore _settingsStore;
  final PinService _pinService;
  final BiometricService _biometricService;

  AppLockManager({
    AppLockSettingsStore? settingsStore,
    PinService? pinService,
    BiometricService? biometricService,
  }) : _settingsStore = settingsStore ?? HiveAppLockSettingsStore(),
       _pinService = pinService ?? PinService(),
       _biometricService = biometricService ?? BiometricService();

  Future<AppLockSettings> loadSettings(String userScope) async {
    final raw = _settingsStore.getSettings(userScope);
    if (raw.isEmpty) {
      return AppLockSettings.defaults();
    }

    return AppLockSettings.fromJson(raw);
  }

  Future<void> saveSettings(String userScope, AppLockSettings settings) async {
    await _settingsStore.saveSettings(userScope, settings.toJson());
  }

  Future<UnlockRequirement> evaluateUnlockRequirement(String userScope) async {
    final settings = await loadSettings(userScope);
    if (!settings.appLockEnabled) {
      return const UnlockRequirement(
        requiresUnlock: false,
        requiresBiometric: false,
        canUseBiometric: false,
        canUsePin: false,
        inLockout: false,
        lockoutUntil: null,
      );
    }

    final now = DateTime.now().toUtc();
    final pinConfigured = await _pinService.hasPin(userScope);
    final capability = await _biometricService.getCapability();

    final lockoutUntil = settings.lockoutUntil;
    final inLockout = lockoutUntil != null && lockoutUntil.isAfter(now);

    final timeout = Duration(minutes: settings.inactivityTimeoutMinutes);
    final hasRecentUnlock =
        settings.lastUnlockAt != null &&
        now.difference(settings.lastUnlockAt!) <= timeout;

    final requiresBiometric =
        settings.biometricEnabled &&
        capability.available &&
        (settings.lastBiometricAt == null ||
            now.difference(settings.lastBiometricAt!) >=
                biometricReverifyWindow);

    final requiresUnlock = inLockout || !hasRecentUnlock || requiresBiometric;

    return UnlockRequirement(
      requiresUnlock: requiresUnlock,
      requiresBiometric: requiresBiometric,
      canUseBiometric: settings.biometricEnabled && capability.available,
      canUsePin: settings.pinEnabled && pinConfigured,
      inLockout: inLockout,
      lockoutUntil: lockoutUntil,
    );
  }

  Future<void> configurePin({
    required String userScope,
    required String pin,
    bool enableAppLock = true,
  }) async {
    await _pinService.setPin(userScope: userScope, pin: pin);

    final current = await loadSettings(userScope);
    await saveSettings(
      userScope,
      current.copyWith(
        appLockEnabled: enableAppLock,
        pinEnabled: true,
        failedPinAttempts: 0,
        clearLockout: true,
        lastUnlockAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> removePin(String userScope) async {
    await _pinService.clearPin(userScope);
    final current = await loadSettings(userScope);
    await saveSettings(
      userScope,
      current.copyWith(
        pinEnabled: false,
        biometricEnabled: false,
        appLockEnabled: false,
        failedPinAttempts: 0,
        clearLockout: true,
      ),
    );
  }

  Future<void> setBiometricEnabled(String userScope, bool enabled) async {
    final capability = await _biometricService.getCapability();
    final current = await loadSettings(userScope);
    final nextEnabled = enabled && capability.available;
    await saveSettings(
      userScope,
      current.copyWith(
        biometricEnabled: nextEnabled,
        appLockEnabled: nextEnabled || current.pinEnabled,
      ),
    );
  }

  Future<void> setAppLockEnabled(String userScope, bool enabled) async {
    final current = await loadSettings(userScope);
    final hasPin = await _pinService.hasPin(userScope);
    final shouldEnable = enabled && hasPin;
    await saveSettings(
      userScope,
      current.copyWith(appLockEnabled: shouldEnable),
    );
  }

  Future<BiometricAuthResult> unlockWithBiometric(String userScope) async {
    final settings = await loadSettings(userScope);
    if (!settings.biometricEnabled) {
      return const BiometricAuthResult(
        success: false,
        message: 'المصادقة الحيوية غير مفعلة لهذا الحساب.',
      );
    }

    final result = await _biometricService.authenticate(
      reason: 'يرجى التحقق بالبصمة لفتح جلسة LPCO',
    );
    if (!result.success) {
      return result;
    }

    final now = DateTime.now().toUtc();
    await saveSettings(
      userScope,
      settings.copyWith(
        lastBiometricAt: now,
        lastUnlockAt: now,
        failedPinAttempts: 0,
        clearLockout: true,
      ),
    );
    return const BiometricAuthResult(success: true);
  }

  Future<bool> unlockWithPin({
    required String userScope,
    required String pin,
  }) async {
    final settings = await loadSettings(userScope);
    final now = DateTime.now().toUtc();

    if (settings.lockoutUntil != null && settings.lockoutUntil!.isAfter(now)) {
      return false;
    }

    final valid = await _pinService.verifyPin(userScope: userScope, pin: pin);
    if (valid) {
      await saveSettings(
        userScope,
        settings.copyWith(
          lastUnlockAt: now,
          failedPinAttempts: 0,
          clearLockout: true,
        ),
      );
      return true;
    }

    final nextFailures = settings.failedPinAttempts + 1;
    final shouldLockout = nextFailures >= maxFailedPinAttempts;

    await saveSettings(
      userScope,
      settings.copyWith(
        failedPinAttempts: shouldLockout ? 0 : nextFailures,
        lockoutUntil: shouldLockout ? now.add(lockoutDuration) : null,
        clearLockout: !shouldLockout,
      ),
    );
    return false;
  }

  Future<void> markUnlocked(String userScope) async {
    final current = await loadSettings(userScope);
    await saveSettings(
      userScope,
      current.copyWith(
        lastUnlockAt: DateTime.now().toUtc(),
        failedPinAttempts: 0,
        clearLockout: true,
      ),
    );
  }

  Future<bool> hasPin(String userScope) {
    return _pinService.hasPin(userScope);
  }

  Future<BiometricCapability> biometricCapability() {
    return _biometricService.getCapability();
  }
}
