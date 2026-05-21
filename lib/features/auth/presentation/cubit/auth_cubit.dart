import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/security/app_lock_manager.dart';
import 'package:lpco_llc/core/session/session_manager.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';
import 'package:lpco_llc/features/auth/data/models/user_model.dart';
import 'package:lpco_llc/features/auth/data/repositories/auth_repository.dart';

abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated(this.user);
}

class GuestAuthenticated extends AuthState {
  final UserModel user;

  const GuestAuthenticated(this.user);
}

class AuthLocked extends AuthState {
  final UserModel user;
  final String userScope;
  final UnlockRequirement requirement;
  final String errorMessage;

  const AuthLocked({
    required this.user,
    required this.userScope,
    required this.requirement,
    this.errorMessage = '',
  });
}

class AuthSecuritySetupRequired extends AuthState {
  final UserModel user;
  final String userScope;
  final bool biometricAvailable;

  const AuthSecuritySetupRequired({
    required this.user,
    required this.userScope,
    required this.biometricAvailable,
  });
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final SessionManager _sessionManager;
  final AppLockManager _appLockManager;

  DateTime? _backgroundedAt;
  StreamSubscription<SessionExpiredEvent>? _sessionExpiredSubscription;

  AuthCubit({
    AuthRepository? authRepository,
    SessionManager? sessionManager,
    AppLockManager? appLockManager,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _sessionManager = sessionManager ?? SessionManager(),
       _appLockManager = appLockManager ?? AppLockManager(),
       super(const AuthInitial()) {
    _sessionExpiredSubscription = _sessionManager.expiredEvents.listen((_) {
      _backgroundedAt = null;
      _emitSafe(const Unauthenticated());
    });
    Future.microtask(checkAuthStatus);
  }

  void _emitSafe(AuthState next) {
    if (!isClosed) {
      emit(next);
    }
  }

  Future<void> checkAuthStatus() async {
    _emitSafe(const AuthLoading());
    try {
      final restored = await _authRepository.restoreSession();
      if (restored != null && restored.isGuest == false) {
        await _resolveAuthenticatedState(restored, enforceSecuritySetup: false);
        return;
      }

      final cachedUser = await _authRepository.getStoredUser();
      if (cachedUser != null && cachedUser.isGuest) {
        _backgroundedAt = null;
        _emitSafe(GuestAuthenticated(cachedUser));
        return;
      }

      _backgroundedAt = null;
      _emitSafe(const Unauthenticated());
    } catch (_) {
      _backgroundedAt = null;
      _emitSafe(const Unauthenticated());
    }
  }

  Future<void> login(String username, String password) async {
    _emitSafe(const AuthLoading());
    try {
      final user = await _authRepository.login(username, password);
      final scope = _sessionManager.buildUserScope(user);
      await _appLockManager.markUnlocked(scope);
      await _resolveAuthenticatedState(user, enforceSecuritySetup: true);
    } catch (error) {
      _emitSafe(AuthError(_normalizeError(error)));
    }
  }

  Future<void> loginAsGuest() async {
    _emitSafe(const AuthLoading());
    try {
      final guest = await _authRepository.loginAsGuest();
      _backgroundedAt = null;
      _emitSafe(GuestAuthenticated(guest));
    } catch (error) {
      _emitSafe(AuthError(_normalizeError(error)));
      _emitSafe(const Unauthenticated());
    }
  }

  Future<void> register({
    required String username,
    required String password,
    required String firstName,
    required String company,
    required String province,
    required String phone,
    required String address,
    String? email,
  }) async {
    _emitSafe(const AuthLoading());
    try {
      await _authRepository.register(
        username: username,
        password: password,
        firstName: firstName,
        company: company,
        province: province,
        phone: phone,
        address: address,
        email: email,
      );
      _emitSafe(const Unauthenticated());
    } catch (error) {
      _emitSafe(AuthError(_normalizeError(error)));
    }
  }

  Future<void> updateProfile({
    required String company,
    required String province,
    required String phone,
    required String address,
  }) async {
    final current = state;
    if (current is! Authenticated) {
      return;
    }

    _emitSafe(const AuthLoading());
    try {
      await _authRepository.updateProfile(
        userId: current.user.id!,
        company: company,
        province: province,
        phone: phone,
        address: address,
      );
      await checkAuthStatus();
    } catch (error) {
      _emitSafe(AuthError(_normalizeError(error)));
      _emitSafe(Authenticated(current.user));
    }
  }

  Future<void> logout() async {
    _backgroundedAt = null;
    _emitSafe(const AuthLoading());
    await _authRepository.logout();
    _emitSafe(const Unauthenticated());
  }

  Future<void> completeSecuritySetup({
    required String pin,
    required bool enableBiometric,
  }) async {
    final current = state;
    if (current is! AuthSecuritySetupRequired) {
      return;
    }

    await _appLockManager.configurePin(
      userScope: current.userScope,
      pin: pin,
      enableAppLock: true,
    );
    await _appLockManager.setBiometricEnabled(
      current.userScope,
      enableBiometric,
    );
    await _appLockManager.markUnlocked(current.userScope);
    _backgroundedAt = null;
    _emitSafe(Authenticated(current.user));
  }

  Future<void> skipSecuritySetup() async {
    final current = state;
    if (current is! AuthSecuritySetupRequired) {
      return;
    }

    await _appLockManager.setAppLockEnabled(current.userScope, false);
    _backgroundedAt = null;
    _emitSafe(Authenticated(current.user));
  }

  Future<void> unlockWithPin(String pin) async {
    final current = state;
    if (current is! AuthLocked) {
      return;
    }

    final valid = await _appLockManager.unlockWithPin(
      userScope: current.userScope,
      pin: pin,
    );
    if (valid) {
      _backgroundedAt = null;
      _emitSafe(Authenticated(current.user));
      return;
    }

    final requirement = await _appLockManager.evaluateUnlockRequirement(
      current.userScope,
    );
    final message = requirement.inLockout
        ? 'تم إيقاف إدخال رمز PIN مؤقتًا. استخدم البصمة أو حاول لاحقًا.'
        : 'رمز PIN غير صحيح.';
    _emitLocked(
      user: current.user,
      userScope: current.userScope,
      requirement: requirement,
      errorMessage: message,
    );
  }

  Future<void> unlockWithBiometric() async {
    final current = state;
    if (current is! AuthLocked) {
      return;
    }

    final result = await _appLockManager.unlockWithBiometric(current.userScope);
    if (result.success) {
      _backgroundedAt = null;
      _emitSafe(Authenticated(current.user));
      return;
    }

    final requirement = await _appLockManager.evaluateUnlockRequirement(
      current.userScope,
    );
    _emitLocked(
      user: current.user,
      userScope: current.userScope,
      requirement: requirement,
      errorMessage: _sanitizeMessage(
        result.message,
        fallback: 'تعذر التحقق بالبصمة. حاول مرة أخرى.',
      ),
    );
  }

  Future<void> onAppPaused() async {
    if (state is Authenticated) {
      _backgroundedAt = DateTime.now().toUtc();
    }
  }

  Future<void> onAppResumed() async {
    final current = state;
    if (current is! Authenticated) {
      return;
    }

    final pausedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (pausedAt == null) {
      return;
    }

    final scope = _sessionManager.buildUserScope(current.user);
    final settings = await _appLockManager.loadSettings(scope);
    if (!settings.appLockEnabled) {
      return;
    }

    final inactive = DateTime.now().toUtc().difference(pausedAt);
    final timeout = Duration(minutes: settings.inactivityTimeoutMinutes);
    if (inactive < timeout) {
      return;
    }

    final requirement = await _appLockManager.evaluateUnlockRequirement(scope);
    if (requirement.requiresUnlock) {
      _emitLocked(
        user: current.user,
        userScope: scope,
        requirement: requirement,
      );
    }
  }

  Future<void> _resolveAuthenticatedState(
    UserModel user, {
    required bool enforceSecuritySetup,
  }) async {
    final scope = _sessionManager.buildUserScope(user);
    final hasPin = await _appLockManager.hasPin(scope);
    final capability = await _appLockManager.biometricCapability();

    if (enforceSecuritySetup && !hasPin) {
      _emitSafe(
        AuthSecuritySetupRequired(
          user: user,
          userScope: scope,
          biometricAvailable: capability.available,
        ),
      );
      return;
    }

    final requirement = await _appLockManager.evaluateUnlockRequirement(scope);
    if (requirement.requiresUnlock) {
      _emitLocked(user: user, userScope: scope, requirement: requirement);
      return;
    }

    await _appLockManager.markUnlocked(scope);
    _backgroundedAt = null;
    _emitSafe(Authenticated(user));
  }

  void _emitLocked({
    required UserModel user,
    required String userScope,
    required UnlockRequirement requirement,
    String errorMessage = '',
  }) {
    _emitSafe(
      AuthLocked(
        user: user,
        userScope: userScope,
        requirement: requirement,
        errorMessage: errorMessage,
      ),
    );
  }

  String _sanitizeMessage(String value, {required String fallback}) {
    final sanitized = TextSanitizer.fix(value).trim();
    if (sanitized.isEmpty || _looksCorrupted(sanitized)) {
      return fallback;
    }
    return sanitized;
  }

  String _normalizeError(Object error) {
    final base = ApiContract.safeMessageFromException(
      error,
      fallback: 'تعذر تسجيل الدخول حالياً. يرجى إعادة المحاولة.',
    );
    final message = TextSanitizer.fix(base).trim();
    if (message.isNotEmpty &&
        !_looksCorrupted(message) &&
        !_looksLikeServerNoise(message)) {
      return message;
    }

    final lower = error.toString().toLowerCase();
    if (lower.contains('authorization') ||
        lower.contains('bearer') ||
        lower.contains('token')) {
      return 'تعذر تسجيل الدخول بسبب بيانات جلسة غير صالحة. تحقق من اسم المستخدم أو البريد الإلكتروني وكلمة المرور.';
    }
    return 'تعذر تسجيل الدخول حالياً. يرجى إعادة المحاولة.';
  }

  bool _looksCorrupted(String value) {
    if (value.isEmpty) {
      return false;
    }
    return RegExp(r'[ÃØÙƒ¢]').hasMatch(value);
  }

  bool _looksLikeServerNoise(String value) {
    final lowered = value.toLowerCase();
    return lowered.contains('@media') ||
        lowered.contains('<html') ||
        lowered.contains('<body') ||
        lowered.contains('forbidden');
  }

  UserModel? get currentUser {
    final current = state;
    if (current is Authenticated) {
      return current.user;
    }
    if (current is GuestAuthenticated) {
      return current.user;
    }
    if (current is AuthLocked) {
      return current.user;
    }
    if (current is AuthSecuritySetupRequired) {
      return current.user;
    }
    return null;
  }

  bool get isLoggedIn => state is Authenticated;
  bool get isGuest => state is GuestAuthenticated;

  @override
  Future<void> close() async {
    await _sessionExpiredSubscription?.cancel();
    await super.close();
  }
}
