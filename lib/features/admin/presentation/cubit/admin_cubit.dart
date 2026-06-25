import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/admin/data/models/admin_models.dart';
import 'package:lpco_llc/features/admin/data/repositories/admin_repository.dart';
import 'package:lpco_llc/features/admin/domain/admin_module.dart';

sealed class AdminState {
  const AdminState();
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminLoaded extends AdminState {
  final List<AdminModule> modules;
  final AdminDashboardModel dashboard;
  final AdminDiagnosticsModel diagnostics;

  const AdminLoaded({
    required this.modules,
    required this.dashboard,
    required this.diagnostics,
  });
}

class AdminError extends AdminState {
  final String message;

  const AdminError(this.message);
}

class AdminCubit extends Cubit<AdminState> {
  AdminCubit({AdminRepository? repository})
    : _repository = repository ?? AdminRepository(),
      super(const AdminInitial());

  final AdminRepository _repository;

  Future<void> fetchDashboard({bool forceRefresh = false}) async {
    emit(const AdminLoading());

    final warnings = <String>[];
    AdminDiscoveryResult discovery;

    try {
      discovery = await _repository.discoverModules(forceRefresh: forceRefresh);
    } catch (error) {
      final detail = _extractErrorDetail('capabilities', error);
      debugPrint('[AdminCubit] discoverModules failed: $detail');
      if (_isAuthorizationFailure(error)) {
        emit(AdminError(detail));
        return;
      }
      warnings.add('تعذر تحميل صلاحيات الإدارة: $detail');
      discovery = AdminDiscoveryResult(
        modules: _fallbackModules(),
        discoveredAt: DateTime.now(),
      );
    }

    if (discovery.modules.isEmpty) {
      warnings.add(
        'لم يرجع الخادم قائمة وحدات الإدارة، تم استخدام قائمة احتياطية.',
      );
      discovery = AdminDiscoveryResult(
        modules: _fallbackModules(),
        discoveredAt: discovery.discoveredAt,
      );
    }

    final results = await Future.wait<Object>([
      _repository
          .fetchDiagnostics(forceRefresh: forceRefresh)
          .then<Object>((diagnostics) => diagnostics)
          .catchError((Object error) {
            final detail = _extractErrorDetail('diagnostics', error);
            debugPrint('[AdminCubit] fetchDiagnostics failed: $detail');
            warnings.add('تعذر تحميل التشخيصات: $detail');
            return const AdminDiagnosticsModel(
              generatedAt: '',
              sections: <AdminDiagnosticSectionModel>[],
              warnings: <String>[],
              latestNotifications: <AdminNotificationHistoryModel>[],
            );
          }),
      _repository
          .fetchDashboard(forceRefresh: forceRefresh)
          .then<Object>((dashboard) => dashboard)
          .catchError((Object error) {
            final detail = _extractErrorDetail('stats', error);
            debugPrint('[AdminCubit] fetchDashboard stats failed: $detail');
            if (_isAuthorizationFailure(error)) {
              return AdminError(detail);
            }
            warnings.add('تعذر تحميل الإحصاءات: $detail');
            return _emptyDashboard();
          }),
    ], eagerError: false);

    final diagnostics = results[0] is AdminDiagnosticsModel
        ? results[0] as AdminDiagnosticsModel
        : _emptyDiagnostics();
    final dashboardResult = results[1];

    if (dashboardResult is AdminError) {
      emit(AdminError(dashboardResult.message));
      return;
    }

    final dashboard = dashboardResult is AdminDashboardModel
        ? _dashboardWithWarnings(dashboardResult, warnings)
        : _dashboardWithWarnings(_emptyDashboard(), warnings);

    emit(
      AdminLoaded(
        modules: discovery.modules,
        dashboard: dashboard,
        diagnostics: diagnostics,
      ),
    );
  }

  List<AdminModule> _fallbackModules() {
    return kAdminModuleDefinitions
        .map((module) {
          if (module.kind == AdminModuleKind.stats ||
              module.kind == AdminModuleKind.diagnostics) {
            return module.copyWith(
              support: AdminModuleSupport.readOnly,
              canRead: true,
              canWrite: false,
              gapMessage: 'تم تفعيل الوحدة من القائمة الاحتياطية.',
            );
          }
          return module.copyWith(
            support: AdminModuleSupport.partial,
            canRead: true,
            canWrite: true,
            gapMessage: 'تعذر تحميل صلاحيات هذه الوحدة من الخادم.',
          );
        })
        .toList(growable: false);
  }

  AdminDiagnosticsModel _emptyDiagnostics() {
    return const AdminDiagnosticsModel(
      generatedAt: '',
      sections: <AdminDiagnosticSectionModel>[],
      warnings: <String>[],
      latestNotifications: <AdminNotificationHistoryModel>[],
    );
  }

  AdminDashboardModel _emptyDashboard() {
    return const AdminDashboardModel(
      ordersToday: 0,
      ordersMonth: 0,
      revenueMonth: 0,
      totalMembers: 0,
      pendingOrders: 0,
      completedOrders: 0,
      unreadNotificationsCount: 0,
      deviceTokensCount: 0,
      lowStockProductsCount: 0,
      latestOrders: <AdminOrderSummaryModel>[],
      latestMembers: <AdminMemberModel>[],
      latestNotifications: <AdminNotificationHistoryModel>[],
      warnings: <String>[],
    );
  }

  AdminDashboardModel _dashboardWithWarnings(
    AdminDashboardModel dashboard,
    List<String> warnings,
  ) {
    final mergedWarnings = <String>{
      ...dashboard.warnings,
      ...warnings.where((warning) => warning.trim().isNotEmpty),
    }.toList(growable: false);

    return AdminDashboardModel(
      ordersToday: dashboard.ordersToday,
      ordersMonth: dashboard.ordersMonth,
      revenueMonth: dashboard.revenueMonth,
      totalMembers: dashboard.totalMembers,
      pendingOrders: dashboard.pendingOrders,
      completedOrders: dashboard.completedOrders,
      unreadNotificationsCount: dashboard.unreadNotificationsCount,
      deviceTokensCount: dashboard.deviceTokensCount,
      lowStockProductsCount: dashboard.lowStockProductsCount,
      latestOrders: dashboard.latestOrders,
      latestMembers: dashboard.latestMembers,
      latestNotifications: dashboard.latestNotifications,
      warnings: mergedWarnings,
    );
  }

  bool _isAuthorizationFailure(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode ?? 0;
      return statusCode == 401 || statusCode == 403;
    }
    return false;
  }

  /// Returns a safe admin error detail without leaking raw backend internals.
  String _extractErrorDetail(String endpoint, Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode ?? 0;
      final body = error.response?.data;
      final bodyText = body == null ? '' : '$body'.trim();
      final looksHtml =
          bodyText.startsWith('<') ||
          bodyText.toLowerCase().contains('<!doctype') ||
          bodyText.toLowerCase().contains('<html');

      final message = switch (statusCode) {
        401 => 'جلسة الإدارة غير صالحة، يرجى تسجيل الدخول مرة أخرى.',
        403 => 'هذا الحساب لا يملك صلاحية إدارة لوحة التحكم.',
        >= 500 => 'خطأ في خادم WordPress، تحقق من سجل الأخطاء.',
        _ when looksHtml => 'الخادم أعاد صفحة HTML بدل استجابة JSON.',
        _ => ApiContract.safeMessageFromException(
          error,
          fallback: 'تعذر تحميل البيانات حالياً. يرجى إعادة المحاولة.',
        ),
      };
      return '[$endpoint] $message';
    }

    final safeMessage = ApiContract.safeMessageFromException(
      error,
      fallback: 'تعذر تحميل البيانات حالياً. يرجى إعادة المحاولة.',
    );
    return '[$endpoint] $safeMessage';
  }
}
