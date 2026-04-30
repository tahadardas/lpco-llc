import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/features/notifications/data/repositories/notifications_repository.dart';

class NotificationsBadgeCubit extends Cubit<int> {
  final NotificationsRepository _repository;

  NotificationsBadgeCubit({NotificationsRepository? repository})
    : _repository = repository ?? NotificationsRepository(),
      super(0);

  Future<void> refresh() async {
    try {
      final unread = await _repository.getUnreadCount();
      emit(unread < 0 ? 0 : unread);
    } catch (_) {
      // Keep previous count when backend/network is temporarily unavailable.
    }
  }

  void setCount(int count) {
    emit(count < 0 ? 0 : count);
  }

  void clear() {
    emit(0);
  }
}
