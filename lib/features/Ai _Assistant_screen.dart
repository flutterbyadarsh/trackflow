
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:trackflow/data_model/Category_entity.dart';
import 'package:uuid/uuid.dart';

import '../Ai_ file/database/gemini_chat_database.dart';
import '../Ai_ file/gemini_repository.dart';
import '../Statemanage_riverpod/provider/category_provider.dart';
import '../Statemanage_riverpod/provider/task_provider.dart';
import '../data_model/task_entity.dart';
import 'documents_pdf_screen.dart';
import 'pdf_viewer_screen.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  final String? initialPdfPath;
  final String? initialPdfName;

  const AiAssistantScreen({
    super.key,
    this.initialPdfPath,
    this.initialPdfName,
  });

  @override
  ConsumerState<AiAssistantScreen> createState() =>
      _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _messageController =
  TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color primary = Color(0xFF5146E5);
  // uuid

  final Uuid _uuid = const Uuid();

  final GeminiRepository _geminiRepository = GeminiRepository();

  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = false;
  bool _isCreatingTask = false;
  String? _activeSessionId;
  String? _attachedPdfPath;
  String? _attachedPdfName;

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      _attachedPdfPath = widget.initialPdfPath;
      _attachedPdfName = widget.initialPdfName ?? p.basename(widget.initialPdfPath!);
    }
    _initChatDatabase();
  }

  Future<void> _initChatDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final session = await GeminiChatDatabase.instance.getOrCreateActiveSession(user.uid);
      _activeSessionId = session.id;

      final messages = await GeminiChatDatabase.instance.getMessages(session.id);
      if (messages.isNotEmpty && mounted) {
        final categories = ref.read(categoryProvider);
        final tasks = ref.read(taskProvider);

        final loadedList = <Map<String, dynamic>>[];
        for (final m in messages) {
          final msgMap = <String, dynamic>{
            'id': m.id,
            'isUser': m.isUser,
            'type': m.type,
            'text': m.text,
            'pdfName': m.pdfName,
            'pdfPath': m.pdfPath,
          };
          if (m.payload != null) {
            msgMap.addAll(m.payload!);
          }
          if (m.type == 'task_proposal') {
            final catVal = msgMap['categoryName'] ?? msgMap['category'];
            msgMap['category'] = _resolveCategoryEntity(catVal, categories);
            if (m.isConfirmed) {
              msgMap['status'] = 'saved';
            }
          } else if (m.type == 'schedule_proposal' && msgMap['items'] is List) {
            final items = (msgMap['items'] as List).map((it) {
              final itemMap = Map<String, dynamic>.from(it as Map);
              final taskId = itemMap['id'] ?? itemMap['taskId'];
              final match = tasks.where((t) => t.id == taskId);
              if (match.isNotEmpty) {
                itemMap['task'] = match.first;
              } else {
                itemMap['task'] = TaskEntity(
                  id: taskId?.toString() ?? 'task_id',
                  title: itemMap['title']?.toString() ?? 'Task',
                  category: itemMap['category']?.toString() ?? 'General',
                  categoryColor: 0xFF6366F1,
                  categoryBackgroundColor: 0xFFEEF2FF,
                  categoryIcon: 0xe318,
                  scheduledDate: DateTime.now(),
                  time: itemMap['time']?.toString() ?? '7:00 PM',
                  priority: 'Medium',
                  notes: '',
                  reminderEnable: false,
                  reminderMinutesBefore: 0,
                  reminderTime: '',
                  upcomingReminderEnabled: false,
                  upcomingReminderMinutesBefore: 0,
                  repeat: 'Never',
                  isCompleted: false,
                  createdAt: DateTime.now(),
                );
              }
              return itemMap;
            }).toList();
            msgMap['items'] = items;
            if (m.isConfirmed) {
              msgMap['status'] = 'saved';
            }
          } else if (m.type == 'routine_proposal' && msgMap['items'] is List) {
            final items = (msgMap['items'] as List).map((it) {
              final itemMap = Map<String, dynamic>.from(it as Map);
              final catVal = itemMap['categoryName'] ?? itemMap['category'];
              itemMap['category'] = _resolveCategoryEntity(catVal, categories);
              return itemMap;
            }).toList();
            msgMap['items'] = items;
            if (m.isConfirmed) {
              msgMap['status'] = 'saved';
            }
          }
          loadedList.add(msgMap);
        }

        setState(() {
          _messages.clear();
          _messages.addAll(loadedList);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Failed to load Gemini messages from SQLite: $e');
    }
  }

  Future<void> _saveMessageToDb(Map<String, dynamic> message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      if (_activeSessionId == null) {
        final session = await GeminiChatDatabase.instance.getOrCreateActiveSession(user.uid);
        _activeSessionId = session.id;
      }

      message['id'] ??= _uuid.v4();
      final type = message['type'] as String? ?? 'text';

      Map<String, dynamic>? payload;
      if (type != 'text') {
        payload = Map<String, dynamic>.from(message);
        payload.remove('id');
        payload.remove('isUser');
        payload.remove('type');
        payload.remove('text');
        payload.remove('pdfName');
        payload.remove('pdfPath');

        if (payload['category'] is CategoryEntity) {
          payload['categoryName'] = (payload['category'] as CategoryEntity).name;
          payload.remove('category');
        }

        if (payload['items'] is List) {
          payload['items'] = (payload['items'] as List).map((it) {
            final itemMap = Map<String, dynamic>.from(it as Map);
            if (itemMap['category'] is CategoryEntity) {
              itemMap['categoryName'] = (itemMap['category'] as CategoryEntity).name;
              itemMap.remove('category');
            }
            if (itemMap['task'] is TaskEntity) {
              final task = itemMap['task'] as TaskEntity;
              itemMap['taskId'] = task.id;
              itemMap['title'] = task.title;
              itemMap.remove('task');
            }
            return itemMap;
          }).toList();
        }
      }

      final dbMsg = GeminiChatMessage(
        id: message['id'] as String,
        sessionId: _activeSessionId!,
        userId: user.uid,
        isUser: message['isUser'] == true,
        type: type,
        text: message['text']?.toString() ?? '',
        payload: payload,
        pdfName: message['pdfName'] as String?,
        pdfPath: message['pdfPath'] as String?,
        isConfirmed: message['status'] == 'saved',
        createdAt: DateTime.now(),
      );

      await GeminiChatDatabase.instance.saveMessage(dbMsg);
    } catch (e) {
      debugPrint('Error saving message to SQLite: $e');
    }
  }

  CategoryEntity _resolveCategoryEntity(dynamic cat, [List<CategoryEntity>? categoriesList]) {
    if (cat is CategoryEntity) return cat;
    final List<CategoryEntity> categories = categoriesList ?? ref.read(categoryProvider);
    if (cat is String && cat.isNotEmpty) {
      final match = categories.where((c) => c.name.toLowerCase() == cat.toLowerCase());
      if (match.isNotEmpty) return match.first;
    }
    if (categories.isNotEmpty) return categories.first;
    return const CategoryEntity(
      id: 'default_cat',
      name: 'General',
      taskCount: 0,
      icon: Icons.category_rounded,
      color: Color(0xFF6366F1),
      backgroundColor: Color(0xFFEEF2FF),
      categoryColor: 0xFF6366F1,
      categoryBackgroundColor: 0xFFEEF2FF,
      categoryIcon: 0xe318,
    );
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result.isNotEmpty) {
        final file = result.first;
        if (file.path != null) {
          setState(() {
            _attachedPdfPath = file.path;
            _attachedPdfName = file.name;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick PDF: $e')),
      );
    }
  }

  final List<Map<String, dynamic>> _actions = [
    {'label': 'Create a task', 'icon': Icons.edit_note_rounded},
    {'label': 'Plan my day', 'icon': Icons.calendar_month_rounded},
    {'label': 'Suggest routine', 'icon': Icons.lightbulb_outline_rounded},
    {'label': 'Analyze progress', 'icon': Icons.insights_rounded},
  ];

  // ----------------------------------------------------------
  // COMMON HELPERS
  // ----------------------------------------------------------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _tasksLoaded() {
    if (!ref.read(taskProvider.notifier).hasLoadedTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tasks are still loading. Please try again.'),
        ),
      );
      return false;
    }

    return true;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

 //date
  DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;

    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }

    final parts = value.split('-');

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }

    return DateTime(year, month, day);
  }


  String? _normaliseTime(dynamic value) {
    if (value is! String) return null;

    final match = RegExp(
      r'^(1[0-2]|[1-9]):([0-5]\d)\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) return null;

    final hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final period = match.group(3)!.toUpperCase();

    return '$hour:$minute $period';
  }

  DateTime? _taskDateTime(TaskEntity task) {
    final time = _normaliseTime(task.time);

    if (time == null) return null;

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s(AM|PM)$',
    ).firstMatch(time);

    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
      hour,
      minute,
    );
  }

  String _buildTaskContext(List<TaskEntity> tasks) {
    final taskData = tasks.map((task) {
      return {
        'id': task.id,
        'title': task.title,
        'category': task.category,
        'date': _formatDate(task.scheduledDate),
        'time': task.time,
        'priority': task.priority,
        'completed': task.isCompleted,
        'repeat': task.repeat,
        'notes': task.notes,
      };
    }).toList();

    final completedCount =
        tasks.where((task) => task.isCompleted).length;

    return jsonEncode({
      'totalTasks': tasks.length,
      'completedTasks': completedCount,
      'pendingTasks': tasks.length - completedCount,
      'tasks': taskData,
    });
  }

  void _addAssistantMessage(String text, {String? pdfName, String? pdfPath}) {
    final msg = {
      'id': _uuid.v4(),
      'text': text,
      'isUser': false,
      'type': 'text',
      'pdfName': pdfName,
      'pdfPath': pdfPath,
    };
    setState(() {
      _messages.add(msg);
    });
    _saveMessageToDb(msg);
    _scrollToBottom();
  }

  void _addUserMessage(String text, {String? pdfName, String? pdfPath}) {
    final msg = {
      'id': _uuid.v4(),
      'text': text,
      'isUser': true,
      'type': 'text',
      'pdfName': pdfName,
      'pdfPath': pdfPath,
    };
    setState(() {
      _messages.add(msg);
    });
    _saveMessageToDb(msg);
    _scrollToBottom();
  }

  // ----------------------------------------------------------
  // NORMAL AI CHAT
  // ----------------------------------------------------------

  Future<void> _sendMessage([String? preset]) async {
    if (_isLoading) return;

    final text = (preset ?? _messageController.text).trim();

    if (text.isEmpty) return;
    if (!_tasksLoaded()) return;

    final tasks = ref.read(taskProvider);
    final taskContext = _buildTaskContext(tasks);

    _addUserMessage(text);

    setState(() {
      _isLoading = true;
    });

    _messageController.clear();
    FocusScope.of(context).unfocus();

    try {
      final history = _messages
          .where((m) => m['type'] == 'text' && m['text'] != null)
          .take(8)
          .map((m) => {
                'role': m['isUser'] == true ? 'user' : 'assistant',
                'text': m['text'].toString(),
              })
          .toList();

      final reply = await _geminiRepository.sendMessage(
        text,
        taskContext: taskContext,
        conversationHistory: history,
      );

      if (!mounted) return;

      _addAssistantMessage(reply);
    } catch (e, stackTrace) {
      debugPrint('Gemini Error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _addAssistantMessage(
        'Sorry, something went wrong with Gemini AI ($e). Please check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ----------------------------------------------------------
  // PDF DOCUMENT ANALYSIS
  // ----------------------------------------------------------

  Future<void> _sendPdfMessage(String userPrompt, String path, String name) async {
    final promptText = userPrompt.isNotEmpty
        ? userPrompt
        : 'Please analyze this document and summarize its key points and any action items.';

    _addUserMessage(promptText, pdfName: name, pdfPath: path);

    setState(() {
      _isLoading = true;
      _attachedPdfPath = null;
      _attachedPdfName = null;
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('The selected PDF file no longer exists.');
      }
      final bytes = await file.readAsBytes();

      if (_geminiRepository.isTaskCreationIntent(promptText)) {
        final availableCategories = ref.read(categoryProvider).map((c) => c.name).toList();
        final proposalData = await _geminiRepository.extractTaskProposalFromPdf(
          pdfBytes: bytes,
          userRequest: promptText,
          availableCategories: availableCategories,
          fileName: name,
        );
        final selectedCategory = ref
            .read(categoryProvider)
            .where((c) => c.name.toLowerCase() == proposalData['category'].toString().toLowerCase())
            .toList();
        final chosenCat = selectedCategory.isNotEmpty
            ? selectedCategory.first
            : _resolveCategoryEntity(proposalData['category']);

        final proposalMsg = {
          'id': _uuid.v4(),
          'isUser': false,
          'type': 'task_proposal',
          'title': proposalData['title'] ?? 'Review $name',
          'category': chosenCat,
          'date': proposalData['date'] ?? _formatDate(DateTime.now()),
          'time': proposalData['time'] ?? '7:00 PM',
          'priority': proposalData['priority'] ?? 'Medium',
          'notes': proposalData['notes'] ?? '',
          'status': 'pending',
          'pdfName': name,
          'pdfPath': path,
        };
        if (mounted) {
          setState(() {
            _messages.add(proposalMsg);
          });
          _saveMessageToDb(proposalMsg);
        }
      } else {
        final tasks = ref.read(taskProvider);
        final taskContext = _buildTaskContext(tasks);
        final reply = await _geminiRepository.analyzePdf(
          pdfBytes: bytes,
          prompt: promptText,
          fileName: name,
          taskContext: taskContext,
        );
        if (mounted) {
          _addAssistantMessage(reply, pdfName: name, pdfPath: path);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing PDF: $e\n$stackTrace');
      if (mounted) {
        _addAssistantMessage(
          'I could not process the attached PDF: $e. Please verify the file and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ----------------------------------------------------------
  // SEND BUTTON HANDLER
  // ----------------------------------------------------------

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();

    if (_isLoading) return;
    if (text.isEmpty && _attachedPdfPath == null) return;

    final attachedPath = _attachedPdfPath;
    final attachedName = _attachedPdfName;

    _messageController.clear();
    FocusScope.of(context).unfocus();

    if (attachedPath != null) {
      await _sendPdfMessage(text, attachedPath, attachedName ?? 'document.pdf');
    } else if (_isCreatingTask || _geminiRepository.isTaskCreationIntent(text)) {
      setState(() {
        _isCreatingTask = false;
      });
      await _createTaskProposal(text);
    } else {
      await _sendMessage(text);
    }
  }

  // ----------------------------------------------------------
  // CREATE TASK PROPOSAL
  // ----------------------------------------------------------

  Future<void> _createTaskProposal(String userRequest) async {
    if (_isLoading) return;

    final categories = ref.read(categoryProvider);

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a category first.'),
        ),
      );
      return;
    }

    _addUserMessage(userRequest);

    setState(() {
      _isLoading = true;
    });

    _messageController.clear();
    FocusScope.of(context).unfocus();

    try {
      final proposal = await _geminiRepository.generateTaskProposal(
        userRequest,
        availableCategories:
        categories.map((category) => category.name).toList(),
      );

      if (!mounted) return;

      final title = proposal['title'];
      final categoryName = proposal['category'];
      final date = proposal['date'];
      final time = proposal['time'];
      final priority = proposal['priority'];
      final notes = proposal['notes'];

      if (title is! String ||
          title.trim().isEmpty ||
          categoryName is! String ||
          date is! String ||
          time is! String ||
          priority is! String ||
          notes is! String) {
        throw Exception('Invalid task proposal.');
      }

      final selectedCategory = categories.where(
            (category) =>
        category.name.toLowerCase() ==
            categoryName.toLowerCase(),
      );

      if (selectedCategory.isEmpty) {
        throw Exception('Invalid category.');
      }

      final parsedDate = _parseDate(date);
      final parsedTime = _normaliseTime(time);

      if (parsedDate == null || parsedTime == null) {
        throw Exception('Invalid date or time.');
      }

      const validPriorities = ['Low', 'Medium', 'High'];

      final validPriority = validPriorities.firstWhere(
            (value) => value.toLowerCase() == priority.toLowerCase(),
        orElse: () => '',
      );

      if (validPriority.isEmpty) {
        throw Exception('Invalid priority.');
      }

      final proposalMap = {
        'id': _uuid.v4(),
        'isUser': false,
        'type': 'task_proposal',
        'title': title.trim(),
        'category': selectedCategory.first,
        'date': _formatDate(parsedDate),
        'time': parsedTime,
        'priority': validPriority,
        'notes': notes,
        'status': 'pending',
      };
      setState(() {
        _messages.add(proposalMap);
      });
      _saveMessageToDb(proposalMap);
    } catch (e, stackTrace) {
      debugPrint('TASK PROPOSAL ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _addAssistantMessage(
        'I could not prepare your task: $e. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ----------------------------------------------------------
  // PLAN MY DAY
  // ----------------------------------------------------------

  Future<void> _runPlanMyDay() async {
    if (_isLoading) return;
    if (!_tasksLoaded()) return;

    final tasks = ref.read(taskProvider);

    final pendingTasks =
    tasks.where((task) => !task.isCompleted).toList();

    _addUserMessage('Plan my day');

    if (pendingTasks.isEmpty) {
      _addAssistantMessage(
        'You have no pending tasks right now. Great work!',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pendingData = pendingTasks.map((task) {
        return {
          'id': task.id,
          'title': task.title,
          'category': task.category,
          'date': _formatDate(task.scheduledDate),
          'time': task.time,
          'priority': task.priority,
          'notes': task.notes,
        };
      }).toList();

      final suggestions =
      await _geminiRepository.generateDailySchedule(
        pendingTasks: pendingData,
        currentDateTime: DateTime.now(),
      );

      if (!mounted) return;

      final taskMap = {
        for (final task in pendingTasks) task.id: task,
      };

      final seenIds = <String>{};
      final validSuggestions = <Map<String, dynamic>>[];

      for (final suggestion in suggestions) {
        final id = suggestion['id']?.toString();

        if (id == null ||
            !taskMap.containsKey(id) ||
            seenIds.contains(id)) {
          continue;
        }

        final task = taskMap[id]!;

        if (task.isCompleted) continue;

        final date = _parseDate(suggestion['date']);
        final time = _normaliseTime(suggestion['time']);

        if (date == null || time == null) continue;

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (date.isBefore(todayDate)) continue;

        seenIds.add(id);

        validSuggestions.add({
          'task': task,
          'date': _formatDate(date),
          'time': time,
          'reason': suggestion['reason']?.toString() ??
              'Suggested based on your task priority.',
          'selected': true,
        });
      }

      if (validSuggestions.isEmpty) {
        _addAssistantMessage(
          'I could not prepare a valid schedule. Please try again.',
        );
        return;
      }

      final scheduleMsg = {
        'id': _uuid.v4(),
        'isUser': false,
        'type': 'schedule_proposal',
        'items': validSuggestions,
        'status': 'pending',
      };
      setState(() {
        _messages.add(scheduleMsg);
      });
      _saveMessageToDb(scheduleMsg);
    } catch (e, stackTrace) {
      debugPrint('PLAN MY DAY ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _addAssistantMessage(
        'I could not prepare your schedule: $e. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _confirmSchedule(
      Map<String, dynamic> proposal,
      ) async {
    if (proposal['status'] == 'saving' ||
        proposal['status'] == 'saved') {
      return;
    }

    final items =
    proposal['items'] as List<Map<String, dynamic>>;
// dublicate nhi hoga
    final selectedItems = items
        .where((item) =>
    item['selected'] == true &&
        item['saved'] != true)
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one task.'),
        ),
      );
      return;
    }
    final hasInvalidItem = selectedItems.any((item) {
      final task = item['task'] as TaskEntity;

      return _parseDate(item['date']) == null ||
          _normaliseTime(item['time']) == null ||
          task.isCompleted;
    });

    if (hasInvalidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some selected tasks have invalid date/time or are already completed. Please deselect them.',
          ),
        ),
      );
      return;
    }

    setState(() {
      proposal['status'] = 'saving';
    });

    int savedCount = 0;

    try {
      for (final item in selectedItems) {
        final task = item['task'] as TaskEntity;
        final date = _parseDate(item['date']);
        final time = _normaliseTime(item['time']);

        if (date == null || time == null || task.isCompleted) {
          throw StateError('Invalid schedule or completed task.');
        }

        final updatedTask = task.copyWith(
          scheduledDate: date,
          time: time,
        );

        await ref.read(taskProvider.notifier).updateTask(updatedTask);

        item['saved'] = true;
        savedCount++;
      }

      if (!mounted) return;

      setState(() {
        proposal['status'] =
        savedCount == selectedItems.length ? 'saved' : 'partial';
        proposal['savedCount'] = savedCount;
      });
      _saveMessageToDb(proposal);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount task schedule(s) updated.'),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('SCHEDULE UPDATE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        proposal['status'] =
        savedCount > 0 ? 'partial' : 'failed';
        proposal['savedCount'] = savedCount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$savedCount task(s) updated. Some updates failed.',
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // SUGGEST ROUTINE
  // ----------------------------------------------------------

  Future<void> _runSuggestRoutine() async {
    if (_isLoading) return;
    if (!_tasksLoaded()) return;

    final tasks = ref.read(taskProvider);
    final categories = ref.read(categoryProvider);

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a category first.'),
        ),
      );
      return;
    }

    _addUserMessage('Suggest routine');

    setState(() {
      _isLoading = true;
    });

    try {
      final taskData = tasks.map((task) {
        return {
          'id': task.id,
          'title': task.title,
          'category': task.category,
          'date': _formatDate(task.scheduledDate),
          'time': task.time,
          'priority': task.priority,
          'completed': task.isCompleted,
        };
      }).toList();

      final suggestions =
      await _geminiRepository.generateRoutineSuggestions(
        tasks: taskData,
        availableCategories:
        categories.map((category) => category.name).toList(),
      );

      if (!mounted) return;

      final routineItems = <Map<String, dynamic>>[];

      const validPriorities = ['Low', 'Medium', 'High'];

      for (final suggestion in suggestions.take(5)) {
        final title = suggestion['title']?.toString().trim() ?? '';
        final categoryName =
            suggestion['category']?.toString() ?? '';
        final date = _parseDate(suggestion['date']);
        final time = _normaliseTime(suggestion['time']);
        final notes = suggestion['notes']?.toString() ?? '';

        final priority = validPriorities.firstWhere(
              (value) =>
          value.toLowerCase() ==
              suggestion['priority']?.toString().toLowerCase(),
          orElse: () => 'Medium',
        );

        final category = categories.where(
              (item) =>
          item.name.toLowerCase() ==
              categoryName.toLowerCase(),
        );

        if (title.isEmpty ||
            date == null ||
            time == null ||
            category.isEmpty) {
          continue;
        }

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (date.isBefore(todayDate)) continue;

        routineItems.add({
          'title': title,
          'category': category.first,
          'date': _formatDate(date),
          'time': time,
          'priority': priority,
          'notes': notes,
          'selected': true,
        });
      }

      if (routineItems.isEmpty) {
        _addAssistantMessage(
          'I could not prepare valid routine suggestions. Please try again.',
        );
        return;
      }

      final routineMsg = {
        'id': _uuid.v4(),
        'isUser': false,
        'type': 'routine_proposal',
        'items': routineItems,
        'status': 'pending',
      };
      setState(() {
        _messages.add(routineMsg);
      });
      _saveMessageToDb(routineMsg);
    } catch (e, stackTrace) {
      debugPrint('ROUTINE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _addAssistantMessage(
        'I could not suggest a routine: $e. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _confirmRoutine(
      Map<String, dynamic> proposal,
      ) async {
    if (proposal['status'] == 'saving' ||
        proposal['status'] == 'saved') {
      return;
    }

    final items =
    proposal['items'] as List<Map<String, dynamic>>;

    final selectedItems = items
        .where((item) =>
    item['selected'] == true &&
        item['saved'] != true)
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one routine.'),
        ),
      );
      return;
    }
    final hasInvalidItem = selectedItems.any((item) {
      return _parseDate(item['date']) == null ||
          _normaliseTime(item['time']) == null;
    });

    if (hasInvalidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some routine tasks have invalid date or time. Please regenerate the routine.',
          ),
        ),
      );
      return;
    }

    setState(() {
      proposal['status'] = 'saving';
    });

    int savedCount = 0;

    try {
      for (final item in selectedItems) {
        final category = item['category'] as CategoryEntity;
        final date = _parseDate(item['date']);
        final time = _normaliseTime(item['time']);

        if (date == null || time == null) {
          throw StateError('Invalid routine date or time.');
        }

        item['taskId'] ??= _uuid.v4();

        final task = TaskEntity(
          id: item['taskId'],
        //  id: _uuid.v4(),
         // id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: item['title'],
          category: category.name,
          categoryColor: category.categoryColor,
          categoryBackgroundColor:
          category.categoryBackgroundColor,
          categoryIcon: category.categoryIcon,
          scheduledDate: date,
          time: time,
          priority: item['priority'],
          notes: item['notes'],
          reminderEnable: true,
          reminderMinutesBefore: 10,
          reminderTime: '10 minutes before',
          upcomingReminderEnabled: true,
          upcomingReminderMinutesBefore: 5,
          repeat: 'Never',
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        await ref.read(taskProvider.notifier).addTask(task);

        item['saved'] = true;
        savedCount++;
      }

      if (!mounted) return;

      setState(() {
        proposal['status'] =
        savedCount == selectedItems.length ? 'saved' : 'partial';
        proposal['savedCount'] = savedCount;
      });
      _saveMessageToDb(proposal);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount routine task(s) created.'),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('ROUTINE SAVE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        proposal['status'] = savedCount > 0 ? 'partial' : 'failed';
        proposal['savedCount'] = savedCount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$savedCount routine(s) saved. Some saves failed.',
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // ANALYZE PROGRESS
  // ----------------------------------------------------------

  Future<void> _runAnalyzeProgress() async {
    if (_isLoading) return;
    if (!_tasksLoaded()) return;

    final tasks = ref.read(taskProvider);

    _addUserMessage('Analyze progress');

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();

      final completed =
          tasks.where((task) => task.isCompleted).length;

      final pending =
          tasks.where((task) => !task.isCompleted).length;

      final overdue = tasks.where((task) {
        if (task.isCompleted) return false;

        final taskDate = _taskDateTime(task);

        return taskDate != null && taskDate.isBefore(now);
      }).length;

      final todayCount = tasks.where((task) {
        return !task.isCompleted &&
            task.scheduledDate.year == now.year &&
            task.scheduledDate.month == now.month &&
            task.scheduledDate.day == now.day;
      }).length;

      final highPriority = tasks.where((task) {
        return !task.isCompleted &&
            task.priority.toLowerCase() == 'high';
      }).length;

      final completionPercentage = tasks.isEmpty
          ? 0.0
          : (completed / tasks.length) * 100;

      // Statistics are calculated in Dart, not by Gemini.
      final summary = {
        'totalTasks': tasks.length,
        'completedTasks': completed,
        'pendingTasks': pending,
        'overdueTasks': overdue,
        'todayPendingTasks': todayCount,
        'highPriorityPendingTasks': highPriority,
        'completionPercentage':
        double.parse(completionPercentage.toStringAsFixed(1)),
      };

      final analysis = await _geminiRepository.analyzeProgress(
        progressSummary: jsonEncode(summary),
        taskContext: _buildTaskContext(tasks),
      );

      if (!mounted) return;

      final progressMsg = {
        'id': _uuid.v4(),
        'isUser': false,
        'type': 'progress_analysis',
        'stats': summary,
        'analysis': analysis,
      };
      setState(() {
        _messages.add(progressMsg);
      });
      _saveMessageToDb(progressMsg);
    } catch (e, stackTrace) {
      debugPrint('PROGRESS ANALYSIS ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _addAssistantMessage(
        'I could not analyze your progress: $e. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ----------------------------------------------------------
  // QUICK ACTION DISPATCHER
  // ----------------------------------------------------------

  void _onQuickAction(String label) {
    if (_isLoading) return;

    switch (label) {
      case 'Create a task':
        setState(() {
          _isCreatingTask = true;
          _messageController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Describe your task and tap Send.'),
          ),
        );
        break;

      case 'Plan my day':
        _runPlanMyDay();
        break;

      case 'Suggest routine':
        _runSuggestRoutine();
        break;

      case 'Analyze progress':
        _runAnalyzeProgress();
        break;
    }
  }

  // ----------------------------------------------------------
  // CREATE TASK CONFIRMATION
  // ----------------------------------------------------------

  Future<void> _confirmTaskProposal(
      Map<String, dynamic> proposal,
      ) async {
    if (proposal['status'] == 'saving' ||
        proposal['status'] == 'saved') {
      return;
    }

    try {
      final category = _resolveCategoryEntity(proposal['category']);
      proposal['category'] = category;
      final date = _parseDate(proposal['date']);
      final time = _normaliseTime(proposal['time']);

      if (date == null || time == null) {
        throw Exception('Invalid date or time.');
      }
      proposal['taskId'] ??= _uuid.v4();

      final task = TaskEntity(
        id: proposal['taskId'],
       // id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: proposal['title'],
        category: category.name,
        categoryColor: category.categoryColor,
        categoryBackgroundColor:
        category.categoryBackgroundColor,
        categoryIcon: category.categoryIcon,
        scheduledDate: date,
        time: time,
        priority: proposal['priority'],
        notes: proposal['notes'],
        reminderEnable: true,
        reminderMinutesBefore: 10,
        reminderTime: '10 minutes before',
        upcomingReminderEnabled: true,
        upcomingReminderMinutesBefore: 5,
        repeat: 'Never',
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      setState(() {
        proposal['status'] = 'saving';
      });

      await ref.read(taskProvider.notifier).addTask(task);

      if (!mounted) return;

      setState(() {
        proposal['status'] = 'saved';
      });
      _saveMessageToDb(proposal);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task successfully saved to Firebase!'),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('AI TASK SAVE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        proposal['status'] = 'failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task could not be saved. Please try again.'),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // SELECTION HANDLER
  // ----------------------------------------------------------

  void _toggleItemSelection(
      Map<String, dynamic> item,
      bool? value,
      ) {
    setState(() {
      item['selected'] = value ?? false;
    });
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TrackFlow AI Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.circle,
                  color: Color(0xFF10B981),
                  size: 8,
                ),
                const SizedBox(width: 5),
                Text(
                  'TrackFlow Gemini • Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Documents & PDFs',
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DocumentsPdfScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Options',
            icon: Icon(
              Icons.more_vert_rounded,
              color: colors.onSurfaceVariant,
            ),
            onSelected: (val) async {
              if (val == 'new_chat') {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final newSess = await GeminiChatDatabase.instance.createNewSession(user.uid);
                  setState(() {
                    _activeSessionId = newSess.id;
                    _messages.clear();
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Started a new chat session')),
                  );
                }
              } else if (val == 'clear_history') {
                if (_activeSessionId != null) {
                  await GeminiChatDatabase.instance.clearSessionMessages(_activeSessionId!);
                  setState(() {
                    _messages.clear();
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat history cleared')),
                  );
                }
              } else if (val == 'info') {
                _showInfo(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.add_comment_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('New Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_history',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Clear History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('About AI Assistant'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  _buildWelcome(),
                  const SizedBox(height: 22),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  ..._messages.map(_buildMessage),
                  if (_isLoading) _buildTypingIndicator(),
                ],
              ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // WELCOME
  // ----------------------------------------------------------

  Widget _buildWelcome() {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aiAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your personal productivity assistant',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Manage tasks, plan your day and build better habits. What would you like to do?',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // QUICK ACTIONS
  // ----------------------------------------------------------

  Widget _buildQuickActions() {
    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: _actions.map((action) {
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _isLoading
              ? null
              : () => _onQuickAction(action['label'] as String),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action['icon'] as IconData,
                  size: 17,
                  color: primary,
                ),
                const SizedBox(width: 7),
                Text(
                  action['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ----------------------------------------------------------
  // MESSAGE ROUTER
  // ----------------------------------------------------------

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool? ?? false;
    final type = message['type'];

    Widget content;

    if (type == 'task_proposal') {
      content = _buildTaskProposalCard(message);
    } else if (type == 'schedule_proposal') {
      content = _buildScheduleCard(message);
    } else if (type == 'routine_proposal') {
      content = _buildRoutineCard(message);
    } else if (type == 'progress_analysis') {
      content = _buildProgressCard(message);
    } else if (type == 'task') {
      content = _buildTaskCard(message);
    } else {
      final colors = Theme.of(context).colorScheme;

      final pdfPath = message['pdfPath'] as String?;
      final pdfName = message['pdfName'] as String?;

      content = Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? primary
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(isUser ? 17 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 17),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pdfPath != null)
              _buildPdfAttachmentTile(
                name: pdfName ?? 'document.pdf',
                path: pdfPath,
                isUser: isUser,
              ),
            Text(
              message['text'] as String? ?? '',
              style: TextStyle(
                color: isUser ? Colors.white : colors.onSurface,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _aiAvatar(),
            const SizedBox(width: 9),
          ],
          Flexible(child: content),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0x265146E5),
              child: Icon(
                Icons.person_rounded,
                size: 19,
                color: primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfAttachmentTile({
    required String name,
    required String path,
    required bool isUser,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isUser
            ? Colors.black.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: path,
                title: name,
              ),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUser ? Colors.white : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: isUser ? Colors.white70 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // TASK CARD
  // ----------------------------------------------------------

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['text'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  task['time'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_outline_rounded,
            color: primary,
            size: 21,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // PROPOSAL DETAIL ROW
  // ----------------------------------------------------------

  Widget _proposalDetail(
      IconData icon,
      String label,
      String value,
      ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: primary),
          const SizedBox(width: 9),
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // COMMON CARD DECORATION
  // ----------------------------------------------------------

  Widget _proposalContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // SCHEDULE PREVIEW CARD
  // ----------------------------------------------------------

  Widget _buildScheduleCard(Map<String, dynamic> proposal) {
    final colors = Theme.of(context).colorScheme;
    final items =
    proposal['items'] as List<Map<String, dynamic>>;
    final status = proposal['status'] as String;

    return _proposalContainer(
      title: 'Your Daily Schedule',
      icon: Icons.calendar_month_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select the tasks you want to reschedule:',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final task = item['task'] as TaskEntity;
            final selected = item['selected'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selected,
                    activeColor: primary,
                    onChanged: status == 'pending'
                        ? (value) =>
                        _toggleItemSelection(item, value)
                        : null,
                    title: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _proposalDetail(
                    Icons.calendar_today_outlined,
                    'Date',
                    item['date'],
                  ),
                  _proposalDetail(
                    Icons.access_time_rounded,
                    'Time',
                    item['time'],
                  ),
                  Text(
                    'Reason: ${item['reason']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          _buildProposalActions(
            status: status,
            onCancel: () {
              setState(() {
                proposal['status'] = 'cancelled';
              });
            },
            onConfirm: () => _confirmSchedule(proposal),
            savedText:
            '${proposal['savedCount'] ?? items.length} task schedule(s) updated.',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // ROUTINE PREVIEW CARD
  // ----------------------------------------------------------

  Widget _buildRoutineCard(Map<String, dynamic> proposal) {
    final colors = Theme.of(context).colorScheme;
    final items =
    proposal['items'] as List<Map<String, dynamic>>;
    final status = proposal['status'] as String;

    return _proposalContainer(
      title: 'Suggested Routine',
      icon: Icons.lightbulb_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose which routine tasks you want to add:',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final category = item['category'] as CategoryEntity;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: item['selected'] == true,
                    activeColor: primary,
                    onChanged: status == 'pending'
                        ? (value) =>
                        _toggleItemSelection(item, value)
                        : null,
                    title: Text(
                      item['title'],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _proposalDetail(
                    Icons.category_outlined,
                    'Category',
                    category.name,
                  ),
                  _proposalDetail(
                    Icons.calendar_today_outlined,
                    'Date',
                    item['date'],
                  ),
                  _proposalDetail(
                    Icons.access_time_rounded,
                    'Time',
                    item['time'],
                  ),
                  _proposalDetail(
                    Icons.flag_outlined,
                    'Priority',
                    item['priority'],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          _buildProposalActions(
            status: status,
            onCancel: () {
              setState(() {
                proposal['status'] = 'cancelled';
              });
            },
            onConfirm: () => _confirmRoutine(proposal),
            savedText:
            '${proposal['savedCount'] ?? items.length} routine task(s) created.',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // COMMON CONFIRM / CANCEL BUTTONS
  // ----------------------------------------------------------

  Widget _buildProposalActions({
    required String status,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    required String savedText,
  }) {
    if (status == 'saving') {
      return const Row(
        children: [
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Saving...'),
        ],
      );
    }

    if (status == 'saved') {
      return Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              savedText,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    if (status == 'cancelled') {
      return const Text(
        'Proposal cancelled. No changes made.',
        style: TextStyle(fontSize: 12),
      );
    }


    if (status == 'failed' || status == 'partial') {
      return Row(
        children: [
          Expanded(
            child: Text(
              status == 'partial'
                  ? 'Some tasks saved. Retry remaining?'
                  : 'Saving failed. Please try again.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            onPressed: onConfirm,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            onPressed: onConfirm,
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // PROGRESS ANALYSIS CARD
  // ----------------------------------------------------------

  Widget _buildProgressCard(Map<String, dynamic> message) {
    final stats = message['stats'] as Map<String, dynamic>;
    final analysis = message['analysis'] as String;

    return _proposalContainer(
      title: 'Your Productivity Report',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow('Total tasks', '${stats['totalTasks']}'),
          _statRow('Completed', '${stats['completedTasks']}'),
          _statRow('Pending', '${stats['pendingTasks']}'),
          _statRow('Overdue', '${stats['overdueTasks']}'),
          _statRow('Due today', '${stats['todayPendingTasks']}'),
          _statRow(
            'High priority pending',
            '${stats['highPriorityPendingTasks']}',
          ),
          const Divider(height: 22),
          Text(
            'Completion: ${stats['completionPercentage']}%',
            style: const TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (stats['completionPercentage'] as num)
                  .toDouble() /
                  100,
              minHeight: 8,
              backgroundColor: colorsForProgress(context),
              color: primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'AI Insights',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            analysis,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color colorsForProgress(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  Widget _statRow(String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // CREATE TASK PREVIEW CARD
  // ----------------------------------------------------------

  Widget _buildTaskProposalCard(Map<String, dynamic> proposal) {
    final colors = Theme.of(context).colorScheme;

    final category = proposal['category'] as CategoryEntity;
    final status = proposal['status'] as String;

    return _proposalContainer(
      title: 'Task Preview',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal['title'],
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _proposalDetail(
            Icons.category_outlined,
            'Category',
            category.name,
          ),
          _proposalDetail(
            Icons.calendar_today_outlined,
            'Date',
            proposal['date'],
          ),
          _proposalDetail(
            Icons.access_time_rounded,
            'Time',
            proposal['time'],
          ),
          _proposalDetail(
            Icons.flag_outlined,
            'Priority',
            proposal['priority'],
          ),
          if ((proposal['notes'] as String).trim().isNotEmpty)
            _proposalDetail(
              Icons.notes_rounded,
              'Notes',
              proposal['notes'],
            ),
          const SizedBox(height: 12),
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        proposal['status'] = 'cancelled';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _confirmTaskProposal(proposal),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            )
          else if (status == 'saving')
            const Text('Saving task...')
          else if (status == 'saved')
              const Text(
                'Task saved successfully!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (status == 'failed')
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Task save failed. Please retry.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _confirmTaskProposal(proposal),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else
                Text(
                  'Task proposal cancelled.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),

        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // TYPING INDICATOR
  // ----------------------------------------------------------

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _aiAvatar(),
          const SizedBox(width: 10),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          const Text('Thinking...'),
        ],
      ),
    );
  }

  Widget _buildAttachedPdfBar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _attachedPdfName ?? 'Attached PDF',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: 'View PDF',
            icon: const Icon(Icons.visibility_outlined, size: 18),
            onPressed: () {
              if (_attachedPdfPath != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      filePath: _attachedPdfPath!,
                      title: _attachedPdfName,
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              setState(() {
                _attachedPdfPath = null;
                _attachedPdfName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // INPUT
  // ----------------------------------------------------------

  Widget _buildInput() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachedPdfPath != null) _buildAttachedPdfBar(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach PDF Document',
                  onPressed: _pickPdf,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: _attachedPdfPath != null
                        ? primary
                        : colors.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                      ),
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: _attachedPdfPath != null
                            ? 'Ask Gemini about this PDF or summarize it...'
                            : _isCreatingTask
                                ? 'Describe the task you want to create...'
                                : 'Type your message...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: primary,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _isLoading ? null : _handleSend,
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // AI AVATAR
  // ----------------------------------------------------------

  Widget _aiAvatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: primary,
        size: 19,
      ),
    );
  }

  // ----------------------------------------------------------
  // INFO DIALOG
  // ----------------------------------------------------------

  void _showInfo(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'TrackFlow AI Assistant',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          'Your personal AI productivity assistant powered by Gemini.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
