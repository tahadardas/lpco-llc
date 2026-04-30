import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';

abstract class SessionStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> saveUserId(String userId);
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> clearAuth();
  Future<void> saveSessionMetadata(Map<String, dynamic> payload);
  Map<String, dynamic>? getSessionMetadata();
  Future<void> clearSessionMetadata();
}

class StorageServiceSessionStorage implements SessionStorage {
  final StorageService _storage;

  StorageServiceSessionStorage({StorageService? storage})
    : _storage = storage ?? StorageService();

  @override
  Future<void> saveToken(String token) => _storage.saveToken(token);

  @override
  Future<String?> getToken() => _storage.getToken();

  @override
  Future<void> saveUserId(String userId) => _storage.saveUserId(userId);

  @override
  Future<void> saveUser(UserModel user) => _storage.saveUser(user);

  @override
  Future<UserModel?> getUser() => _storage.getUser();

  @override
  Future<void> clearAuth() => _storage.clearAuth();

  @override
  Future<void> saveSessionMetadata(Map<String, dynamic> payload) =>
      _storage.saveSessionMetadata(payload);

  @override
  Map<String, dynamic>? getSessionMetadata() => _storage.getSessionMetadata();

  @override
  Future<void> clearSessionMetadata() => _storage.clearSessionMetadata();
}

class SessionSnapshot {
  final String token;
  final String userScope;
  final bool isGuest;
  final DateTime? lastAuthenticatedAt;
  final DateTime? lastOnlineValidatedAt;

  const SessionSnapshot({
    required this.token,
    required this.userScope,
    required this.isGuest,
    required this.lastAuthenticatedAt,
    required this.lastOnlineValidatedAt,
  });

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    return SessionSnapshot(
      token: (json['token'] ?? '').toString(),
      userScope: (json['user_scope'] ?? 'guest').toString(),
      isGuest: json['is_guest'] == true,
      lastAuthenticatedAt: DateTime.tryParse(
        (json['last_authenticated_at'] ?? '').toString(),
      ),
      lastOnlineValidatedAt: DateTime.tryParse(
        (json['last_online_validated_at'] ?? '').toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'token': token,
      'user_scope': userScope,
      'is_guest': isGuest,
      'last_authenticated_at': lastAuthenticatedAt?.toUtc().toIso8601String(),
      'last_online_validated_at': lastOnlineValidatedAt
          ?.toUtc()
          .toIso8601String(),
    };
  }

  SessionSnapshot copyWith({
    String? token,
    String? userScope,
    bool? isGuest,
    DateTime? lastAuthenticatedAt,
    DateTime? lastOnlineValidatedAt,
  }) {
    return SessionSnapshot(
      token: token ?? this.token,
      userScope: userScope ?? this.userScope,
      isGuest: isGuest ?? this.isGuest,
      lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
      lastOnlineValidatedAt:
          lastOnlineValidatedAt ?? this.lastOnlineValidatedAt,
    );
  }
}

class SessionRestoreResult {
  final UserModel user;
  final SessionSnapshot snapshot;
  final bool restoredFromLocal;

  const SessionRestoreResult({
    required this.user,
    required this.snapshot,
    required this.restoredFromLocal,
  });
}

class SessionManager {
  static const Duration onlineValidationInterval = Duration(hours: 6);

  final SessionStorage _storage;

  SessionManager({SessionStorage? storage})
    : _storage = storage ?? StorageServiceSessionStorage();

  String buildUserScope(UserModel user) {
    if (user.isGuest) {
      return 'guest';
    }

    final idPart = user.id?.toString();
    if ((idPart ?? '').isNotEmpty) {
      return 'user_$idPart';
    }

    final fallback = user.username.trim().isEmpty
        ? 'unknown'
        : user.username.trim();
    return 'user_$fallback';
  }

  Future<void> persistAuthenticatedSession({
    required String token,
    required UserModel user,
  }) async {
    if (user.id == null || user.id! <= 0) {
      throw Exception('Authenticated session requires a valid user id');
    }

    await _storage.saveToken(token);
    await _storage.saveUserId(user.id.toString());
    await _storage.saveUser(user);

    final snapshot = SessionSnapshot(
      token: token,
      userScope: buildUserScope(user),
      isGuest: false,
      lastAuthenticatedAt: DateTime.now().toUtc(),
      lastOnlineValidatedAt: DateTime.now().toUtc(),
    );

    await _storage.saveSessionMetadata(snapshot.toJson());
  }

  Future<void> persistGuestSession(UserModel guestUser) async {
    await _storage.clearAuth();
    await _storage.saveUser(guestUser);

    final snapshot = SessionSnapshot(
      token: '',
      userScope: 'guest',
      isGuest: true,
      lastAuthenticatedAt: DateTime.now().toUtc(),
      lastOnlineValidatedAt: null,
    );

    await _storage.saveSessionMetadata(snapshot.toJson());
  }

  Future<SessionRestoreResult?> restore({
    required bool online,
    Future<UserModel> Function(int userId)? refreshRemoteUser,
  }) async {
    final storedUser = await _storage.getUser();
    if (storedUser == null) {
      return null;
    }

    final snapshot =
        SessionSnapshot.fromJson(
          _storage.getSessionMetadata() ?? <String, dynamic>{},
        ).copyWith(
          userScope: buildUserScope(storedUser),
          isGuest: storedUser.isGuest,
          token: await _storage.getToken() ?? '',
        );

    if (storedUser.isGuest) {
      return SessionRestoreResult(
        user: storedUser,
        snapshot: snapshot,
        restoredFromLocal: true,
      );
    }

    if (snapshot.token.isEmpty) {
      return null;
    }

    final userId = storedUser.id;
    final shouldAttemptValidation =
        online &&
        userId != null &&
        userId > 0 &&
        _shouldValidateOnline(snapshot);

    if (!shouldAttemptValidation || refreshRemoteUser == null) {
      return SessionRestoreResult(
        user: storedUser,
        snapshot: snapshot,
        restoredFromLocal: true,
      );
    }

    try {
      final refreshed = await refreshRemoteUser(userId);
      await _storage.saveUser(refreshed);
      final validatedSnapshot = snapshot.copyWith(
        userScope: buildUserScope(refreshed),
        lastOnlineValidatedAt: DateTime.now().toUtc(),
      );
      await _storage.saveSessionMetadata(validatedSnapshot.toJson());
      return SessionRestoreResult(
        user: refreshed,
        snapshot: validatedSnapshot,
        restoredFromLocal: false,
      );
    } catch (_) {
      return SessionRestoreResult(
        user: storedUser,
        snapshot: snapshot,
        restoredFromLocal: true,
      );
    }
  }

  Future<void> markOnlineValidated() async {
    final current = SessionSnapshot.fromJson(
      _storage.getSessionMetadata() ?? <String, dynamic>{},
    );
    final updated = current.copyWith(
      lastOnlineValidatedAt: DateTime.now().toUtc(),
    );
    await _storage.saveSessionMetadata(updated.toJson());
  }

  Future<void> clear() async {
    await _storage.clearAuth();
    await _storage.clearSessionMetadata();
  }

  Future<SessionSnapshot?> currentSnapshot() async {
    final user = await _storage.getUser();
    if (user == null) {
      return null;
    }

    final metadata = _storage.getSessionMetadata() ?? <String, dynamic>{};
    final snapshot = SessionSnapshot.fromJson(metadata);
    return snapshot.copyWith(
      token: await _storage.getToken() ?? '',
      userScope: buildUserScope(user),
      isGuest: user.isGuest,
    );
  }

  bool _shouldValidateOnline(SessionSnapshot snapshot) {
    final validatedAt = snapshot.lastOnlineValidatedAt;
    if (validatedAt == null) {
      return true;
    }

    final elapsed = DateTime.now().toUtc().difference(validatedAt);
    return elapsed >= onlineValidationInterval;
  }
}
