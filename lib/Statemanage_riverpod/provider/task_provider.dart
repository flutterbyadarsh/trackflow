
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/task_entity.dart';
import '../auth services/notification_service.dart';
import '../repository/task_repository.dart';
import '../repository/notification_repository.dart';
import 'notification_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final taskProvider = NotifierProvider<TaskNotifier, List<TaskEntity>>(
  TaskNotifier.new,
);

class TaskNotifier extends Notifier<List<TaskEntity>>
    with WidgetsBindingObserver {
  late TaskRepository _repository;
  late NotificationRepository _notificationRepository;

  bool _hasLoadedTasks = false;
  bool _isAccountDeleting = false;

  int _activeOperations = 0;
  Completer<void>? _operationsFinished;

  bool get hasLoadedTasks => _hasLoadedTasks;

  StreamSubscription<List<TaskEntity>>? _taskSubscription;

  StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  @override
  List<TaskEntity> build() {
    _repository = ref.read(taskRepositoryProvider);
    _notificationRepository = ref.read(notificationRepositoryProvider);

    WidgetsBinding.instance.addObserver(this);

    _startConnectivityListener();
    _startTaskListener();

    // App start par pending tasks sync karo.
    unawaited(
      _trackOperation(() async {
        if (_isAccountDeleting) return;
        await _repository.syncPendingTasks();
      }).catchError((error) {
        debugPrint('Initial task sync error: $error');
      }),
    );
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);

      _taskSubscription?.cancel();
      _connectivitySubscription?.cancel();
    });

    return [];
  }

  // -----------------------------------------
  // TASK STREAM
  // -----------------------------------------

  void _startTaskListener() {
    if (_isAccountDeleting) return;

    _taskSubscription = _repository.watchTasks().listen(
          (tasks) {
        if (_isAccountDeleting) return;

        state = tasks;
        _hasLoadedTasks = true;

        unawaited(
          _trackOperation(() => _syncNotificationsSafely()),
        );
      },
      onError: (error) {
        debugPrint('Task stream error: $error');
      },
    );
  }

  // -----------------------------------------
  // CONNECTIVITY LISTENER
  // -----------------------------------------

  void _startConnectivityListener() {
    if (_isAccountDeleting) return;

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
          if (_isAccountDeleting) return;

          if (results.any((result) => result != ConnectivityResult.none)) {
            _repository.syncPendingTasks().catchError((error) {
              debugPrint('Task reconnect sync error: $error');
            });
          }
        });
  }

  // tracking helper
  Future<void> _trackOperation(
      Future<void> Function() operation,
      ) async {
    _activeOperations++;

    _operationsFinished ??= Completer<void>();

    try {
      await operation();
    } finally {
      _activeOperations--;

      if (_activeOperations == 0) {
        if (!(_operationsFinished?.isCompleted ?? true)) {
          _operationsFinished!.complete();
        }

        _operationsFinished = null;
      }
    }
  }

  // -----------------------------------------
  // ACCOUNT DELETION PAUSE / RESUME
  // -----------------------------------------

  Future<void> pauseForAccountDeletion() async {
    if (_isAccountDeleting) return;

    // Block new operations first.
    _isAccountDeleting = true;

    // Stop repository writes and sync.
    await _repository.pauseSyncAndWait();

    // Wait for already-running notification operations.
    final activeOperations = _operationsFinished?.future;

    if (activeOperations != null) {
      await activeOperations;
    }

    // Stop task stream.
    await _taskSubscription?.cancel();
    _taskSubscription = null;

    // Stop connectivity listener.
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // Stop lifecycle observer.
    WidgetsBinding.instance.removeObserver(this);

    debugPrint('Task operations safely paused');
  }

  // -----------------------------------------
  // APP LIFECYCLE
  // -----------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (_isAccountDeleting) return;

    if (lifecycleState == AppLifecycleState.resumed) {
      _repository.syncPendingTasks().catchError((error) {
        debugPrint('Task resume sync error: $error');
      });
    }
  }

  // -----------------------------------------
  // NOTIFICATION IDS
  // -----------------------------------------

  int _getNotificationBaseId(String taskId) {
    int hash = 0;

    for (final code in taskId.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }

    return (hash % 1000000000) * 2;
  }

  int _taskReminderId(String taskId) {
    return _getNotificationBaseId(taskId) + 1;
  }

  int _upcomingReminderId(String taskId) {
    return _getNotificationBaseId(taskId) + 2;
  }

  // -----------------------------------------
  // TASK DATE / TIME
  // -----------------------------------------

  DateTime? _getTaskDateTime(TaskEntity task) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(task.time.trim());

    if (match == null) {
      debugPrint('Unsupported task time format: ${task.time}');
      return null;
    }

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();

    if (minute < 0 || minute > 59) return null;

    if (period != null) {
      if (hour < 1 || hour > 12) return null;

      if (period == 'AM') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
    } else if (hour < 0 || hour > 23) {
      return null;
    }

    return DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
      hour,
      minute,
    );
  }

  // -----------------------------------------
  // CANCEL TASK NOTIFICATIONS
  // -----------------------------------------

  Future<void> _cancelTaskNotifications(String taskId) async {
    try {
      await NotificationService.cancelTaskNotifications(
        taskReminderId: _taskReminderId(taskId),
        upcomingReminderId: _upcomingReminderId(taskId),
      );
    } catch (error) {
      debugPrint('Cancel task notifications error: $error');
    }
  }

  // -----------------------------------------
  // SCHEDULE TASK NOTIFICATIONS
  // -----------------------------------------

  Future<void> _scheduleTaskNotifications(TaskEntity task) async {
    if (_isAccountDeleting) return;

    await _cancelTaskNotifications(task.id);

    // Deletion may have started while cancellation was running.
    if (_isAccountDeleting) return;

    if (task.isCompleted) return;

    final taskDateTime = _getTaskDateTime(task);
    if (taskDateTime == null) return;

    try {
      if (task.reminderEnable) {
        final reminderDateTime = taskDateTime.subtract(
          Duration(minutes: task.reminderMinutesBefore),
        );

        if (_isAccountDeleting) return;

        await NotificationService.scheduleTaskReminder(
          id: _taskReminderId(task.id),
          title: task.title,
          reminderDateTime: reminderDateTime,
          notificationTitle: 'Task Reminder',
          notificationBody: '${task.title} is scheduled soon.',
        );
      }

      if (task.upcomingReminderEnabled && !_isAccountDeleting) {
        final upcomingDateTime = taskDateTime.subtract(
          Duration(minutes: task.upcomingReminderMinutesBefore),
        );

        await NotificationService.scheduleTaskReminder(
          id: _upcomingReminderId(task.id),
          title: task.title,
          reminderDateTime: upcomingDateTime,
          notificationTitle: 'Upcoming Task',
          notificationBody: '${task.title} is coming up.',
        );
      }
    } catch (error) {
      debugPrint('Schedule task notifications error: $error');
    }
  }

  // -----------------------------------------
  // IN-APP NOTIFICATION SYNC
  // -----------------------------------------

  Future<void> syncDueInAppNotifications() async {
    if (_isAccountDeleting) return;

    final now = DateTime.now();

    for (final task in state) {
      if (_isAccountDeleting) return;

      if (task.isCompleted) continue;

      final taskDateTime = _getTaskDateTime(task);
      if (taskDateTime == null) continue;

      // Ignore tasks that ended more than 24 hours ago.
      if (now.isAfter(taskDateTime.add(const Duration(hours: 24)))) {
        continue;
      }

      if (task.reminderEnable) {
        final reminderAt = taskDateTime.subtract(
          Duration(minutes: task.reminderMinutesBefore),
        );

        if (!reminderAt.isAfter(now)) {
          if (_isAccountDeleting) return;

          await _notificationRepository.createReminderIfMissing(
            id: _taskReminderId(task.id),
            type: 'task_reminder',
            title: task.title,
            message: 'Your task reminder is due now.',
            createdAt: reminderAt,
          );
        }
      }

      if (task.upcomingReminderEnabled) {
        final upcomingAt = taskDateTime.subtract(
          Duration(minutes: task.upcomingReminderMinutesBefore),
        );

        if (!upcomingAt.isAfter(now)) {
          if (_isAccountDeleting) return;

          await _notificationRepository.createReminderIfMissing(
            id: _upcomingReminderId(task.id),
            type: 'upcoming_task',
            title: task.title,
            message: 'Your task is coming up soon',
            createdAt: upcomingAt,
          );
        }
      }
    }
  }

  Future<void> _syncNotificationsSafely() async {
    if (_isAccountDeleting) return;

    try {
      await syncDueInAppNotifications();
    } catch (error) {
      debugPrint('In-app notification sync error: $error');
    }
  }

  // -----------------------------------------
  // ADD TASK
  // -----------------------------------------

  Future<void> addTask(TaskEntity task) async {
    if (_isAccountDeleting) return;

    await _trackOperation(() async {
      await _repository.addTask(task);
    });

    if (_isAccountDeleting) return;

    state = [
      task,
      ...state.where((item) => item.id != task.id),
    ];

    unawaited(
      _trackOperation(() => _scheduleTaskNotifications(task)),
    );

    unawaited(
      _trackOperation(() => _syncNotificationsSafely()),
    );
  }

  // -----------------------------------------
  // UPDATE TASK
  // -----------------------------------------

  Future<void> updateTask(TaskEntity task) async {
    if (_isAccountDeleting) return;

    await _trackOperation(() async {
      await _repository.updateTask(task);
    });

    if (_isAccountDeleting) return;

    state = [
      for (final item in state)
        if (item.id == task.id) task else item,
    ];

    unawaited(
      _trackOperation(() => _scheduleTaskNotifications(task)),
    );

    unawaited(
      _trackOperation(() => _syncNotificationsSafely()),
    );
  }

  // -----------------------------------------
  // DELETE TASK
  // -----------------------------------------

  Future<void> deleteTask(String id) async {
    if (_isAccountDeleting) return;

    await _trackOperation(() async {
      await _repository.deleteTask(id);
    });

    if (_isAccountDeleting) return;

    state = state.where((task) => task.id != id).toList();

    await _trackOperation(
          () => _cancelTaskNotifications(id),
    );
  }

  // -----------------------------------------
  // TOGGLE TASK COMPLETION
  // -----------------------------------------

  Future<void> toggleTaskCompletion(String id) async {
    if (_isAccountDeleting) return;

    final index = state.indexWhere((task) => task.id == id);
    if (index == -1) return;

    final task = state[index];

    final updatedTask = TaskEntity(
      id: task.id,
      title: task.title,
      category: task.category,
      categoryColor: task.categoryColor,
      categoryBackgroundColor: task.categoryBackgroundColor,
      categoryIcon: task.categoryIcon,
      scheduledDate: task.scheduledDate,
      time: task.time,
      priority: task.priority,
      reminderEnable: task.reminderEnable,
      reminderMinutesBefore: task.reminderMinutesBefore,
      reminderTime: task.reminderTime,
      upcomingReminderEnabled: task.upcomingReminderEnabled,
      upcomingReminderMinutesBefore:
      task.upcomingReminderMinutesBefore,
      repeat: task.repeat,
      notes: task.notes,
      isCompleted: !task.isCompleted,
      pdfName: task.pdfName,
      pdfPath: task.pdfPath,
      folderId: task.folderId,
      folderName: task.folderName,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );

    await _trackOperation(() async {
      await _repository.updateTask(updatedTask);
    });

    if (_isAccountDeleting) return;

    state = [
      for (final item in state)
        if (item.id == id) updatedTask else item,
    ];

    await _trackOperation(
          () => _scheduleTaskNotifications(updatedTask),
    );

    if (!updatedTask.isCompleted && !_isAccountDeleting) {
      await _trackOperation(
            () => _syncNotificationsSafely(),
      );
    }
  }
}
