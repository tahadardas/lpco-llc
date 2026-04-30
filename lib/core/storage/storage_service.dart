import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:lpco_llc/features/auth/data/models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal();

  static const int currentSchemaVersion = 2;

  late final FlutterSecureStorage secureStorage;
  late final SharedPreferences sharedPreferences;
  bool _initialized = false;

  // Box Names
  static const String dbMetaBoxName = 'local_db_meta';
  static const String cartBoxName = 'cart_box';
  static const String behaviorBoxName = 'behavior_box';
  static const String settingsBoxName = 'settings_box';
  static const String recentSearchesBoxName = 'recent_searches';
  static const String sessionBoxName = 'session_box';
  static const String catalogBoxName = 'catalog_box';
  static const String ordersBoxName = 'orders_box';
  static const String syncQueueBoxName = 'sync_queue_box';
  static const String syncMetaBoxName = 'sync_meta_box';
  static const String searchIndexBoxName = 'search_index_box';

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userKey = 'current_user';
  static const String _deviceTokenKey = 'device_token';
  static const String _savedProductsPrefix = 'saved_products_';
  static const String _lastRouteKey = 'last_route_state';
  static const String _recentSearchesKey = 'terms';
  static const String _sessionMetaKey = 'session_metadata';
  static const String _schemaVersionKey = 'schema_version';

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    // 1. Initialize Hive
    await Hive.initFlutter();

    // Open necessary boxes
    await Hive.openBox(dbMetaBoxName);
    await Hive.openBox(cartBoxName);
    await Hive.openBox(behaviorBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(recentSearchesBoxName);
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(catalogBoxName);
    await Hive.openBox(ordersBoxName);
    await Hive.openBox(syncQueueBoxName);
    await Hive.openBox(syncMetaBoxName);
    await Hive.openBox(searchIndexBoxName);
    await _runMigrations();

    // 2. Initialize Secure Storage
    secureStorage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );

    // 3. Initialize Shared Preferences
    sharedPreferences = await SharedPreferences.getInstance();
    _initialized = true;
  }

  Future<void> _runMigrations() async {
    final meta = dbMetaBox;
    final version = meta.get(_schemaVersionKey);
    final previousVersion = version is int ? version : 0;

    if (previousVersion < 1) {
      // Initial baseline migration slot.
    }

    if (previousVersion < 2) {
      // Move legacy cart payload to scoped guest key.
      final rawLegacy = cartBox.get('local_cart');
      if (rawLegacy != null && cartBox.get(cartScopeKey('guest')) == null) {
        await cartBox.put(cartScopeKey('guest'), rawLegacy);
      }
    }

    await meta.put(_schemaVersionKey, currentSchemaVersion);
  }

  String cartScopeKey(String userScope) {
    final normalized = userScope.trim().isEmpty ? 'guest' : userScope.trim();
    return 'cart::$normalized';
  }

  String recentSearchesScopeKey(String userScope) {
    final normalized = userScope.trim().isEmpty ? 'guest' : userScope.trim();
    return '$_recentSearchesKey::$normalized';
  }

  Future<void> writeSecure(String key, String value) async {
    await secureStorage.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) async {
    return secureStorage.read(key: key);
  }

  Future<void> deleteSecure(String key) async {
    await secureStorage.delete(key: key);
  }

  Future<void> saveToken(String token) async {
    await secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await secureStorage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await secureStorage.delete(key: _tokenKey);
  }

  Future<void> saveUserId(String userId) async {
    await secureStorage.write(key: _userIdKey, value: userId);
  }

  Future<String?> getUserId() async {
    return secureStorage.read(key: _userIdKey);
  }

  Future<void> deleteUserId() async {
    await secureStorage.delete(key: _userIdKey);
  }

  Future<void> saveUser(UserModel user) async {
    await secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final raw = await secureStorage.read(key: _userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser() async {
    await secureStorage.delete(key: _userKey);
  }

  Future<void> clearAuth() async {
    await Future.wait([deleteToken(), deleteUserId(), deleteUser()]);
  }

  Future<void> saveSessionMetadata(Map<String, dynamic> payload) async {
    await sessionBox.put(_sessionMetaKey, jsonEncode(payload));
  }

  Map<String, dynamic>? getSessionMetadata() {
    final raw = sessionBox.get(_sessionMetaKey);
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSessionMetadata() async {
    await sessionBox.delete(_sessionMetaKey);
  }

  Future<void> saveDeviceToken(String token) async {
    await secureStorage.write(key: _deviceTokenKey, value: token);
  }

  Future<String?> getDeviceToken() async {
    return secureStorage.read(key: _deviceTokenKey);
  }

  Future<void> deleteDeviceToken() async {
    await secureStorage.delete(key: _deviceTokenKey);
  }

  List<int> getSavedProductIds(String userScope) {
    final values = sharedPreferences.getStringList(
      '$_savedProductsPrefix$userScope',
    );
    if (values == null) return <int>[];
    return values.map((e) => int.tryParse(e)).whereType<int>().toSet().toList();
  }

  Future<void> saveSavedProductIds(String userScope, List<int> ids) async {
    final normalized = ids.toSet().toList()..sort();
    await sharedPreferences.setStringList(
      '$_savedProductsPrefix$userScope',
      normalized.map((e) => e.toString()).toList(),
    );
  }

  Future<void> saveLastRouteState(Map<String, dynamic> payload) async {
    await sharedPreferences.setString(_lastRouteKey, jsonEncode(payload));
  }

  Map<String, dynamic>? getLastRouteState() {
    final raw = sharedPreferences.getString(_lastRouteKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastRouteState() async {
    await sharedPreferences.remove(_lastRouteKey);
  }

  List<String> getRecentSearches({int limit = 5, String userScope = 'guest'}) {
    final scopeKey = recentSearchesScopeKey(userScope);
    final List<dynamic> raw =
        (recentSearchesBox.get(scopeKey) as List?) ?? <dynamic>[];
    final normalized = raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (limit <= 0 || normalized.length <= limit) {
      return normalized;
    }

    return normalized.take(limit).toList();
  }

  Future<void> saveRecentSearch(
    String term, {
    int maxItems = 5,
    String userScope = 'guest',
  }) async {
    final normalized = term.trim();
    if (normalized.isEmpty) {
      return;
    }

    final next = getRecentSearches(limit: maxItems * 2, userScope: userScope)
      ..removeWhere((e) => e.toLowerCase() == normalized.toLowerCase())
      ..insert(0, normalized);

    if (next.length > maxItems) {
      next.removeRange(maxItems, next.length);
    }

    await recentSearchesBox.put(recentSearchesScopeKey(userScope), next);
  }

  Future<void> removeRecentSearch(
    String term, {
    String userScope = 'guest',
  }) async {
    final normalized = term.trim();
    if (normalized.isEmpty) {
      return;
    }

    final next = getRecentSearches(limit: 20, userScope: userScope)
      ..removeWhere((e) => e.toLowerCase() == normalized.toLowerCase());
    await recentSearchesBox.put(recentSearchesScopeKey(userScope), next);
  }

  Future<void> clearRecentSearches({String userScope = 'guest'}) async {
    await recentSearchesBox.delete(recentSearchesScopeKey(userScope));
  }

  Map<String, dynamic> getAppLockSettings(String userScope) {
    final key = 'app_lock::$userScope';
    final raw = settingsBox.get(key);
    if (raw is! String || raw.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveAppLockSettings(
    String userScope,
    Map<String, dynamic> payload,
  ) async {
    await settingsBox.put('app_lock::$userScope', jsonEncode(payload));
  }

  Future<void> saveSyncMeta(String key, Map<String, dynamic> payload) async {
    await syncMetaBox.put(key, jsonEncode(payload));
  }

  Map<String, dynamic>? readSyncMeta(String key) {
    final raw = syncMetaBox.get(key);
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // --- Hive Accessors ---

  Box get dbMetaBox => Hive.box(dbMetaBoxName);
  Box get cartBox => Hive.box(cartBoxName);
  Box get behaviorBox => Hive.box(behaviorBoxName);
  Box get settingsBox => Hive.box(settingsBoxName);
  Box get recentSearchesBox => Hive.box(recentSearchesBoxName);
  Box get sessionBox => Hive.box(sessionBoxName);
  Box get catalogBox => Hive.box(catalogBoxName);
  Box get ordersBox => Hive.box(ordersBoxName);
  Box get syncQueueBox => Hive.box(syncQueueBoxName);
  Box get syncMetaBox => Hive.box(syncMetaBoxName);
  Box get searchIndexBox => Hive.box(searchIndexBoxName);
}
