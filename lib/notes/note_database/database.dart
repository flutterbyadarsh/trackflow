
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../notes_data_model/notes_data_model.dart';

class PendingNoteSync {
  const PendingNoteSync({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic> payload;

  factory PendingNoteSync.fromMap(Map<String, Object?> map) {
    final raw = map['payload'] as String?;

    return PendingNoteSync(
      id: map['id'] as int,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      action: map['action'] as String,
      payload: raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
}

class NotesDatabase {
  NotesDatabase._();

  static final NotesDatabase instance = NotesDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();

    _database = await openDatabase(
      p.join(dbPath, 'trackflow_notes.db'),
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _migrateToV3(db);
        }
      },
    );

    return _database!;
  }

  static Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE note_folders (
        id TEXT NOT NULL,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        parentId TEXT,
        PRIMARY KEY (userId, id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT NOT NULL,
        userId TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        folderId TEXT,
        pdfName TEXT,
        pdfPath TEXT,
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (userId, id)
      )
    ''');

    await _createPendingTable(db);
  }

  static Future<void> _createPendingTable(
      DatabaseExecutor db,
      ) async {
    await db.execute('''
      CREATE TABLE pending_note_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        UNIQUE(userId, entityType, entityId)
      )
    ''');
  }

  static Future<void> _migrateToV3(Database db) async {
    await db.transaction((txn) async {
      // Existing tables are renamed so their records remain preserved.
      await txn.execute(
        'ALTER TABLE note_folders RENAME TO note_folders_old',
      );
      await txn.execute(
        'ALTER TABLE notes RENAME TO notes_old',
      );

      // The old pending table may not exist in very old installations.
      final pendingExists = Sqflite.firstIntValue(
        await txn.rawQuery('''
          SELECT COUNT(*) FROM sqlite_master
          WHERE type = 'table' AND name = 'pending_note_sync'
        '''),
      ) ?? 0;

      if (pendingExists > 0) {
        await txn.execute(
          'ALTER TABLE pending_note_sync RENAME TO pending_note_sync_old',
        );
      }

      await _createTables(txn);

      // Legacy records remain unassigned until the first authenticated
      // account explicitly claims them through ensureLegacyDataAssigned().
      await txn.execute('''
        INSERT INTO note_folders (id, userId, name, parentId)
        SELECT id, '', name, parentId FROM note_folders_old
      ''');

      await txn.execute('''
        INSERT INTO notes (
          id, userId, title, content, category,
          folderId, pdfName, pdfPath, updatedAt
        )
        SELECT
          id, '', title, content, category,
          folderId, pdfName, pdfPath, updatedAt
        FROM notes_old
      ''');

      if (pendingExists > 0) {
        await txn.execute('''
          INSERT INTO pending_note_sync (
            id, userId, entityType, entityId,
            action, payload, createdAt
          )
          SELECT
            id, '', entityType, entityId,
            action, payload, createdAt
          FROM pending_note_sync_old
        ''');

        await txn.execute('DROP TABLE pending_note_sync_old');
      }

      await txn.execute('DROP TABLE note_folders_old');
      await txn.execute('DROP TABLE notes_old');
    });
  }

  /// Assigns unclaimed legacy records to the first authenticated user.
  /// Call this after login and before loading local Notes data.
  Future<void> ensureLegacyDataAssigned(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'note_folders',
        {'userId': userId},
        where: "userId = ''",
      );

      await txn.update(
        'notes',
        {'userId': userId},
        where: "userId = ''",
      );

      await txn.update(
        'pending_note_sync',
        {'userId': userId},
        where: "userId = ''",
      );
    });
  }

  void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('A valid userId is required');
    }
  }

  Future<void> _queue(
      DatabaseExecutor db, {
        required String userId,
        required String entityType,
        required String entityId,
        required String action,
        Map<String, dynamic>? payload,
      }) async {
    await db.insert(
      'pending_note_sync',
      {
        'userId': userId,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'payload': jsonEncode(payload ?? <String, dynamic>{}),
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // FOLDERS

  Future<List<NoteFolder>> getFolders({
    required String userId,
  }) async {
    _validateUserId(userId);
    final db = await database;

    final rows = await db.query(
      'note_folders',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    return rows.map((row) => NoteFolder.fromMap(row)).toList();
  }

  Future<void> insertFolder(
      NoteFolder folder, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.insert(
      'note_folders',
      {...folder.toMap(), 'userId': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFolder(
      NoteFolder folder, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.update(
      'note_folders',
      {...folder.toMap(), 'userId': userId},
      where: 'id = ? AND userId = ?',
      whereArgs: [folder.id, userId],
    );
  }

  Future<void> saveFolderAndQueue(
      NoteFolder folder, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert(
        'note_folders',
        {...folder.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _queue(
        txn,
        userId: userId,
        entityType: 'folder',
        entityId: folder.id,
        action: 'upsert',
        payload: folder.toMap(),
      );
    });
  }

  Future<void> deleteFolder(
      String id, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.delete(
      'note_folders',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> deleteFolderAndQueue(
      String id, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'note_folders',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, userId],
      );

      await _queue(
        txn,
        userId: userId,
        entityType: 'folder',
        entityId: id,
        action: 'delete',
      );
    });
  }

  // NOTES

  Future<List<NoteItem>> getNotes({
    required String userId,
  }) async {
    _validateUserId(userId);
    final db = await database;

    final rows = await db.query(
      'notes',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );

    return rows.map((row) => NoteItem.fromMap(row)).toList();
  }

  Future<void> insertNote(
      NoteItem note, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.insert(
      'notes',
      {...note.toMap(), 'userId': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNote(
      NoteItem note, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.update(
      'notes',
      {...note.toMap(), 'userId': userId},
      where: 'id = ? AND userId = ?',
      whereArgs: [note.id, userId],
    );
  }

  Future<void> saveNoteAndQueue(
      NoteItem note, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert(
        'notes',
        {...note.toMap(), 'userId': userId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final cloudData = note.toMap()..remove('pdfPath');

      await _queue(
        txn,
        userId: userId,
        entityType: 'note',
        entityId: note.id,
        action: 'upsert',
        payload: cloudData,
      );
    });
  }

  Future<void> deleteNote(
      String id, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.delete(
      'notes',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> deleteNoteAndQueue(
      String id, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'notes',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, userId],
      );

      await _queue(
        txn,
        userId: userId,
        entityType: 'note',
        entityId: id,
        action: 'delete',
      );
    });
  }

  Future<void> deleteNotesByFolder(
      String folderId, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.delete(
      'notes',
      where: 'folderId = ? AND userId = ?',
      whereArgs: [folderId, userId],
    );
  }

  // LEGACY LOCAL DATA UPLOAD QUEUE

  Future<void> queueFolderUpload(
      NoteFolder folder, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await _queue(
      db,
      userId: userId,
      entityType: 'folder',
      entityId: folder.id,
      action: 'upsert',
      payload: folder.toMap(),
    );
  }

  Future<void> queueNoteUpload(
      NoteItem note, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    final cloudData = note.toMap()..remove('pdfPath');

    await _queue(
      db,
      userId: userId,
      entityType: 'note',
      entityId: note.id,
      action: 'upsert',
      payload: cloudData,
    );
  }

  // PENDING QUEUE

  Future<List<PendingNoteSync>> getPendingSyncItems({
    required String userId,
  }) async {
    _validateUserId(userId);
    final db = await database;

    final rows = await db.query(
      'pending_note_sync',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );

    return rows.map(PendingNoteSync.fromMap).toList();
  }

  Future<void> removePendingSyncItem(
      int id, {
        required String userId,
      }) async {
    _validateUserId(userId);
    final db = await database;

    await db.delete(
      'pending_note_sync',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> getPendingSyncCount({
    required String userId,
  }) async {
    _validateUserId(userId);
    final db = await database;

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM pending_note_sync WHERE userId = ?',
      [userId],
    );

    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ACCOUNT DELETION: only this user's local Notes data is removed.

  Future<void> clearUserNoteData({
    required String userId,
  }) async {
    _validateUserId(userId);
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'pending_note_sync',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      await txn.delete(
        'notes',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      await txn.delete(
        'note_folders',
        where: 'userId = ?',
        whereArgs: [userId],
      );
    });
  }
}
