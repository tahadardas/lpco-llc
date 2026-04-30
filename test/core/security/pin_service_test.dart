import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/security/pin_service.dart';

class InMemorySecureStore implements SecureValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

void main() {
  group('PinService', () {
    test('stores hashed pin and validates correctly', () async {
      final store = InMemorySecureStore();
      final service = PinService(secureStore: store);

      await service.setPin(userScope: 'user_10', pin: '1234');

      expect(await service.hasPin('user_10'), isTrue);
      expect(
        await service.verifyPin(userScope: 'user_10', pin: '1234'),
        isTrue,
      );
      expect(
        await service.verifyPin(userScope: 'user_10', pin: '5678'),
        isFalse,
      );
    });

    test('rejects invalid pin format', () async {
      final store = InMemorySecureStore();
      final service = PinService(secureStore: store);

      expect(
        () => service.setPin(userScope: 'user_20', pin: '12ab'),
        throwsException,
      );
      expect(await service.hasPin('user_20'), isFalse);
    });

    test('clears pin securely', () async {
      final store = InMemorySecureStore();
      final service = PinService(secureStore: store);

      await service.setPin(userScope: 'user_30', pin: '9876');
      expect(await service.hasPin('user_30'), isTrue);

      await service.clearPin('user_30');
      expect(await service.hasPin('user_30'), isFalse);
      expect(
        await service.verifyPin(userScope: 'user_30', pin: '9876'),
        isFalse,
      );
    });
  });
}
