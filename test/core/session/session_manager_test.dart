import 'package:flutter_test/flutter_test.dart';
import 'package:lpco_llc/core/session/session_manager.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';

class FakeSessionStorage implements SessionStorage {
  String? token;
  String? userId;
  UserModel? user;
  Map<String, dynamic>? metadata;

  @override
  Future<void> saveToken(String token) async {
    this.token = token;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveUserId(String userId) async {
    this.userId = userId;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    this.user = user;
  }

  @override
  Future<UserModel?> getUser() async => user;

  @override
  Future<void> clearAuth() async {
    token = null;
    userId = null;
    user = null;
  }

  @override
  Future<void> saveSessionMetadata(Map<String, dynamic> payload) async {
    metadata = payload;
  }

  @override
  Map<String, dynamic>? getSessionMetadata() => metadata;

  @override
  Future<void> clearSessionMetadata() async {
    metadata = null;
  }
}

UserModel _user({int id = 10, String name = 'taha'}) {
  return UserModel(
    id: id,
    username: name,
    email: '$name@example.com',
    firstName: 'Test',
    lastName: 'User',
    displayName: 'Test User',
    userNicename: name,
    group: 'default',
    currency: 'syp',
    currencySymbol: 'SYP',
    roles: const <String>['customer'],
  );
}

void main() {
  group('SessionManager', () {
    test('restores authenticated user from local data while offline', () async {
      final storage = FakeSessionStorage();
      final manager = SessionManager(storage: storage);
      final user = _user();

      await manager.persistAuthenticatedSession(token: 'token-1', user: user);

      final restored = await manager.restore(online: false);

      expect(restored, isNotNull);
      expect(restored!.user.id, equals(user.id));
      expect(restored.restoredFromLocal, isTrue);
    });

    test('refreshes user remotely when online validation is due', () async {
      final storage = FakeSessionStorage();
      final manager = SessionManager(storage: storage);
      final original = _user(id: 20, name: 'old');

      await manager.persistAuthenticatedSession(
        token: 'token-2',
        user: original,
      );
      storage.metadata = <String, dynamic>{
        ...storage.metadata!,
        'last_online_validated_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 7))
            .toIso8601String(),
      };

      final restored = await manager.restore(
        online: true,
        refreshRemoteUser: (userId) async => _user(id: userId, name: 'fresh'),
      );

      expect(restored, isNotNull);
      expect(restored!.user.username, equals('fresh'));
      expect(restored.restoredFromLocal, isFalse);
    });

    test('returns null for authenticated user without token', () async {
      final storage = FakeSessionStorage();
      final manager = SessionManager(storage: storage);

      await storage.saveUser(_user(id: 30));
      await storage.saveSessionMetadata(<String, dynamic>{
        'token': '',
        'is_guest': false,
        'user_scope': 'user_30',
      });

      final restored = await manager.restore(online: false);

      expect(restored, isNull);
    });
  });
}
