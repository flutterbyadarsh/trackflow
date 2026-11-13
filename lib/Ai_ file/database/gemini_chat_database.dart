import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class GeminiChatSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  GeminiChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GeminiChatSession.fromMap(Map<String, dynamic> map) {
    return GeminiChatSession(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class GeminiChatMessage {
  final String id;
  final String sessionId;
  final String userId;
  final bool isUser;
  final String type; // 'text', 'task_proposal', 'schedule_proposal', 'routine_proposal', 'progress_analysis', 'pdf_analysis'
  final String text;
  final Map<String, dynamic>? payload;
  final String? pdfName;
  final String? pdfPath;
  final bool isConfirmed;
  final DateTime createdAt;

  GeminiChatMessage({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.isUser,
    required this.type,
    required this.text,
    this.payload,
    this.pdfName,
    this.pdfPath,
    this.isConfirmed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'userId': userId,
      'isUser': isUser ? 1 : 0,
      'type': type,
      'text': text,
      'payload': payload != null ? jsonEncode(payload) : null,
      'pdfName': pdfName,
      'pdfPath': pdfPath,
      'isConfirmed': isConfirmed ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GeminiChatMessage.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? decodedPayload;
    final payloadRaw = map['payload'] as String?;
    if (payloadRaw != null && payloadRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is Map) {
          decodedPayload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return GeminiChatMessage(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      userId: map['userId'] as String,
      isUser: (map['isUser'] as int?) == 1,
      type: map['type'] as String? ?? 'text',
      text: map['text'] as String? ?? '',
      payload: decodedPayload,
      pdfName: map['pdfName'] as String?,
      pdfPath: map['pdfPath'] as String?,
      isConfirmed: (map['isConfirmed'] as int?) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class GeminiChatDatabase {
  GeminiChatDatabase._();

  static final GeminiChatDatabase instance = GeminiChatDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'trackflow_gemini_ai.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE gemini_sessions (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE gemini_messages (
            id TEXT PRIMARY KEY,
            sessionId TEXT NOT NULL,
            userId TEXT NOT NULL,
            isUser INTEGER NOT NULL,
            type TEXT NOT NULL,
            text TEXT NOT NULL,
            payload TEXT,
            pdfName TEXT,
            pdfPath TEXT,
            isConfirmed INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (sessionId) REFERENCES gemini_sessions (id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_gemini_msg_session ON gemini_messages (sessionId)',
        );
        await db.execute(
          'CREATE INDEX idx_gemini_msg_user ON gemini_messages (userId)',
        );
      },
    );

    return _database!;
  }

  // ----------------------------------------------------------
  // SESSIONS
  // ----------------------------------------------------------

  Future<GeminiChatSession> getOrCreateActiveSession(String userId) async {
    final db = await database;
    final results = await db.query(
      'gemini_sessions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return GeminiChatSession.fromMap(results.first);
    }

    final newSession = GeminiChatSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'New Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await db.insert('gemini_sessions', newSession.toMap());
    return newSession;
  }

  Future<List<GeminiChatSession>> getSessions(String userId) async {
    final db = await database;
    final results = await db.query(
      'gemini_sessions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );
    return results.map((m) => GeminiChatSession.fromMap(m)).toList();
  }

  Future<GeminiChatSession> createNewSession(String userId, {String? title}) async {
    final db = await database;
    final newSession = GeminiChatSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: title ?? 'New Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert('gemini_sessions', newSession.toMap());
    return newSession;
  }

  Future<void> updateSessionTitle(String sessionId, String title) async {
    final db = await database;
    await db.update(
      'gemini_sessions',
      {'title': title, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'gemini_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      'gemini_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ----------------------------------------------------------
  // MESSAGES
  // ----------------------------------------------------------

  Future<List<GeminiChatMessage>> getMessages(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'gemini_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'createdAt ASC',
    );
    return results.map((m) => GeminiChatMessage.fromMap(m)).toList();
  }

  Future<void> saveMessage(GeminiChatMessage message) async {
    final db = await database;
    await db.insert(
      'gemini_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update session timestamp
    await db.update(
      'gemini_sessions',
      {'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [message.sessionId],
    );
  }

  Future<void> updateMessageStatus(
    String messageId, {
    bool? isConfirmed,
    Map<String, dynamic>? updatedPayload,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (isConfirmed != null) {
      updates['isConfirmed'] = isConfirmed ? 1 : 0;
    }
    if (updatedPayload != null) {
      updates['payload'] = jsonEncode(updatedPayload);
    }
    if (updates.isNotEmpty) {
      await db.update(
        'gemini_messages',
        updates,
        where: 'id = ?',
        whereArgs: [messageId],
      );
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'gemini_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearSessionMessages(String sessionId) async {
    final db = await database;
    await db.delete(
      'gemini_messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> clearAllUserHistory(String userId) async {
    final db = await database;
    await db.delete(
      'gemini_messages',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    await db.delete(
      'gemini_sessions',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }
}
