import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/notification_Entity.dart';
import '../repository/notification_repository.dart';

final notificationRepositoryProvider =
Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationProvider =
NotifierProvider<NotificationNotifier, List<NotificationEntity>>(
  NotificationNotifier.new,
);

class NotificationNotifier extends Notifier<List<NotificationEntity>> {
  late NotificationRepository _repository;

  @override
  List<NotificationEntity> build() {
    _repository = ref.read(notificationRepositoryProvider);

    final subscription = _repository.watchNotifications().listen(
          (notifications) {
        state = notifications;
      },
      onError: (error) {
        print('Notification stream error: $error');
      },
    );

    ref.onDispose(subscription.cancel);

    return [];
  }

  Future<void> addNotification(NotificationEntity notification) {
    return _repository.addNotification(notification);
  }

  Future<void> markAsRead(int id) {
    return _repository.markAsRead(id);
  }

  Future<void> markAllAsRead() {
    return _repository.markAllAsRead(state);
  }

  Future<void> deleteNotifications(Set<int> ids) {
    return _repository.deleteNotifications(ids);
  }

  Future<void> clearNotifications() {
    return _repository.clearNotifications(state);
  }

  int get unreadCount =>
      state.where((notification) => !notification.isRead).length;
}