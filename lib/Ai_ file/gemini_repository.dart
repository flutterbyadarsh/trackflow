import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

class GeminiRepository {
  GenerativeModel get primaryModel {
    return FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.8-flash',
      generationConfig: GenerationConfig(
       // thinkingConfig: ThinkingConfig(
        //  thinkingBudget: 0,
       // ),
      ),
    );
  }

  GenerativeModel get fallbackModel {
    return FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.5-flash-lite',
    );
  }

  GeminiRepository();

  // ----------------------------------------------------------
  // MODEL EXECUTION WITH AUTOMATIC FALLBACK
  // ----------------------------------------------------------

  Future<GenerateContentResponse> _generateWithFallback(
    List<Content> contents,
  ) async {
    try {
      return await primaryModel
          .generateContent(contents)
          .timeout(const Duration(seconds: 25));
    } catch (primaryError) {
      debugPrint('Primary model (gemini-3.8-flash) error: $primaryError. Trying fallback (gemini-3.5-flash-lite)...');
      try {
        return await fallbackModel
            .generateContent(contents)
            .timeout(const Duration(seconds: 25));
      } catch (fallbackError) {
        debugPrint('Fallback model (gemini-3.5-flash-lite) error: $fallbackError');
        throw Exception('$primaryError | Fallback: $fallbackError');
      }
    }
  }

  // ----------------------------------------------------------
  // LOCAL DATE AND TIME HELPERS
  // ----------------------------------------------------------

  DateTime _nowLocal() {
    return DateTime.now();
  }

  String _getTimezoneInfo() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');

    return '''
Timezone: ${now.timeZoneName}
UTC Offset: $sign$hours:$minutes
''';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  // ----------------------------------------------------------
  // INTENT DETECTION HELPER
  // ----------------------------------------------------------

  bool isTaskCreationIntent(String query) {
    final lower = query.toLowerCase().trim();
    final taskPatterns = [
      r'\b(?:create|add|make|schedule|set|remind me to|reminder for)\b',
      r'\btask\b',
      r'\b(todo|to-do)\b',
      r'\b(task banao|task add karo|schedule karo|remind karo)\b',
    ];

    int matches = 0;
    for (final pattern in taskPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        matches++;
      }
    }

    return matches >= 2 ||
        lower.startsWith('create task') ||
        lower.startsWith('add task') ||
        lower.startsWith('schedule task') ||
        lower.startsWith('remind me to');
  }

  // ----------------------------------------------------------
  // RESOLVE DATE
  // ----------------------------------------------------------

  String _resolveDate(
    String request,
    String aiDate,
    DateTime today,
  ) {
    final text = request.toLowerCase();

    if (RegExp(r'\btomorrow\b').hasMatch(text) ||
        RegExp(r'\bkal\b').hasMatch(text)) {
      return _formatDate(today.add(const Duration(days: 1)));
    }

    if (RegExp(r'\btoday\b').hasMatch(text) ||
        RegExp(r'\baaj\b').hasMatch(text)) {
      return _formatDate(today);
    }

    final dateMatch = RegExp(
      r'\b(\d{4}-\d{1,2}-\d{1,2})\b',
    ).firstMatch(request);

    if (dateMatch != null) {
      final date = DateTime.tryParse(dateMatch.group(1)!);
      if (date != null) {
        return _formatDate(date);
      }
    }

    final parsedAiDate = DateTime.tryParse(aiDate);
    return parsedAiDate != null ? _formatDate(parsedAiDate) : _formatDate(today);
  }

  // ----------------------------------------------------------
  // RESOLVE TIME
  // ----------------------------------------------------------

  String _resolveTime(String request, String aiTime) {
    final timeMatch = RegExp(
      r'\b(1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(a\.?m\.?|p\.?m\.?)\b',
      caseSensitive: false,
    ).firstMatch(request);

    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final period = timeMatch.group(3)!.toLowerCase();

      if (period.startsWith('p') && hour != 12) {
        hour += 12;
      }
      if (period.startsWith('a') && hour == 12) {
        hour = 0;
      }

      return _formatTime(hour, minute);
    }

    return aiTime.trim().isNotEmpty ? aiTime.trim() : '7:00 PM';
  }

  // ----------------------------------------------------------
  // RESOLVE PRIORITY
  // ----------------------------------------------------------

  String _resolvePriority(String request, String aiPriority) {
    final text = request.toLowerCase();

    if (RegExp(r'\bhigh\s+priority\b').hasMatch(text) ||
        RegExp(r'\bhigh\b').hasMatch(text) ||
        RegExp(r'\bzaroori\b').hasMatch(text) ||
        RegExp(r'\burgent\b').hasMatch(text)) {
      return 'High';
    }

    if (RegExp(r'\blow\s+priority\b').hasMatch(text) ||
        RegExp(r'\blow\b').hasMatch(text)) {
      return 'Low';
    }

    const validPriorities = ['Low', 'Medium', 'High'];

    return validPriorities.firstWhere(
      (p) => p.toLowerCase() == aiPriority.toLowerCase(),
      orElse: () => 'Medium',
    );
  }

  // ----------------------------------------------------------
  // RESOLVE CATEGORY
  // ----------------------------------------------------------

  String _resolveCategory(
    String request,
    String aiCategory,
    List<String> availableCategories,
  ) {
    for (final category in availableCategories) {
      final pattern = RegExp(
        '\\b${RegExp.escape(category)}\\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(request)) {
        return category;
      }
    }

    for (final category in availableCategories) {
      if (category.toLowerCase() == aiCategory.toLowerCase()) {
        return category;
      }
    }

    return availableCategories.firstWhere(
      (c) => c.toLowerCase() == 'other',
      orElse: () => availableCategories.isNotEmpty
          ? availableCategories.first
          : 'Other',
    );
  }

  // ----------------------------------------------------------
  // RESOLVE TITLE
  // ----------------------------------------------------------

  String _resolveTitle(String request, String aiTitle) {
    final match = RegExp(
      r'\b(?:create|add|make|schedule)\s+(?:a\s+|an\s+|the\s+)?(.+?)\s+task\b',
      caseSensitive: false,
    ).firstMatch(request);

    if (match != null) {
      final extracted = match.group(1)!.trim();
      if (extracted.isNotEmpty) {
        return extracted[0].toUpperCase() + extracted.substring(1);
      }
    }

    if (aiTitle.trim().isEmpty || aiTitle.toLowerCase().trim() == 'add task') {
      return 'New Task';
    }

    return aiTitle.trim();
  }

  // ----------------------------------------------------------
  // GENERATE TASK PROPOSAL
  // ----------------------------------------------------------

  Future<Map<String, dynamic>> generateTaskProposal(
    String userRequest, {
    required List<String> availableCategories,
  }) async {
    try {
      final today = _nowLocal();
      final todayString = _formatDate(today);

      final prompt = '''
You are TrackFlow AI, a task creation assistant.

Convert the user's request into a structured task proposal.

CURRENT LOCAL DATE:
$todayString

CURRENT LOCAL DATE AND TIME:
${today.toIso8601String()}

USER TIMEZONE:
${_getTimezoneInfo()}

AVAILABLE CATEGORIES:
${availableCategories.join(', ')}

STRICT RULES:
1. Return ONLY valid JSON.
2. Never return markdown blocks, ticks, or explanatory text.
3. Create a clear, concise title based on what the user wants to accomplish.
4. Select category only from AVAILABLE CATEGORIES.
5. Use today's date if no date is specified.
6. Resolve tomorrow relative to CURRENT LOCAL DATE ($todayString).
7. Date format must be YYYY-MM-DD.
8. Time format must be h:mm AM/PM. Default time is 7:00 PM.
9. Priority must be Low, Medium, or High. Default is Medium.
10. Notes should contain any extra context mentioned by user or empty string.

JSON FORMAT EXAMPLE:
{
  "title": "Study physics chapter 3",
  "category": "${availableCategories.isNotEmpty ? availableCategories.first : 'Study'}",
  "date": "$todayString",
  "time": "7:00 PM",
  "priority": "Medium",
  "notes": ""
}

USER REQUEST:
$userRequest
''';

      final response = await _generateWithFallback([
        Content.text(prompt),
      ]);

      final result = response.text?.trim();
      if (result == null || result.isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      final cleanJson = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid task proposal format.');
      }

      final aiTitle = decoded['title']?.toString() ?? '';
      final aiCategory = decoded['category']?.toString() ?? '';
      final aiDate = decoded['date']?.toString() ?? '';
      final aiTime = decoded['time']?.toString() ?? '';
      final aiPriority = decoded['priority']?.toString() ?? '';
      final notes = decoded['notes']?.toString() ?? '';

      final finalProposal = <String, dynamic>{
        'title': _resolveTitle(userRequest, aiTitle),
        'category': _resolveCategory(
          userRequest,
          aiCategory,
          availableCategories,
        ),
        'date': _resolveDate(userRequest, aiDate, today),
        'time': _resolveTime(userRequest, aiTime),
        'priority': _resolvePriority(userRequest, aiPriority),
        'notes': notes,
      };

      debugPrint('FINAL TASK PROPOSAL: $finalProposal');
      return finalProposal;
    } catch (e, stackTrace) {
      debugPrint('TASK PROPOSAL ERROR: $e');
      debugPrint('TASK PROPOSAL STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // SEND MESSAGE WITH CHAT HISTORY & CONTEXT
  // ----------------------------------------------------------

  Future<String> sendMessage(
    String message, {
    required String taskContext,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      debugPrint('GEMINI: Sending message with context...');

      final now = _nowLocal();

      final historyBuffer = StringBuffer();
      if (conversationHistory.isNotEmpty) {
        historyBuffer.writeln('\nRECENT CONVERSATION HISTORY:');
        for (final entry in conversationHistory) {
          final role = entry['role'] == 'user' ? 'User' : 'TrackFlow AI';
          final text = entry['text'] ?? '';
          historyBuffer.writeln('$role: $text');
        }
      }

      final prompt = '''
You are TrackFlow AI, an intelligent personal productivity assistant built into TrackFlow.

You help users understand their existing tasks, plan their schedules, suggest routines, analyze productivity, and answer general questions about study, work, coding, and life habits.

CURRENT LOCAL DATE AND TIME:
${now.toIso8601String()}

USER TIMEZONE:
${_getTimezoneInfo()}

USER'S CURRENT TASK DATA:
$taskContext
$historyBuffer
USER MESSAGE:
$message

GUIDELINES:
1. Provide accurate, practical, and direct answers.
2. When answering about tasks, use the provided task data as the ground truth.
3. For general knowledge or planning questions, provide clear step-by-step guidance, bullet points, or examples.
4. If user speaks Hinglish or Hindi, reply naturally in helpful Hinglish or friendly English.
5. Keep your tone supportive, encouraging, and productive.
6. Do not wrap entire responses in code blocks unless writing actual code.
''';

      final response = await _generateWithFallback([
        Content.text(prompt),
      ]);

      final result = response.text?.trim();
      if (result == null || result.isEmpty) {
        return 'I could not generate a response. Please try again.';
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('GEMINI ERROR: $e');
      debugPrint('GEMINI STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // ANALYZE PDF DOCUMENT WITH GEMINI
  // ----------------------------------------------------------

  Future<String> analyzePdf({
    required Uint8List pdfBytes,
    required String prompt,
    String? taskContext,
    String? fileName,
  }) async {
    try {
      debugPrint('GEMINI: Analyzing PDF (${pdfBytes.length} bytes)...');
      final now = _nowLocal();

      final systemPrompt = '''
You are TrackFlow AI Document Assistant.
You are analyzing an attached PDF document${fileName != null ? ' ("$fileName")' : ''}.

CURRENT DATE: ${_formatDate(now)}
${taskContext != null ? '\nUSER TASKS CONTEXT:\n$taskContext\n' : ''}

USER INSTRUCTION:
$prompt

INSTRUCTIONS:
1. Read the PDF content carefully.
2. Answer the user's questions or summarize the key points clearly.
3. If the user asks for action items or tasks from this document, list them clearly with suggested priority and due dates.
4. Keep the explanation structured with clear headings or bullet points.
5. If the document cannot be read or contains unreadable scans, inform the user politely.
''';

      final contents = [
        Content.multi([
          InlineDataPart('application/pdf', pdfBytes),
          TextPart(systemPrompt),
        ]),
      ];

      final response = await _generateWithFallback(contents);
      final result = response.text?.trim();

      if (result == null || result.isEmpty) {
        return 'I could not extract or analyze information from the attached PDF. Please check the file.';
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('GEMINI PDF ANALYSIS ERROR: $e');
      debugPrint('GEMINI PDF STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // EXTRACT TASK PROPOSAL FROM PDF
  // ----------------------------------------------------------

  Future<Map<String, dynamic>> extractTaskProposalFromPdf({
    required Uint8List pdfBytes,
    required String userRequest,
    required List<String> availableCategories,
    String? fileName,
  }) async {
    try {
      final today = _nowLocal();
      final todayString = _formatDate(today);

      final prompt = '''
You are TrackFlow AI. Analyze the attached PDF${fileName != null ? ' ("$fileName")' : ''} and create a single primary task proposal based on it and the user's request.

CURRENT LOCAL DATE: $todayString
AVAILABLE CATEGORIES: ${availableCategories.join(', ')}

USER REQUEST:
$userRequest

STRICT RULES:
1. Return ONLY valid JSON.
2. Title must be concise and actionable based on the document.
3. Category must be chosen from AVAILABLE CATEGORIES.
4. Date format: YYYY-MM-DD.
5. Time format: h:mm AM/PM.
6. Priority: Low, Medium, or High.
7. Notes: summary of key action items or deadlines mentioned in the document.

JSON FORMAT:
{
  "title": "Review Document",
  "category": "${availableCategories.isNotEmpty ? availableCategories.first : 'Work'}",
  "date": "$todayString",
  "time": "7:00 PM",
  "priority": "Medium",
  "notes": "Key details from document"
}
''';

      final contents = [
        Content.multi([
          InlineDataPart('application/pdf', pdfBytes),
          TextPart(prompt),
        ]),
      ];

      final response = await _generateWithFallback(contents);
      final result = response.text?.trim();
      if (result == null || result.isEmpty) {
        throw Exception('Gemini could not extract a task from the document.');
      }

      final cleanJson = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid task proposal JSON from PDF.');
      }

      final aiTitle = decoded['title']?.toString() ?? 'Review ${fileName ?? "Document"}';
      final aiCategory = decoded['category']?.toString() ?? '';
      final aiDate = decoded['date']?.toString() ?? '';
      final aiTime = decoded['time']?.toString() ?? '';
      final aiPriority = decoded['priority']?.toString() ?? '';
      final notes = decoded['notes']?.toString() ?? '';

      return <String, dynamic>{
        'title': _resolveTitle(userRequest, aiTitle),
        'category': _resolveCategory(
          userRequest,
          aiCategory,
          availableCategories,
        ),
        'date': _resolveDate(userRequest, aiDate, today),
        'time': _resolveTime(userRequest, aiTime),
        'priority': _resolvePriority(userRequest, aiPriority),
        'notes': notes,
      };
    } catch (e, stackTrace) {
      debugPrint('PDF TASK EXTRACT ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // PLAN MY DAY
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> generateDailySchedule({
    required List<Map<String, dynamic>> pendingTasks,
    required DateTime currentDateTime,
  }) async {
    try {
      if (pendingTasks.isEmpty) return [];

      final localNow = currentDateTime.toLocal();

      final prompt = '''
You are TrackFlow AI, a daily scheduling assistant.

Create a realistic schedule for the user's pending tasks.

CURRENT LOCAL DATE AND TIME:
${localNow.toIso8601String()}

USER TIMEZONE:
${_getTimezoneInfo()}

PENDING TASKS:
${jsonEncode(pendingTasks)}

STRICT RULES:
1. Return ONLY valid JSON.
2. Do not use markdown.
3. Only schedule tasks whose IDs exist in the supplied data.
4. Never include completed tasks.
5. Do not change task titles or IDs.
6. Respect priority: High before Medium before Low.
7. Prefer realistic working hours.
8. Avoid overlapping task times.
9. Use date format YYYY-MM-DD.
10. Use time format h:mm AM/PM.
11. Give a short reason for every suggestion.
12. Do not schedule tasks in the past.

JSON FORMAT:
{
  "schedule": [
    {
      "id": "existing_task_id",
      "date": "${_formatDate(localNow)}",
      "time": "9:00 AM",
      "reason": "High priority task scheduled first."
    }
  ]
}
''';

      final response = await _generateWithFallback([
        Content.text(prompt),
      ]);

      final result = response.text?.trim();

      if (result == null || result.isEmpty) {
        throw Exception('Gemini returned an empty schedule.');
      }

      final cleanJson = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(cleanJson);

      if (decoded is! Map<String, dynamic> ||
          decoded['schedule'] is! List) {
        throw Exception('Invalid schedule response.');
      }

      return (decoded['schedule'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('DAILY SCHEDULE ERROR: $e');
      debugPrint('DAILY SCHEDULE STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // SUGGEST ROUTINE
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> generateRoutineSuggestions({
    required List<Map<String, dynamic>> tasks,
    required List<String> availableCategories,
  }) async {
    try {
      final today = _formatDate(_nowLocal());

      final prompt = '''
You are TrackFlow AI, a productivity routine assistant.

Suggest a practical daily routine based on the user's actual tasks.

CURRENT LOCAL DATE:
$today

USER TIMEZONE:
${_getTimezoneInfo()}

AVAILABLE CATEGORIES:
${availableCategories.join(', ')}

USER TASK DATA:
${jsonEncode(tasks)}

STRICT RULES:
1. Return ONLY valid JSON.
2. Do not use markdown.
3. Suggest 3 to 5 practical routine items.
4. Use categories only from AVAILABLE CATEGORIES.
5. Use date format YYYY-MM-DD.
6. Use time format h:mm AM/PM.
7. Priority must be Low, Medium, or High.
8. Keep titles short and meaningful.

JSON FORMAT:
{
  "routines": [
    {
      "title": "Morning Planning",
      "category": "${availableCategories.isNotEmpty ? availableCategories.first : 'Work'}",
      "date": "$today",
      "time": "8:00 AM",
      "priority": "Medium",
      "notes": "Plan important tasks for the day."
    }
  ]
}
''';

      final response = await _generateWithFallback([
        Content.text(prompt),
      ]);

      final result = response.text?.trim();

      if (result == null || result.isEmpty) {
        throw Exception('Gemini returned empty routine suggestions.');
      }

      final cleanJson = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(cleanJson);

      if (decoded is! Map<String, dynamic> ||
          decoded['routines'] is! List) {
        throw Exception('Invalid routine response.');
      }

      final validCategories = availableCategories
          .map((category) => category.toLowerCase())
          .toSet();

      return (decoded['routines'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) {
        final category = item['category']?.toString().toLowerCase();
        return category != null && validCategories.contains(category);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('ROUTINE SUGGESTION ERROR: $e');
      debugPrint('ROUTINE SUGGESTION STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  // ----------------------------------------------------------
  // ANALYZE PROGRESS
  // ----------------------------------------------------------

  Future<String> analyzeProgress({
    required String progressSummary,
    required String taskContext,
  }) async {
    try {
      final now = _nowLocal();

      final prompt = '''
You are TrackFlow AI, a productivity progress analyst.

Analyze the user's real productivity data.

CURRENT LOCAL DATE AND TIME:
${now.toIso8601String()}

USER TIMEZONE:
${_getTimezoneInfo()}

CALCULATED PROGRESS SUMMARY:
$progressSummary

USER TASK DATA:
$taskContext

STRICT RULES:
1. Use only the supplied task data.
2. Never invent task counts or percentages.
3. Treat calculated summary as the source of truth.
4. Identify positive progress.
5. Identify areas that need improvement.
6. Mention overdue tasks only when supported by data.
7. Give 3 practical improvement suggestions.
8. Be friendly and concise.

Use these headings:
Progress Overview
What Is Going Well
Areas to Improve
Suggestions for Next Steps
''';

      final response = await _generateWithFallback([
        Content.text(prompt),
      ]);

      final result = response.text?.trim();

      if (result == null || result.isEmpty) {
        throw Exception('Gemini could not analyze progress.');
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('PROGRESS ANALYSIS ERROR: $e');
      debugPrint('PROGRESS ANALYSIS STACKTRACE: $stackTrace');
      rethrow;
    }
  }
}
