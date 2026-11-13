
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    timezone_data.initializeTimeZones();

    try {
      final timezoneInfo =
      await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(timezoneInfo.identifier),
      );
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('Timezone error: $e');
    }

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    debugPrint('Notification service initialized');
    debugPrint('Timezone: ${tz.local.name}');
  }

  // --------------------------------------------------
  // Schedule notification
  // --------------------------------------------------

  static Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required DateTime reminderDateTime,
    String notificationTitle = 'Task Reminder',
    String? notificationBody,
  }) async {
    if (!reminderDateTime.isAfter(DateTime.now())) {
      debugPrint('Reminder time already passed: $id');
      return;
    }

    final scheduledDate = tz.TZDateTime.from(
      reminderDateTime,
      tz.local,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trackflow_task_reminders',
        'Task Reminders',
        channelDescription: 'TrackFlow task notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: notificationTitle,
      body: notificationBody ?? 'Upcoming task: $title',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode:
      AndroidScheduleMode.inexactAllowWhileIdle,
    );

    debugPrint('Notification scheduled: $id at $scheduledDate');
  }

  // --------------------------------------------------
  // Cancel notification
  // --------------------------------------------------

  static Future<void> cancelReminder(int id) async {
    try {
      await _plugin.cancel(id: id);
      debugPrint('Notification cancelled: $id');
    } catch (e) {
      debugPrint('Notification cancellation error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------
  // Cancel both task notifications
  // --------------------------------------------------

  static Future<void> cancelTaskNotifications({
    required int taskReminderId,
    required int upcomingReminderId,
  }) async {
    await cancelReminder(taskReminderId);
    await cancelReminder(upcomingReminderId);
  }

  // --------------------------------------------------
// Cancel all app notifications (Account Deletion)
// --------------------------------------------------

  static Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
      debugPrint('All TrackFlow notifications cancelled');
    } catch (e) {
      debugPrint('Cancel all notifications error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------
  // Pending notifications
  // --------------------------------------------------

  static Future<List<PendingNotificationRequest>>
  getPendingReminders() async {
    return _plugin.pendingNotificationRequests();
  }

  // --------------------------------------------------
  // Test notification
  // --------------------------------------------------

  static Future<void> showTestNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trackflow_test_channel',
        'TrackFlow Test Notifications',
        channelDescription: 'Testing TrackFlow notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: 1,
      title: 'TrackFlow',
      body: 'Test notification is working!',
      notificationDetails: details,
    );
  }

  static Future<void> testScheduledNotification() async {
    final scheduledDate =
    tz.TZDateTime.now(tz.local).add(
      const Duration(minutes: 2),
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trackflow_test_channel',
        'TrackFlow Test Notifications',
        channelDescription: 'Testing scheduled notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id: 9999,
      title: 'TrackFlow Test',
      body: 'Scheduled notification is working!',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode:
      AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
