import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/core/sync/sync_coordinator.dart';
import 'package:lpco_llc/features/orders/data/models/order_model.dart';
import 'package:lpco_llc/features/orders/data/repositories/order_repository.dart';

abstract class OrdersState {
  const OrdersState();
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  final List<OrderModel> orders;

  const OrdersLoaded(this.orders);
}

class OrdersError extends OrdersState {
  final String message;

  const OrdersError(this.message);
}

class OrdersCubit extends Cubit<OrdersState> {
  final OrderRepository _repository;

  OrdersCubit({OrderRepository? repository})
    : _repository = repository ?? OrderRepository(),
      super(const OrdersInitial());

  Future<void> loadOrders() async {
    if (isClosed) return;

    var hasLocalData = false;
    try {
      final cached = await _repository.getCachedOrders();
      if (cached.isNotEmpty) {
        hasLocalData = true;
        emit(OrdersLoaded(cached));
      }
    } catch (_) {}

    // Only show loading if we have absolutely no data to show
    if (!hasLocalData) {
      emit(const OrdersLoading());
    }

    try {
      final orders = await _repository.getOrders(preferLocal: false);
      if (!isClosed) emit(OrdersLoaded(orders));
    } catch (e) {
      if (hasLocalData) {
        // We already have some data, just keep it
        return;
      }
      if (!isClosed) {
        emit(OrdersError(ApiContract.safeMessageFromException(e)));
      }
    }
  }

  Future<void> retryOrder(OrderModel order) async {
    await _repository.retryFailedOrder(order);
    await SyncCoordinator().triggerSync();
    await loadOrders();
  }
}
