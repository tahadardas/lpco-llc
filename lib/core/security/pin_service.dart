import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';

abstract class SecureValueStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class FlutterSecureValueStore implements SecureValueStore {
  final StorageService _storage;

  FlutterSecureValueStore({StorageService? storage})
    : _storage = storage ?? StorageService();

  @override
  Future<void> write(String key, String value) {
    return _storage.writeSecure(key, value);
  }

  @override
  Future<String?> read(String key) {
    return _storage.readSecure(key);
  }

  @override
  Future<void> delete(String key) {
    return _storage.deleteSecure(key);
  }
}

class PinService {
  static const int minPinLength = 4;
  static const int maxPinLength = 8;

  final SecureValueStore _secureStore;

  PinService({SecureValueStore? secureStore})
    : _secureStore = secureStore ?? FlutterSecureValueStore();

  String _hashKey(String userScope) => 'app_pin_hash::$userScope';
  String _saltKey(String userScope) => 'app_pin_salt::$userScope';

  bool isValidPinFormat(String pin) {
    final normalized = pin.trim();
    return RegExp(r'^[0-9]{4,8}$').hasMatch(normalized);
  }

  Future<bool> hasPin(String userScope) async {
    final hash = await _secureStore.read(_hashKey(userScope));
    final salt = await _secureStore.read(_saltKey(userScope));
    return (hash ?? '').isNotEmpty && (salt ?? '').isNotEmpty;
  }

  Future<void> setPin({required String userScope, required String pin}) async {
    if (!isValidPinFormat(pin)) {
      throw Exception('PIN must be 4 to 8 digits');
    }

    final salt = _generateSalt();
    final digest = _hash(pin: pin, salt: salt);

    await _secureStore.write(_saltKey(userScope), salt);
    await _secureStore.write(_hashKey(userScope), digest);
  }

  Future<bool> verifyPin({
    required String userScope,
    required String pin,
  }) async {
    if (!isValidPinFormat(pin)) {
      return false;
    }

    final salt = await _secureStore.read(_saltKey(userScope));
    final savedHash = await _secureStore.read(_hashKey(userScope));

    if ((salt ?? '').isEmpty || (savedHash ?? '').isEmpty) {
      return false;
    }

    final digest = _hash(pin: pin, salt: salt!);
    return digest == savedHash;
  }

  Future<void> clearPin(String userScope) async {
    await _secureStore.delete(_saltKey(userScope));
    await _secureStore.delete(_hashKey(userScope));
  }

  String _hash({required String pin, required String salt}) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    Random random;
    try {
      random = Random.secure();
    } catch (_) {
      random = Random();
    }

    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
