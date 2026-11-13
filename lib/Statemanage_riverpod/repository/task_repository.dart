
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data_model/task_entity.dart';
import '../database/task_database.dart';

class TaskRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final TaskDatabase _database;

  bool _isSyncing = false;
  bool _syncRequested = false;
  bool _syncPaused = false;
  Completer<void>? _syncFinished;


  TaskRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    TaskDatabase? database,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? TaskDatabase.instance;

  // ============================================================
// Pause Sync - Account Deletion
// ========================write====================================
  int _activeWrites = 0;
  Completer<void>? _writesFinished;

  Future<void> pauseSyncAndWait() async {
    _syncPaused = true;
    _syncRequested = false;

    // Wait for running local database writes.
    final activeWrites = _writesFinished?.future;

    if (activeWrites != null) {
      await activeWrites;
    }

    // Wait for running Firestore sync.
    final activeSync = _syncFinished?.future;

    if (activeSync != null) {
      await activeSync;
    }
  }
  // helpr
  Future<void> _runLocalWrite(
      Future<void> Function() operation,
      ) async {
    if (_syncPaused) return;

    _activeWrites++;

    _writesFinished ??= Completer<void>();

    try {
      // Recheck after registering the operation.
      if (_syncPaused) return;

      await operation();

      // Don't start sync if account deletion has started.
      if (!_syncPaused) {
        unawaited(syncPendingTasks());
      }
    } finally {
      _activeWrites--;

      if (_activeWrites == 0) {
        if (!(_writesFinished?.isCompleted ?? true)) {
          _writesFinished!.complete();
        }

        _writesFinished = null;
      }
    }
  }



  // ============================================================
// Resume Sync
// ============================================================

  void resumeSync() {
    if (!_syncPaused) return;

    _syncPaused = false;

    // Resume pending Firestore sync.
    unawaited(
      syncPendingTasks().catchError((error) {
        // Keep pending operations in SQLite for next retry.
      }),
    );
  }
  // ============================================================
  // Firestore Collection
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _tasksCollection {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw Exception('User is not logged in');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks');
  }

  // ============================================================
  // Watch Tasks: Local First + Firestore Updates
  // ============================================================

  Stream<List<TaskEntity>> watchTasks() async* {
    if (_auth.currentUser == null) {
      yield [];
      return;
    }

    yield await _database.getLocalTasks();

    try {
      await for (final snapshot in _tasksCollection
          .orderBy('createdAt', descending: true)
          .snapshots()) {
        for (final doc in snapshot.docs) {
          final hasPending =
          await _database.hasPendingOperation(doc.id);

          if (hasPending) continue;

          final task = TaskEntity.fromMap(doc.data(), doc.id);

          await _database.saveCloudTaskLocally(task);
        }

        yield await _database.getLocalTasks();
      }
    } catch (e) {
      yield await _database.getLocalTasks();
    }
  }

  // ============================================================
  // Add Task - Local First
  // ============================================================

  Future<void> addTask(TaskEntity task) async {
    await _runLocalWrite(() async {
      await _database.saveTaskAndQueue(task);
    });
  }

  Future<void> updateTask(TaskEntity task) async {
    await _runLocalWrite(() async {
      await _database.saveTaskAndQueue(task);
    });
  }

  Future<void> deleteTask(String id) async {
    await _runLocalWrite(() async {
      await _database.deleteTaskAndQueue(id);
    });
  }

  // ============================================================
  // Convert Queued JSON Payload to Firestore Data
  // ============================================================

  Map<String, dynamic> _convertPayloadForFirestore(
      String payload,
      ) {
    final Map<String, dynamic> data =
    Map<String, dynamic>.from(jsonDecode(payload));

    for (final field in [
      'scheduledDate',
      'createdAt',
      'updatedAt',
    ]) {
      final value = data[field];

      if (value is String && value.isNotEmpty) {
        data[field] = Timestamp.fromDate(DateTime.parse(value));
      }
    }

    return data;
  }

  // ============================================================
  // Sync Pending Tasks with Firestore
  // ============================================================

  Future<void> syncPendingTasks() async {
    if (_syncPaused || _auth.currentUser == null) return;

    // Prevent multiple sync processes at the same time.
    if (_isSyncing) {
      _syncRequested = true;
      return;
    }

    _isSyncing = true;
    _syncFinished = Completer<void>();

    try {
      do {
        _syncRequested = false;

        if (_syncPaused) break;

        final pendingTasks =
        await _database.getPendingTaskSync();

        for (final pending in pendingTasks) {
          if (_syncPaused) break;

          try {
            final document =
            _tasksCollection.doc(pending.entityId);

            if (pending.action == 'delete') {
              await document
                  .delete()
                  .timeout(const Duration(seconds: 8));
            } else if (pending.action == 'upsert') {
              final data =
              _convertPayloadForFirestore(pending.payload);

              await document
                  .set(
                data,
                SetOptions(merge: true),
              )
                  .timeout(const Duration(seconds: 8));
            }

            await _database.removePendingTaskSync(pending.id!);
          } catch (e) {
            break;
          }
        }
      } while (_syncRequested && !_syncPaused);
    } catch (e) {
      // Pending operations remain in SQLite.
    } finally {
      _isSyncing = false;

      if (!(_syncFinished?.isCompleted ?? true)) {
        _syncFinished!.complete();
      }

      _syncFinished = null;
    }
  }

}
