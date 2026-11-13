import 'package:flutter_test/flutter_test.dart';
import 'package:trackflow/Ai_%20file/database/gemini_chat_database.dart';
import 'package:trackflow/Ai_%20file/gemini_repository.dart';

void main() {
  group('Gemini Chat Database Models Test', () {
    test('GeminiChatSession serialize and deserialize correctly', () {
      final session = GeminiChatSession(
        id: 'sess_123',
        userId: 'user_abc',
        title: 'Project Planning',
        createdAt: DateTime(2026, 11, 13, 10, 0),
        updatedAt: DateTime(2026, 11, 13, 10, 30),
      );

      final map = session.toMap();
      final restored = GeminiChatSession.fromMap(map);

      expect(restored.id, 'sess_123');
      expect(restored.userId, 'user_abc');
      expect(restored.title, 'Project Planning');
      expect(restored.createdAt, session.createdAt);
      expect(restored.updatedAt, session.updatedAt);
    });

    test('GeminiChatMessage serialize and deserialize correctly with payload and PDF', () {
      final msg = GeminiChatMessage(
        id: 'msg_999',
        sessionId: 'sess_123',
        userId: 'user_abc',
        isUser: true,
        type: 'pdf_analysis',
        text: 'Summarize this file',
        payload: {'priority': 'High', 'category': 'Study'},
        pdfName: 'report.pdf',
        pdfPath: '/path/to/report.pdf',
        isConfirmed: true,
        createdAt: DateTime(2026, 11, 13, 10, 15),
      );

      final map = msg.toMap();
      final restored = GeminiChatMessage.fromMap(map);

      expect(restored.id, 'msg_999');
      expect(restored.sessionId, 'sess_123');
      expect(restored.isUser, true);
      expect(restored.type, 'pdf_analysis');
      expect(restored.text, 'Summarize this file');
      expect(restored.pdfName, 'report.pdf');
      expect(restored.pdfPath, '/path/to/report.pdf');
      expect(restored.isConfirmed, true);
      expect(restored.payload?['priority'], 'High');
    });
  });

  group('Gemini Repository Intent Detection Test', () {
    final repo = GeminiRepository();

    test('Detects task creation intent accurately', () {
      expect(repo.isTaskCreationIntent('create task to buy groceries'), true);
      expect(repo.isTaskCreationIntent('add task for study'), true);
      expect(repo.isTaskCreationIntent('schedule task meeting at 3pm'), true);
      expect(repo.isTaskCreationIntent('remind me to call mom'), true);
      expect(repo.isTaskCreationIntent('what is quantum computing?'), false);
    });
  });
}
