import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lpco_llc/core/network/api_contract.dart';
import 'package:lpco_llc/features/notifications/data/models/app_notification_model.dart';
import 'package:lpco_llc/features/notifications/data/repositories/notifications_repository.dart';

abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<AppNotificationModel> notifications;
  final int unreadCount;

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
  });
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);
}

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;

  NotificationsCubit({NotificationsRepository? repository})
    : _repository = repository ?? NotificationsRepository(),
      super(const NotificationsInitial());

  Future<void> load() async {
    emit(const NotificationsLoading());
    try {
      final notifications = await _repository.getNotifications();
      int unread;
      try {
        unread = await _repository.getUnreadCount();
      } catch (_) {
        unread = notifications.where((n) => !n.isRead).length;
      }
      emit(
        NotificationsLoaded(notifications: notifications, unreadCount: unread),
      );
    } catch (e) {
      emit(NotificationsError(ApiContract.safeMessageFromException(e)));
    }
  }

  Future<void> markAsRead(int id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final next = current.notifications
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    emit(
      NotificationsLoaded(
        notifications: next,
        unreadCount: next.where((n) => !n.isRead).length,
      ),
    );

    try {
      await _repository.markRead(id);
    } catch (_) {}
  }

  Future<void> markAsUnread(int id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final previous = current;
    final next = current.notifications
        .map((n) => n.id == id ? n.copyWith(isRead: false) : n)
        .toList();
    emit(
      NotificationsLoaded(
        notifications: next,
        unreadCount: next.where((n) => !n.isRead).length,
      ),
    );

    try {
      await _repository.markUnread(id);
    } catch (_) {
      emit(previous);
    }
  }

  Future<void> toggleRead(int id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    AppNotificationModel? target;
    for (final notification in current.notifications) {
      if (notification.id == id) {
        target = notification;
        break;
      }
    }
    if (target == null) return;

    if (target.isRead) {
      await markAsUnread(id);
      return;
    }
    await markAsRead(id);
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final next = current.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    emit(NotificationsLoaded(notifications: next, unreadCount: 0));

    try {
      await _repository.markAllRead();
    } catch (_) {}
  }

  Future<void> deleteOne(int id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    final next = current.notifications.where((n) => n.id != id).toList();
    emit(
      NotificationsLoaded(
        notifications: next,
        unreadCount: next.where((n) => !n.isRead).length,
      ),
    );

    try {
      await _repository.deleteNotification(id);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    emit(
      const NotificationsLoaded(
        notifications: <AppNotificationModel>[],
        unreadCount: 0,
      ),
    );
    try {
      await _repository.deleteAll();
    } catch (_) {}
  }
}
