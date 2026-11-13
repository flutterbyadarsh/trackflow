
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../Add_dummy_data/add_dummy_category.dart';
import '../data_model/Category_entity.dart';
import '../data_model/task_entity.dart';
import '../Statemanage_riverpod/provider/task_provider.dart';
import 'pdf_viewer_screen.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() =>
      _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  static const Color purple = Color(0xFF625CF6);

  bool isEditing = false;
  bool isCompleted = false;
  bool reminderEnabled = true;
  bool upcomingReminderEnabled = true;
  bool isPickingPdf = false;
  bool isSaving = false;
  bool isDeleting = false;

  String priority = 'Medium';
  String repeat = 'Never';

  int reminderMinutesBefore = 10;
  int upcomingReminderMinutesBefore = 5;

  late CategoryEntity selectedCategory;

  DateTime dueDate = DateTime.now();
  TimeOfDay taskTime = const TimeOfDay(hour: 19, minute: 0);

  String? pdfName;
  String? pdfPath;

  int categoryColor = 0xFF7C3AED;
  int categoryBackgroundColor = 0xFFEDE9FE;
  int categoryIcon = Icons.category_rounded.codePoint;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaskData();
  }

  void _loadTaskData() {
    final task = widget.task;

    titleController.text =
        (task['title'] ?? task['name'] ?? '').toString();

    final savedCategory =
    (task['categoryName'] ?? task['category'] ?? 'Personal')
        .toString();

    selectedCategory = dummyCategories.firstWhere(
          (category) => category.name == savedCategory,
      orElse: () => dummyCategories.first,
    );

    categoryController.text = savedCategory;

    categoryColor =
        (task['categoryColor'] as num?)?.toInt() ??
            selectedCategory.categoryColor;

    categoryBackgroundColor =
        (task['categoryBackgroundColor'] as num?)?.toInt() ??
            selectedCategory.categoryBackgroundColor;

    categoryIcon =
        (task['categoryIcon'] as num?)?.toInt() ??
            selectedCategory.categoryIcon;

    descriptionController.text =
        task['notes']?.toString() ??
            task['description']?.toString() ??
            '';

    isCompleted = task['isCompleted'] == true;

    priority = task['priority']?.toString() ?? 'Medium';

    reminderEnabled =
        task['reminderEnabled'] == true ||
            task['reminderEnable'] == true;

    reminderMinutesBefore =
        (task['reminderMinutesBefore'] as num?)?.toInt() ?? 10;

    upcomingReminderEnabled =
        task['upcomingReminderEnabled'] as bool? ?? true;

    upcomingReminderMinutesBefore =
        (task['upcomingReminderMinutesBefore'] as num?)?.toInt() ?? 5;

    const allowedRepeats = [
      'Never',
      'Daily',
      'Weekly',
      'Monthly',
    ];

    final repeatValue = task['repeat']?.toString() ?? 'Never';

    repeat = allowedRepeats.contains(repeatValue)
        ? repeatValue
        : 'Never';

    final dateValue = task['scheduledDate'] ?? task['dueDate'];

    if (dateValue is DateTime) {
      dueDate = dateValue;
    } else if (dateValue is String) {
      dueDate = DateTime.tryParse(dateValue) ?? DateTime.now();
    }

    final timeValue = task['time'];

    if (timeValue is TimeOfDay) {
      taskTime = timeValue;
    } else if (timeValue is String) {
      taskTime = _parseTaskTime(timeValue) ?? taskTime;
    }

    pdfName = task['pdfName']?.toString();
    pdfPath = task['pdfPath']?.toString();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTaskTime(String value) {
    final text = value.trim().toUpperCase();

    final twelveHour = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    ).firstMatch(text);

    if (twelveHour != null) {
      var hour = int.parse(twelveHour.group(1)!);
      final minute = int.parse(twelveHour.group(2)!);
      final period = twelveHour.group(3);

      if (hour < 1 || hour > 12 || minute > 59) return null;

      if (period == 'AM') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }

      return TimeOfDay(hour: hour, minute: minute);
    }

    final twentyFourHour = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(text);

    if (twentyFourHour != null) {
      final hour = int.parse(twentyFourHour.group(1)!);
      final minute = int.parse(twentyFourHour.group(2)!);

      if (hour > 23 || minute > 59) return null;

      return TimeOfDay(hour: hour, minute: minute);
    }

    return null;
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${months[dueDate.month - 1]} ${dueDate.day}, ${dueDate.year}';
  }

  String get formattedTime {
    final hour =
    taskTime.hourOfPeriod == 0 ? 12 : taskTime.hourOfPeriod;

    final minute = taskTime.minute.toString().padLeft(2, '0');

    final period =
    taskTime.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  DateTime get selectedTaskDateTime {
    return DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      taskTime.hour,
      taskTime.minute,
    );
  }

  String get reminderLabel {
    if (!reminderEnabled) {
      return 'Reminder is off';
    }

    if (reminderMinutesBefore == 60) {
      return '1 hour before';
    }

    return '$reminderMinutesBefore minute${reminderMinutesBefore == 1 ? '' : 's'} before';
  }

  String get upcomingReminderLabel {
    if (!upcomingReminderEnabled) {
      return 'Upcoming notification is off';
    }

    if (upcomingReminderMinutesBefore == 60) {
      return '1 hour before due time';
    }

    return '$upcomingReminderMinutesBefore minutes before due time';
  }

  Future<void> _selectDate() async {
    if (!isEditing) return;

    final selected = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: purple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => dueDate = selected);
    }
  }

  Future<void> _selectTime() async {
    if (!isEditing) return;

    final selected = await showTimePicker(
      context: context,
      initialTime: taskTime,
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: purple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => taskTime = selected);
    }
  }

  Future<void> _pickPdf() async {
    try {
      setState(() => isPickingPdf = true);

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => isPickingPdf = false);
        return;
      }

      final selectedFile = result.first;
      final sourcePath = selectedFile.path;

      if (sourcePath == null) {
        throw Exception('Could not access the selected PDF.');
      }

      final sourceFile = File(sourcePath);
      final appDirectory = await getApplicationDocumentsDirectory();

      final attachmentDirectory = Directory(
        p.join(appDirectory.path, 'task_attachments'),
      );

      await attachmentDirectory.create(recursive: true);

      final safeName = p.basename(selectedFile.name);

      final uniqueName =
          '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final destinationPath = p.join(
        attachmentDirectory.path,
        uniqueName,
      );

      final savedFile = await sourceFile.copy(destinationPath);

      if (!mounted) return;

      setState(() {
        pdfName = selectedFile.name;
        pdfPath = savedFile.path;
        isPickingPdf = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => isPickingPdf = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to attach PDF: $error'),
        ),
      );
    }
  }

  Future<void> _removePdf() async {
    final oldPath = pdfPath;

    setState(() {
      pdfName = null;
      pdfPath = null;
    });

    if (oldPath == null) return;

    try {
      final file = File(oldPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('PDF deletion error: $error');
    }
  }

  // Save task changes
  Future<void> _saveChanges() async {
    if (isSaving) return;

    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task title cannot be empty'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final taskId = widget.task['id']?.toString();

    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task ID is missing'),
        ),
      );

      return;
    }

    TaskEntity? existingTask;

    for (final task in ref.read(taskProvider)) {
      if (task.id == taskId) {
        existingTask = task;
        break;
      }
    }

    setState(() => isSaving = true);

    final updatedTask = TaskEntity(
      id: taskId,
      title: titleController.text.trim(),
      category: selectedCategory.name,
      categoryColor: categoryColor,
      categoryBackgroundColor: categoryBackgroundColor,
      categoryIcon: categoryIcon,
      scheduledDate: dueDate,
      time: formattedTime,
      priority: priority,

      reminderEnable: reminderEnabled,
      reminderMinutesBefore:
      reminderEnabled ? reminderMinutesBefore : 0,
      reminderTime: reminderEnabled ? reminderLabel : '',

      upcomingReminderEnabled: upcomingReminderEnabled,
      upcomingReminderMinutesBefore:
      upcomingReminderEnabled
          ? upcomingReminderMinutesBefore
          : 0,

      repeat: repeat,
      notes: descriptionController.text.trim(),
      isCompleted: isCompleted,
      pdfName: pdfName,
      pdfPath: pdfPath,
      folderId: widget.task['folderId'] as String?,
      folderName: widget.task['folderName'] as String?,

      createdAt: existingTask?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(taskProvider.notifier).updateTask(updatedTask);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update task: $error'),
        ),
      );
    }
  }

  // Toggle task completion
  Future<void> _markAsRead() async {
    if (isCompleted) {
      Navigator.pop(context);
      return;
    }

    try {
      await ref.read(taskProvider.notifier).toggleTaskCompletion(
        widget.task['id'].toString(),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update task: $error'),
        ),
      );
    }
  }

  // Delete task with confirmation
  // Delete task with confirmation
  Future<void> _deleteTask() async {
    if (isDeleting || isSaving) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task?'),
          content: const Text(
            'Are you sure you want to delete this task? '
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      isDeleting = true;
    });

    try {
      final taskId = widget.task['id']?.toString();

      if (taskId == null || taskId.isEmpty) {
        throw Exception('Task ID is missing');
      }

      // Delete task and cancel its scheduled reminders
      await ref.read(taskProvider.notifier).deleteTask(taskId);

      if (!mounted) return;

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete task: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  // Cancel edit and restore original values
  void _cancelEditing() {
    _loadTaskData();

    setState(() {
      isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final iconData = IconData(
      categoryIcon,
      fontFamily: 'MaterialIcons',
    );

    return Scaffold(
      backgroundColor: colors.surface,

      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colors.onSurface,
          ),
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Details',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Task information and reminders',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),

        actions: [
          if (!isEditing)
            IconButton(
              tooltip: 'Edit task',
              onPressed: () {
                setState(() => isEditing = true);
              },
              icon: const Icon(
                Icons.edit_outlined,
                color: purple,
              ),
            )
          else
            TextButton(
              onPressed: isSaving ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),

          children: [
            // Task information
            _card(
              context: context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Color(categoryBackgroundColor),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          iconData,
                          color: Color(categoryColor),
                          size: 25,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: isEditing
                            ? _textField(
                          context: context,
                          controller: titleController,
                          hint: 'Task title',
                          fontSize: 17,
                          bold: true,
                        )
                            : Text(
                          titleController.text,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _sectionLabel(context, 'Category'),

                  const SizedBox(height: 6),

                  if (isEditing)
                    DropdownButtonFormField<CategoryEntity>(
                      initialValue: selectedCategory,
                      dropdownColor: colors.surface,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colors.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: purple,
                          ),
                        ),
                      ),
                      items: dummyCategories.map((category) {
                        return DropdownMenuItem<CategoryEntity>(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                category.icon,
                                color: category.color,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          selectedCategory = value;
                          categoryController.text = value.name;
                          categoryColor = value.categoryColor;
                          categoryBackgroundColor =
                              value.categoryBackgroundColor;
                          categoryIcon = value.categoryIcon;
                        });
                      },
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          IconData(
                            categoryIcon,
                            fontFamily: 'MaterialIcons',
                          ),
                          color: Color(categoryColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedCategory.name,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  _sectionLabel(context, 'Description'),

                  const SizedBox(height: 6),

                  if (isEditing)
                    _textField(
                      context: context,
                      controller: descriptionController,
                      hint: 'Add a description...',
                      maxLines: 4,
                    )
                  else
                    Text(
                      descriptionController.text.isEmpty
                          ? 'No description added.'
                          : descriptionController.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Attachments
            _sectionLabel(context, 'Attachments'),

            const SizedBox(height: 10),

            _card(
              context: context,
              child: Column(
                children: [
                  if (pdfName != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: pdfPath != null
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(
                                    filePath: pdfPath!,
                                    title: pdfName,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Colors.red,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pdfName!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap to view PDF',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pdfPath != null)
                              IconButton(
                                tooltip: 'View PDF',
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PdfViewerScreen(
                                        filePath: pdfPath!,
                                        title: pdfName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (isEditing)
                              IconButton(
                                tooltip: 'Remove PDF',
                                onPressed: _removePdf,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'No PDF attached',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                  if (isEditing) ...[
                    Divider(
                      height: 24,
                      color: colors.outlineVariant,
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isPickingPdf ? null : _pickPdf,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          isPickingPdf ? 'Adding...' : 'Add PDF',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Date and time
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    label: 'Due date',
                    value: formattedDate,
                    onTap: _selectDate,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _infoCard(
                    context: context,
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: formattedTime,
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Priority
            _sectionLabel(context, 'Priority'),

            const SizedBox(height: 10),

            _card(
              context: context,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: ['Low', 'Medium', 'High'].map((item) {
                  final selected = priority == item;

                  return Expanded(
                    child: GestureDetector(
                      onTap: isEditing
                          ? () => setState(() => priority = item)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? purple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // Task Reminder
            _card(
              context: context,
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: colors.onSurfaceVariant,
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Reminder',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          reminderLabel,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),

                        if (isEditing && reminderEnabled)
                          DropdownButton<int>(
                            value: [1, 5, 10, 15, 30, 60]
                                .contains(reminderMinutesBefore)
                                ? reminderMinutesBefore
                                : 10,
                            dropdownColor: colors.surface,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 13,
                            ),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 1,
                                child: Text('1 minute'),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text('5 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 10,
                                child: Text('10 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 15,
                                child: Text('15 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1 hour'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  reminderMinutesBefore = value;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                  Switch(
                    value: reminderEnabled,
                    activeTrackColor: Colors.green,
                    onChanged: isEditing
                        ? (value) {
                      setState(() {
                        reminderEnabled = value;
                      });
                    }
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Upcoming Task
            _card(
              context: context,
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: colors.onSurfaceVariant,
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Task',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          upcomingReminderLabel,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),

                        if (isEditing && upcomingReminderEnabled)
                          DropdownButton<int>(
                            value: [1, 5, 10, 15, 30, 60]
                                .contains(
                                upcomingReminderMinutesBefore)
                                ? upcomingReminderMinutesBefore
                                : 5,
                            dropdownColor: colors.surface,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 13,
                            ),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 1,
                                child: Text('1 minute'),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text('5 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 10,
                                child: Text('10 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 15,
                                child: Text('15 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1 hour'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  upcomingReminderMinutesBefore = value;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                  Switch(
                    value: upcomingReminderEnabled,
                    activeTrackColor: Colors.green,
                    onChanged: isEditing
                        ? (value) {
                      setState(() {
                        upcomingReminderEnabled = value;
                      });
                    }
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Repeat
            _card(
              context: context,
              child: Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    color: colors.onSurfaceVariant,
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repeat',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Set a repeat schedule',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  DropdownButton<String>(
                    value: repeat,
                    dropdownColor: colors.surface,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                    ),
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Never',
                        child: Text('Never'),
                      ),
                      DropdownMenuItem(
                        value: 'Daily',
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: 'Weekly',
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: 'Monthly',
                        child: Text('Monthly'),
                      ),
                    ],
                    onChanged: isEditing
                        ? (value) {
                      if (value != null) {
                        setState(() => repeat = value);
                      }
                    }
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save / Mark as Read
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: isSaving || isDeleting
                    ? null
                    : isEditing
                    ? _saveChanges
                    : _markAsRead,
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: isSaving
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  isEditing
                      ? Icons.save_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  isSaving
                      ? 'Saving...'
                      : isEditing
                      ? 'Save Changes'
                      : 'Mark as Completed',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Delete button
            if (!isEditing) ...[
              const SizedBox(height: 12),

              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : _deleteTask,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isDeleting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    isDeleting ? 'Deleting...' : 'Delete Task',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Section heading
  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // Text field
  Widget _textField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    double fontSize = 14,
    bool bold = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: colors.onSurface,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: colors.onSurfaceVariant,
        ),
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: purple,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // Common card decoration
  Widget _card({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: child,
    );
  }

  // Date and time cards
  Widget _infoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isEditing ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: purple,
                size: 18,
              ),

              const SizedBox(height: 12),

              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),

              if (isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap to change',
                    style: TextStyle(
                      fontSize: 10,
                      color: purple,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
