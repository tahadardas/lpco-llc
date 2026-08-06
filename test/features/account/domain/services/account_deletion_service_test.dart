import 'package:flutter_test/flutter_test.dart';

import 'package:lpco_llc/features/account/data/repositories/account_repository.dart';
import 'package:lpco_llc/features/account/domain/services/account_deletion_service.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';

class FakeDeletionGateway implements AccountDeletionGateway {
  int calls = 0;
  String? password;

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    calls++;
    this.password = password;
  }
}

class FakeDeletionConnectivity implements AccountDeletionConnectivity {
  bool online;

  FakeDeletionConnectivity(this.online);

  @override
  Future<bool> canReachServer() async => online;
}

class FakeDeletionCleaner implements AccountDeletionDataCleaner {
  int calls = 0;

  @override
  Future<void> clear(UserModel user) async {
    calls++;
  }
}

UserModel _user() => UserModel(
  id: 42,
  username: 'customer42',
  email: 'customer42@example.com',
  firstName: 'عميل',
  lastName: 'اختبار',
  displayName: 'عميل اختبار',
  userNicename: 'customer42',
  roles: <String>['customer'],
);

void main() {
  test('requires confirmed server deletion before local cleanup', () async {
    final gateway = FakeDeletionGateway();
    final cleaner = FakeDeletionCleaner();
    final service = AccountDeletionService(
      gateway: gateway,
      connectivity: FakeDeletionConnectivity(true),
      cleaner: cleaner,
    );

    await service.deleteAccount(user: _user(), password: 'secret123');

    expect(gateway.calls, 1);
    expect(gateway.password, 'secret123');
    expect(cleaner.calls, 1);
  });

  test('does not call the server or clear data while offline', () async {
    final gateway = FakeDeletionGateway();
    final cleaner = FakeDeletionCleaner();
    final service = AccountDeletionService(
      gateway: gateway,
      connectivity: FakeDeletionConnectivity(false),
      cleaner: cleaner,
    );

    await expectLater(
      service.deleteAccount(user: _user(), password: 'secret123'),
      throwsA(isA<AccountDeletionOfflineException>()),
    );
    expect(gateway.calls, 0);
    expect(cleaner.calls, 0);
  });
}
