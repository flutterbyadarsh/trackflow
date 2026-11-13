import 'package:cloud_firestore/cloud_firestore.dart';

class TaskEntity {
  final String id;
  final String title;
  final String category;
  final int categoryColor;
  final int categoryBackgroundColor;
  final int categoryIcon;
  final DateTime scheduledDate;
  final String time;
  final String priority;

  // Task Reminder settings
  final bool reminderEnable;
  final int reminderMinutesBefore;
  final String reminderTime;

  // Upcoming Task settings
  final bool upcomingReminderEnabled;
  final int upcomingReminderMinutesBefore;

  final String repeat;
  final String? notes;
  final bool isCompleted;
  final String? pdfName;
  final String? pdfPath;
  final String? folderId;
  final String? folderName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.categoryBackgroundColor,
    required this.categoryIcon,
    required this.scheduledDate,
    required this.time,
    required this.priority,

    // Task Reminder defaults
    this.reminderEnable = true,
    this.reminderMinutesBefore = 10,
    this.reminderTime = '10 minutes before',

    // Upcoming Task defaults
    this.upcomingReminderEnabled = true,
    this.upcomingReminderMinutesBefore = 5,

    this.repeat = 'Never',
    this.notes,
    this.isCompleted = false,
    this.pdfName,
    this.pdfPath,
    this.folderId,
    this.folderName,
    this.createdAt,
    this.updatedAt,
  });

  // adding

  TaskEntity copyWith({
    DateTime? scheduledDate,
    String? time,
    DateTime? updatedAt,
  }) {
    return TaskEntity(
      id: id,
      title: title,
      category: category,
      categoryColor: categoryColor,
      categoryBackgroundColor: categoryBackgroundColor,
      categoryIcon: categoryIcon,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      time: time ?? this.time,
      priority: priority,
      reminderEnable: reminderEnable,
      reminderMinutesBefore: reminderMinutesBefore,
      reminderTime: reminderTime,
      upcomingReminderEnabled: upcomingReminderEnabled,
      upcomingReminderMinutesBefore:
      upcomingReminderMinutesBefore,
      repeat: repeat,
      notes: notes,
      isCompleted: isCompleted,
      pdfName: pdfName,
      pdfPath: pdfPath,
      folderId: folderId,
      folderName: folderName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }


  // Convert TaskEntity into Firestore-compatible Map.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'categoryColor': categoryColor,
      'categoryBackgroundColor': categoryBackgroundColor,
      'categoryIcon': categoryIcon,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'time': time,
      'priority': priority,

      // Task Reminder
      'reminderEnable': reminderEnable,
      'reminderMinutesBefore': reminderMinutesBefore,
      'reminderTime': reminderTime,

      // Upcoming Task
      'upcomingReminderEnabled': upcomingReminderEnabled,
      'upcomingReminderMinutesBefore':
      upcomingReminderMinutesBefore,

      'repeat': repeat,
      'notes': notes,
      'isCompleted': isCompleted,
      'pdfName': pdfName,
      'pdfPath': pdfPath,
      'folderId': folderId,
      'folderName': folderName,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Safely convert Firestore date values into DateTime.
  static DateTime _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }

  // Convert Firestore Map into TaskEntity.
  factory TaskEntity.fromMap(
      Map<String, dynamic> map,
      String documentId,
      ) {
    return TaskEntity(
      id: documentId,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      categoryColor:
      (map['categoryColor'] as num?)?.toInt() ?? 0,
      categoryBackgroundColor:
      (map['categoryBackgroundColor'] as num?)?.toInt() ?? 0,
      categoryIcon:
      (map['categoryIcon'] as num?)?.toInt() ?? 0,
      scheduledDate: _getDateTime(map['scheduledDate']),
      time: map['time'] as String? ?? '',
      priority: map['priority'] as String? ?? 'Medium',

      // Task Reminder
      reminderEnable: map['reminderEnable'] as bool? ?? true,
      reminderMinutesBefore:
      (map['reminderMinutesBefore'] as num?)?.toInt() ?? 10,
      reminderTime:
      map['reminderTime'] as String? ?? '10 minutes before',

      // Upcoming Task
      upcomingReminderEnabled:
      map['upcomingReminderEnabled'] as bool? ?? true,
      upcomingReminderMinutesBefore:
      (map['upcomingReminderMinutesBefore'] as num?)?.toInt() ?? 5,

      repeat: map['repeat'] as String? ?? 'Never',
      notes: map['notes'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      pdfName: map['pdfName'] as String?,
      pdfPath: map['pdfPath'] as String?,
      folderId: map['folderId'] as String?,
      folderName: map['folderName'] as String?,
      createdAt: map['createdAt'] == null
          ? null
          : _getDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] == null
          ? null
          : _getDateTime(map['updatedAt']),
    );
  }
}