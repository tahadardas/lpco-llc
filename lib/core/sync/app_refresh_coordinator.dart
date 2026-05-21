import 'package:flutter/foundation.dart';
import 'package:lpco_llc/core/local/catalog_local_store.dart';
import 'package:lpco_llc/core/network/dio_client.dart';
import 'package:lpco_llc/core/storage/storage_service.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';

class AppRefreshCoordinator {
  final ProductRepository _repository;
  final CatalogLocalStore _catalogLocalStore;
  final StorageService _storageService;
  final DioClient _dioClient;

  AppRefreshCoordinator({
    ProductRepository? repository,
    CatalogLocalStore? catalogLocalStore,
    StorageService? storageService,
    DioClient? dioClient,
  }) : _repository = repository ?? ProductRepository(),
       _catalogLocalStore = catalogLocalStore ?? CatalogLocalStore(),
       _storageService = storageService ?? StorageService(),
       _dioClient = dioClient ?? DioClient();

  Future<CatalogRefreshResult> refreshCatalog({
    bool forceRemote = false,
    bool guest = true,
  }) async {
    final sw = Stopwatch();
    if (forceRemote) sw.start();
    bool cacheCleared = false;
    bool revisionChanged = false;
    String? errorMessage;

    if (forceRemote) {
      try {
        revisionChanged = await _repository.syncCatalogRevision(guest: guest);
        if (revisionChanged) {
          await _catalogLocalStore.clearAllCatalogProducts();
          cacheCleared = true;
          if (kDebugMode) {
            debugPrint(
              '[REFRESH_COORDINATOR] Catalog revision changed, cleared local catalog cache',
            );
          }
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
        'revisionChanged=$revisionChanged cacheCleared=$cacheCleared',
      );
    }

    return CatalogRefreshResult(
      success: errorMessage == null,
      cacheCleared: cacheCleared,
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
    bool cacheCleared = false;
    bool revisionChanged = false;
    String? errorMessage;

    if (forceRemote) {
      try {
        revisionChanged = await _repository.syncCatalogRevision(guest: guest);
        if (revisionChanged) {
          await _catalogLocalStore.clearAllCatalogProducts();
          cacheCleared = true;
          if (kDebugMode) {
            debugPrint(
              '[REFRESH_COORDINATOR] Catalog revision changed on scope refresh, cleared cache',
            );
          }
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
        'revisionChanged=$revisionChanged cacheCleared=$cacheCleared',
      );
    }

    return CatalogRefreshResult(
      success: errorMessage == null,
      cacheCleared: cacheCleared,
      revisionChanged: revisionChanged,
      errorMessage: errorMessage,
      durationMs: durationMs,
    );
  }

  Future<void> clearCatalogCache() async {
    await _catalogLocalStore.clearAllCatalogProducts();
    const metaKey = 'catalog_revision::global';
    await _storageService.saveSyncMeta(metaKey, <String, dynamic>{});
    if (kDebugMode) {
      debugPrint('[REFRESH_COORDINATOR] Catalog cache cleared manually');
    }
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
  final bool cacheCleared;
  final bool revisionChanged;
  final String? errorMessage;
  final int? durationMs;

  const CatalogRefreshResult({
    required this.success,
    this.cacheCleared = false,
    this.revisionChanged = false,
    this.errorMessage,
    this.durationMs,
  });
}
