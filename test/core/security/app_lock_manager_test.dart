import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lpco_llc/core/security/app_lock_manager.dart';
import 'package:lpco_llc/core/security/biometric_service.dart';
import 'package:lpco_llc/core/security/pin_service.dart';

class InMemorySettingsStore implements AppLockSettingsStore {
  final Map<String, Map<String, dynamic>> _store =
      <String, Map<String, dynamic>>{};

  @override
  Map<String, dynamic> getSettings(String userScope) {
    return Map<String, dynamic>.from(_store[userScope] ?? <String, dynamic>{});
  }

  @override
  Future<void> saveSettings(
    String userScope,
    Map<String, dynamic> payload,
  ) async {
    _store[userScope] = Map<String, dynamic>.from(payload);
  }
}

class _MemorySecureStore implements SecureValueStore {
  final Map<String, String> data = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

class FakeBiometricService extends BiometricService {
  final bool available;
  bool authResult;

  FakeBiometricService({required this.available, required this.authResult});

  @override
  Future<BiometricCapability> getCapability() async {
    return BiometricCapability(
      available: available,
      canCheckBiometrics: available,
      hasDeviceSupport: available,
      enrolledTypes: available
          ? const <BiometricType>[BiometricType.weak]
          : const <BiometricType>[],
    );
  }

  @override
  Future<BiometricAuthResult> authenticate({
    String reason = 'Authenticate to unlock app',
  }) async {
    return BiometricAuthResult(
      success: authResult,
      message: authResult ? '' : 'Biometric authentication failed in test',
    );
  }
}

void main() {
  group('AppLockManager', () {
    test(
      'daily biometric requirement is enforced when older than 24h',
      () async {
        final store = InMemorySettingsStore();
        final pinService = PinService(secureStore: _MemorySecureStore());
        final manager = AppLockManager(
          settingsStore: store,
          pinService: pinService,
          biometricService: FakeBiometricService(
            available: true,
            authResult: true,
          ),
        );

        await pinService.setPin(userScope: 'user_1', pin: '1234');
        await manager.saveSettings(
          'user_1',
          AppLockSettings.defaults().copyWith(
            appLockEnabled: true,
            pinEnabled: true,
            biometricEnabled: true,
            lastUnlockAt: DateTime.now().toUtc(),
            lastBiometricAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 25),
            ),
          ),
        );

        final requirement = await manager.evaluateUnlockRequirement('user_1');
        expect(requirement.requiresUnlock, isTrue);
        expect(requirement.requiresBiometric, isTrue);
        expect(requirement.canUseBiometric, isTrue);
      },
    );

    test('failed pin attempts trigger temporary lockout', () async {
      final store = InMemorySettingsStore();
      final secure = _MemorySecureStore();
      final pinService = PinService(secureStore: secure);
      final manager = AppLockManager(
        settingsStore: store,
        pinService: pinService,
        biometricService: FakeBiometricService(
          available: false,
          authResult: false,
        ),
      );

      await pinService.setPin(userScope: 'user_2', pin: '1111');
      await manager.saveSettings(
        'user_2',
        AppLockSettings.defaults().copyWith(
          appLockEnabled: true,
          pinEnabled: true,
          lastUnlockAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 3),
          ),
        ),
      );

      for (int i = 0; i < AppLockManager.maxFailedPinAttempts; i++) {
        await manager.unlockWithPin(userScope: 'user_2', pin: '9999');
      }

      final requirement = await manager.evaluateUnlockRequirement('user_2');
      expect(requirement.inLockout, isTrue);
      expect(requirement.lockoutUntil, isNotNull);
    });

    test('successful biometric unlock updates unlock state', () async {
      final store = InMemorySettingsStore();
      final pinService = PinService(secureStore: _MemorySecureStore());
      final manager = AppLockManager(
        settingsStore: store,
        pinService: pinService,
        biometricService: FakeBiometricService(
          available: true,
          authResult: true,
        ),
      );

      await manager.saveSettings(
        'user_3',
        AppLockSettings.defaults().copyWith(
          appLockEnabled: true,
          biometricEnabled: true,
          pinEnabled: false,
          lastUnlockAt: DateTime.now().toUtc().subtract(
            const Duration(days: 2),
          ),
        ),
      );

      final unlocked = await manager.unlockWithBiometric('user_3');
      expect(unlocked.success, isTrue);

      final settings = await manager.loadSettings('user_3');
      expect(settings.lastUnlockAt, isNotNull);
      expect(settings.lastBiometricAt, isNotNull);
    });
  });
}
