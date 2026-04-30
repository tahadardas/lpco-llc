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

  Future<void> fetchDashboard() async {
    emit(const AdminLoading());

    try {
      // Step 1: Discover modules (Essential for navigation)
      AdminDiscoveryResult discovery;
      try {
        discovery = await _repository.discoverModules();
      } catch (e) {
        debugPrint(
          '[AdminCubit] discoverModules failed: ${_extractErrorDetail('capabilities', e)}',
        );
        discovery = AdminDiscoveryResult(
          modules: const <AdminModule>[],
          discoveredAt: DateTime.now(),
        );
      }

      // Step 2: Fetch diagnostics & stats in parallel for better performance
      final results = await Future.wait([
        _repository.fetchDiagnostics().catchError((e) {
          debugPrint('[AdminCubit] fetchDiagnostics failed: $e');
          return const AdminDiagnosticsModel(
            generatedAt: '',
            sections: <AdminDiagnosticSectionModel>[],
            warnings: <String>[],
            latestNotifications: <AdminNotificationHistoryModel>[],
          );
        }),
        _repository.fetchDashboard().catchError((e) {
          debugPrint('[AdminCubit] fetchDashboard stats failed: $e');
          throw e;
        }),
      ], eagerError: false);

      final diagnostics = results[0] as AdminDiagnosticsModel;
      final dashboard = results[1] as AdminDashboardModel;

      emit(
        AdminLoaded(
          modules: discovery.modules,
          dashboard: dashboard,
          diagnostics: diagnostics,
        ),
      );
    } catch (error) {
      final detail = _extractErrorDetail('dashboard', error);

      // Fallback: if modules load, keep admin tools accessible.
      final discovery = await _repository.discoverModules().catchError(
        (_) => AdminDiscoveryResult(
          modules: const [],
          discoveredAt: DateTime.now(),
        ),
      );

      if (discovery.modules.isNotEmpty) {
        emit(
          AdminLoaded(
            modules: discovery.modules,
            dashboard: AdminDashboardModel(
              ordersToday: 0,
              ordersMonth: 0,
              revenueMonth: 0,
              totalMembers: 0,
              pendingOrders: 0,
              completedOrders: 0,
              unreadNotificationsCount: 0,
              deviceTokensCount: 0,
              lowStockProductsCount: 0,
              latestOrders: const [],
              latestMembers: const [],
              latestNotifications: const [],
              warnings: <String>[
                'فشل تحميل الإحصائيات: $detail',
                'ملاحظة: يمكنك الاستمرار في استخدام الوحدات الأخرى أدناه.',
              ],
            ),
            diagnostics: const AdminDiagnosticsModel(
              generatedAt: '',
              sections: [],
              warnings: [],
              latestNotifications: [],
            ),
          ),
        );
      } else {
        emit(AdminError(detail));
      }
    }
  }

  /// Returns a safe admin error detail without leaking raw backend internals.
  String _extractErrorDetail(String endpoint, Object error) {
    final safeMessage = ApiContract.safeMessageFromException(
      error,
      fallback: 'تعذر تحميل البيانات حالياً. يرجى إعادة المحاولة.',
    );
    return '[$endpoint] $safeMessage';
  }
}
