import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

class AppRefreshCoordinator {
  final ProductRepository _repository;
  final DioClient _dioClient;

  AppRefreshCoordinator({
    ProductRepository? repository,
    DioClient? dioClient,
  }) : _repository = repository ?? ProductRepository(),
       _dioClient = dioClient ?? DioClient();

  Future<CatalogRefreshResult> refreshCatalog({
    bool forceRemote = false,
    bool guest = true,
  }) async {
    final sw = Stopwatch();
    if (forceRemote) sw.start();
    bool revisionChanged = false;
    String? errorMessage;

    if (forceRemote) {
      try {
        revisionChanged = await _repository.syncCatalogRevision(guest: guest);
        if (kDebugMode) {
          debugPrint(
            '[REFRESH_COORDINATOR] Catalog revision check: changed=$revisionChanged',
          );
        }
      } catch (e) {
        errorMessage = 'فحص نسخة الكتالوج: $e';
        if (kDebugMode) {
          debugPrint('[REFRESH_COORDINATOR] Catalog revision check failed: $e');
        }
      }
    }

    try {
      await Future.wait([
        _repository.getCategories(guest: guest, forceRefresh: forceRemote),
        _repository.getBrands(guest: guest, forceRefresh: forceRemote),
      ]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[REFRESH_COORDINATOR] Categories/brands refresh failed: $e',
        );
      }
    }

    sw.stop();
    final durationMs = forceRemote ? sw.elapsedMilliseconds : null;
    if (kDebugMode && forceRemote) {
      debugPrint(
        '[REFRESH_COORDINATOR] refreshCatalog completed in ${durationMs}ms '
        'revisionChanged=$revisionChanged',
      );
    }

    return CatalogRefreshResult(
      success: errorMessage == null,
      revisionChanged: revisionChanged,
      errorMessage: errorMessage,
      durationMs: durationMs,
    );
  }

  Future<CatalogRefreshResult> refreshHome({
    bool forceRemote = false,
    bool guest = true,
  }) async {
    final sw = Stopwatch();
    if (forceRemote) sw.start();
    String? errorMessage;

    try {
      await _repository.getHomeBannerData(
        guest: guest,
        forceRefresh: forceRemote,
      );
      await _repository.getHomeBannersData(
        guest: guest,
        forceRefresh: forceRemote,
      );
    } catch (e) {
      errorMessage = 'فشل تحديث الإعلانات: $e';
      if (kDebugMode) {
        debugPrint('[REFRESH_COORDINATOR] Home banners refresh failed: $e');
      }
    }

    sw.stop();
    final durationMs = forceRemote ? sw.elapsedMilliseconds : null;
    if (kDebugMode && forceRemote) {
      debugPrint(
        '[REFRESH_COORDINATOR] refreshHome completed in ${durationMs}ms',
      );
    }

    return CatalogRefreshResult(
      success: errorMessage == null,
      errorMessage: errorMessage,
      durationMs: durationMs,
    );
  }

  Future<CatalogRefreshResult> refreshCurrentScope({
    bool forceRemote = false,
    bool guest = true,
  }) async {
    final sw = Stopwatch();
    if (forceRemote) sw.start();
    bool revisionChanged = false;
    String? errorMessage;

    if (forceRemote) {
      try {
        revisionChanged = await _repository.syncCatalogRevision(guest: guest);
        if (kDebugMode) {
          debugPrint(
            '[REFRESH_COORDINATOR] Catalog revision check on scope refresh: changed=$revisionChanged',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[REFRESH_COORDINATOR] Catalog revision check on scope refresh failed: $e',
          );
        }
      }
    }

    try {
      await Future.wait([
        _repository.getCategories(guest: guest, forceRefresh: forceRemote),
        _repository.getBrands(guest: guest, forceRefresh: forceRemote),
        _repository.getHomeBannerData(
          guest: guest,
          forceRefresh: forceRemote,
        ),
        _repository.getHomeBannersData(
          guest: guest,
          forceRefresh: forceRemote,
        ),
      ]);
    } catch (e) {
      errorMessage = 'فشل تحديث البيانات: $e';
      if (kDebugMode) {
        debugPrint('[REFRESH_COORDINATOR] Full scope refresh failed: $e');
      }
    }

    sw.stop();
    final durationMs = forceRemote ? sw.elapsedMilliseconds : null;
    if (kDebugMode && forceRemote) {
      debugPrint(
        '[REFRESH_COORDINATOR] refreshCurrentScope completed in ${durationMs}ms '
        'revisionChanged=$revisionChanged',
      );
    }

    return CatalogRefreshResult(
      success: errorMessage == null,
      revisionChanged: revisionChanged,
      errorMessage: errorMessage,
      durationMs: durationMs,
    );
  }

  Future<void> clearHttpCacheIfPossible() async {
    await _dioClient.clearHttpCache();
  }

  Future<bool> checkCatalogVersionChanged({bool guest = true}) async {
    try {
      final changed = await _repository.syncCatalogRevision(guest: guest);
      if (kDebugMode) {
        debugPrint(
          '[REFRESH_COORDINATOR] Background catalog version check: changed=$changed',
        );
      }
      return changed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[REFRESH_COORDINATOR] Background catalog version check failed: $e',
        );
      }
      return false;
    }
  }
}

class CatalogRefreshResult {
  final bool success;
  final bool revisionChanged;
  final String? errorMessage;
  final int? durationMs;

  const CatalogRefreshResult({
    required this.success,
    this.revisionChanged = false,
    this.errorMessage,
    this.durationMs,
  });
}
