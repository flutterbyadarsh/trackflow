
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../data_model/task_entity.dart';

// ============================================================
// Pending Task Sync Model
// ============================================================

class PendingTaskSync {
  final int? id;
  final String userId;
  final String entityId;
  final String action;
  final String payload;

  PendingTaskSync({
    this.id,
    required this.userId,
    required this.entityId,
    required this.action,
    required this.payload,
  });

  factory PendingTaskSync.fromMap(Map<String, dynamic> map) {
    return PendingTaskSync(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      entityId: map['entityId'] as String,
      action: map['action'] as String,
      payload: map['payload'] as String,
    );
  }
}

// ============================================================
// Task Database
// ============================================================

class TaskDatabase {
  TaskDatabase._();

  static final TaskDatabase instance = TaskDatabase._();

  static Database? _database;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'trackflow_tasks.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            categoryColor INTEGER NOT NULL,
            categoryBackgroundColor INTEGER NOT NULL,
            categoryIcon INTEGER NOT NULL,
            scheduledDate TEXT NOT NULL,
            time TEXT NOT NULL,
            priority TEXT NOT NULL,
            reminderEnable INTEGER NOT NULL,
            reminderMinutesBefore INTEGER NOT NULL,
            reminderTime TEXT NOT NULL,
            upcomingReminderEnabled INTEGER NOT NULL,
            upcomingReminderMinutesBefore INTEGER NOT NULL,
            repeat TEXT NOT NULL,
            notes TEXT,
            isCompleted INTEGER NOT NULL,
            pdfName TEXT,
            pdfPath TEXT,
            folderId TEXT,
            folderName TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_task_sync (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            entityId TEXT NOT NULL,
            action TEXT NOT NULL,
            payload TEXT NOT NULL,
            UNIQUE(userId, entityId)
          )
        ''');

        await db.execute('''
          CREATE INDEX task_user_index
          ON tasks(userId)
        ''');

        await db.execute('''
          CREATE INDEX pending_task_user_index
          ON pending_task_sync(userId)
        ''');
      },
    );

    return _database!;
  }

  // ============================================================
  // Task to Local SQLite Map
  // ============================================================

  Map<String, dynamic> _taskToLocalMap(
      TaskEntity task,
      String userId,
      ) {
    return {
      'id': task.id,
      'userId': userId,
      'title': task.title,
      'category': task.category,
      'categoryColor': task.categoryColor,
      'categoryBackgroundColor': task.categoryBackgroundColor,
      'categoryIcon': task.categoryIcon,
      'scheduledDate': task.scheduledDate.toIso8601String(),
      'time': task.time,
      'priority': task.priority,
      'reminderEnable': task.reminderEnable ? 1 : 0,
      'reminderMinutesBefore': task.reminderMinutesBefore,
      'reminderTime': task.reminderTime,
      'upcomingReminderEnabled':
      task.upcomingReminderEnabled ? 1 : 0,
      'upcomingReminderMinutesBefore':
      task.upcomingReminderMinutesBefore,
      'repeat': task.repeat,
      'notes': task.notes,
      'isCompleted': task.isCompleted ? 1 : 0,
      'pdfName': task.pdfName,
      'pdfPath': task.pdfPath,
      'folderId': task.folderId,
      'folderName': task.folderName,
      'createdAt': task.createdAt?.toIso8601String(),
      'updatedAt': (task.updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  // ============================================================
  // Local Map to Task Entity
  // ============================================================

  TaskEntity _localMapToTask(Map<String, dynamic> map) {
    final convertedMap = Map<String, dynamic>.from(map);

    convertedMap['scheduledDate'] = Timestamp.fromDate(
      DateTime.parse(map['scheduledDate'] as String),
    );

    if (map['createdAt'] != null) {
      convertedMap['createdAt'] = Timestamp.fromDate(
        DateTime.parse(map['createdAt'] as String),
      );
    }

    if (map['updatedAt'] != null) {
      convertedMap['updatedAt'] = Timestamp.fromDate(
        DateTime.parse(map['updatedAt'] as String),
      );
    }

    convertedMap['reminderEnable'] =
        (map['reminderEnable'] as int) == 1;

    convertedMap['upcomingReminderEnabled'] =
        (map['upcomingReminderEnabled'] as int) == 1;

    convertedMap['isCompleted'] =
        (map['isCompleted'] as int) == 1;

    return TaskEntity.fromMap(
      convertedMap,
      map['id'] as String,
    );
  }

  // ============================================================
  // Firestore Sync Payload
  // ============================================================

  Map<String, dynamic> _taskToSyncMap(TaskEntity task) {
    return {
      'title': task.title,
      'category': task.category,
      'categoryColor': task.categoryColor,
      'categoryBackgroundColor': task.categoryBackgroundColor,
      'categoryIcon': task.categoryIcon,
      'scheduledDate': task.scheduledDate.toIso8601String(),
      'time': task.time,
      'priority': task.priority,
      'reminderEnable': task.reminderEnable,
      'reminderMinutesBefore': task.reminderMinutesBefore,
      'reminderTime': task.reminderTime,
      'upcomingReminderEnabled': task.upcomingReminderEnabled,
      'upcomingReminderMinutesBefore':
      task.upcomingReminderMinutesBefore,
      'repeat': task.repeat,
      'notes': task.notes,
      'isCompleted': task.isCompleted,
      'pdfName': task.pdfName,
      'folderId': task.folderId,
      'folderName': task.folderName,
      'createdAt':
      (task.createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Save Task Locally + Add Sync Queue
  // ============================================================

  Future<void> saveTaskAndQueue(TaskEntity task) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not logged in');

    final db = await database;

    final localMap = _taskToLocalMap(task, uid);
    final syncPayload = jsonEncode(_taskToSyncMap(task));

    await db.transaction((txn) async {
      await txn.insert(
        'tasks',
        localMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'pending_task_sync',
        {
          'userId': uid,
          'entityId': task.id,
          'action': 'upsert',
          'payload': syncPayload,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ============================================================
  // Delete Task Locally + Add Sync Queue
  // ============================================================

  Future<void> deleteTaskAndQueue(String taskId) async {
    final uid = _userId;
    if (uid == null) throw Exception('User is not logged in');

    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'tasks',
        where: 'id = ? AND userId = ?',
        whereArgs: [taskId, uid],
      );

      await txn.insert(
        'pending_task_sync',
        {
          'userId': uid,
          'entityId': taskId,
          'action': 'delete',
          'payload': '{}',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ============================================================
  // Get All Local Tasks
  // ============================================================

  Future<List<TaskEntity>> getLocalTasks() async {
    final uid = _userId;
    if (uid == null) return [];

    final db = await database;

    final result = await db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [uid],
      orderBy: 'createdAt DESC',
    );

    return result.map(_localMapToTask).toList();
  }

  // ============================================================
  // Get Pending Sync Operations
  // ============================================================

  Future<List<PendingTaskSync>> getPendingTaskSync() async {
    final uid = _userId;
    if (uid == null) return [];

    final db = await database;

    final result = await db.query(
      'pending_task_sync',
      where: 'userId = ?',
      whereArgs: [uid],
      orderBy: 'id ASC',
    );

    return result.map(PendingTaskSync.fromMap).toList();
  }

  // ============================================================
  // Remove Completed Sync Operation
  // ============================================================

  Future<void> removePendingTaskSync(int id) async {
    final db = await database;

    await db.delete(
      'pending_task_sync',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // Insert / Update Task Downloaded From Firestore
  // ============================================================
  Future<void> saveCloudTaskLocally(TaskEntity task) async {
    final uid = _userId;
    if (uid == null) return;

    final db = await database;

    await db.transaction((txn) async {
      // Check existing local task.
      final existingTask = await txn.query(
        'tasks',
        columns: ['pdfName', 'pdfPath'],
        where: 'id = ? AND userId = ?',
        whereArgs: [task.id, uid],
        limit: 1,
      );

      final localMap = _taskToLocalMap(task, uid);

      // Preserve locally stored PDF information.
      if (existingTask.isNotEmpty) {
        final existingPdfName = existingTask.first['pdfName'];
        final existingPdfPath = existingTask.first['pdfPath'];

        if (existingPdfName != null) {
          localMap['pdfName'] = existingPdfName;
        }

        if (existingPdfPath != null) {
          localMap['pdfPath'] = existingPdfPath;
        }
      }

      await txn.insert(
        'tasks',
        localMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
  // ============================================================
  // Check Pending Operation For Task
  // ============================================================

  Future<bool> hasPendingOperation(String taskId) async {
    final uid = _userId;
    if (uid == null) return false;

    final db = await database;

    final result = await db.query(
      'pending_task_sync',
      where: 'userId = ? AND entityId = ?',
      whereArgs: [uid, taskId],
      limit: 1,
    );

    return result.isNotEmpty;
  }
  Future<void> clearUserTaskData(String userId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'pending_task_sync',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      await txn.delete(
        'tasks',
        where: 'userId = ?',
        whereArgs: [userId],
      );
    });
  }
}
