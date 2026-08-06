import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/network/reachability_service.dart';
import 'package:lpco_llc/core/security/app_lock_manager.dart';
import 'package:lpco_llc/core/services/push_notification_service.dart';
import 'package:lpco_llc/core/session/session_manager.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/account/data/repositories/account_repository.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

abstract class AccountDeletionConnectivity {
  Future<bool> canReachServer();
}

class ReachabilityAccountDeletionConnectivity
    implements AccountDeletionConnectivity {
  final ReachabilityService _reachability;

  ReachabilityAccountDeletionConnectivity({ReachabilityService? reachability})
    : _reachability = reachability ?? ReachabilityService();

  @override
  Future<bool> canReachServer() async {
    final snapshot = await _reachability.refresh(force: true);
    return snapshot.isOnline;
  }
}

abstract class AccountDeletionDataCleaner {
  Future<void> clear(UserModel user);
}

class LocalAccountDeletionDataCleaner implements AccountDeletionDataCleaner {
  final StorageService _storage;
  final SessionManager _sessionManager;
  final AppLockManager _appLockManager;
  final PushNotificationService _pushNotifications;

  LocalAccountDeletionDataCleaner({
    StorageService? storage,
    SessionManager? sessionManager,
    AppLockManager? appLockManager,
    PushNotificationService? pushNotifications,
  }) : _storage = storage ?? StorageService(),
       _sessionManager = sessionManager ?? SessionManager(),
       _appLockManager = appLockManager ?? AppLockManager(),
       _pushNotifications = pushNotifications ?? PushNotificationService();

  @override
  Future<void> clear(UserModel user) async {
    final scope = _sessionManager.buildUserScope(user);
    try {
      await _pushNotifications.forgetDeviceAfterAccountDeletion();
      try {
        await _appLockManager.removePin(scope);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Failed to clear deleted account PIN: $error');
        }
      }
      try {
        await _storage.clearUserScopedData(scope);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Failed to clear some scoped account data: $error');
        }
      }
    } finally {
      await _sessionManager.clear();
      ProductRepository().invalidateCache();
    }
  }
}

class AccountDeletionOfflineException implements Exception {
  const AccountDeletionOfflineException();
}

class AccountDeletionService {
  final AccountDeletionGateway _gateway;
  final AccountDeletionConnectivity _connectivity;
  final AccountDeletionDataCleaner _cleaner;

  AccountDeletionService({
    AccountDeletionGateway? gateway,
    AccountDeletionConnectivity? connectivity,
    AccountDeletionDataCleaner? cleaner,
  }) : _gateway = gateway ?? AccountRepository(),
       _connectivity =
           connectivity ?? ReachabilityAccountDeletionConnectivity(),
       _cleaner = cleaner ?? LocalAccountDeletionDataCleaner();

  Future<void> deleteAccount({
    required UserModel user,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const AccountDeletionException('يرجى إدخال كلمة المرور.');
    }
    if (!await _connectivity.canReachServer()) {
      throw const AccountDeletionOfflineException();
    }

    await _gateway.deleteCurrentAccount(password: password);
    await _cleaner.clear(user);
  }
}
