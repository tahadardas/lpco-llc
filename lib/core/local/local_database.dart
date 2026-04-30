import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();

  factory LocalDatabase() => _instance;

  LocalDatabase._internal();

  final StorageService _storage = StorageService();

  Future<void> initialize() async {
    await _storage.init();
  }

  int get schemaVersion {
    final raw = _storage.dbMetaBox.get('schema_version');
    if (raw is int) {
      return raw;
    }
    return 0;
  }

  Box get catalogBox => _storage.catalogBox;
  Box get ordersBox => _storage.ordersBox;
  Box get syncQueueBox => _storage.syncQueueBox;
  Box get syncMetaBox => _storage.syncMetaBox;
  Box get searchIndexBox => _storage.searchIndexBox;

  Future<void> putJson(
    String boxKey,
    Map<String, dynamic> payload, {
    required Box box,
  }) async {
    await box.put(boxKey, jsonEncode(payload));
  }

  Map<String, dynamic>? getJsonMap(String boxKey, {required Box box}) {
    final raw = box.get(boxKey);
    if (raw is! String || raw.isEmpty) {
      return null;
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> putJsonList(
    String boxKey,
    List<Map<String, dynamic>> payload, {
    required Box box,
  }) async {
    await box.put(boxKey, jsonEncode(payload));
  }

  List<Map<String, dynamic>> getJsonList(String boxKey, {required Box box}) {
    final raw = box.get(boxKey);
    if (raw is! String || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return <Map<String, dynamic>>[];
      }

      return parsed
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
