

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../Statemanage_riverpod/provider/category_provider.dart';
import '../Statemanage_riverpod/provider/task_provider.dart';
import '../data_model/Category_entity.dart';
import '../data_model/task_entity.dart';
import '../widget/utilities/categoryGrid.dart';
import '../widget/utilities/date_time_tile.dart';
import '../widget/utilities/dropdown.dart';
import '../widget/utilities/priority_selector.dart';
import '../widget/utilities/task_input_decoration.dart';
import 'pdf_viewer_screen.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  static const Color purple = Color(0xFF7C3AED);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  // noti
  bool upcomingReminderEnabled = true;
  String selectedUpcomingReminder = '5 minutes before';

  String? selectedCategoryId;

  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  TimeOfDay selectedTime = TimeOfDay.now();

  String? _pdfName;
  String? _pdfPath;

  bool _isPickingPdf = false;
  bool _isSaving = false;

  String selectedPriority = 'Medium';
  String selectedReminder = '10 minutes before';
  String selectedRepeat = 'Never';

  bool reminderEnabled = true;

  DateTime get selectedTaskDateTime {
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // PDF PICKER
  // ----------------------------------------------------------

  Future<void> _pickPdf() async {
    if (_isPickingPdf || _isSaving) return;

    setState(() => _isPickingPdf = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() => _isPickingPdf = false);
        return;
      }

      final selectedFile = result.first;
      final sourcePath = selectedFile.path;

      if (sourcePath == null) {
        throw Exception('Unable to access selected PDF.');
      }

      final appDirectory = await getApplicationDocumentsDirectory();

      final attachmentDirectory = Directory(
        p.join(appDirectory.path, 'task_attachments'),
      );

      await attachmentDirectory.create(recursive: true);

      final uniqueName =
          '${DateTime.now().microsecondsSinceEpoch}_${p.basename(selectedFile.name)}';

      final destinationPath = p.join(
        attachmentDirectory.path,
        uniqueName,
      );

      final savedFile = await File(sourcePath).copy(destinationPath);

      if (!mounted) return;

      setState(() {
        _pdfName = selectedFile.name;
        _pdfPath = savedFile.path;
        _isPickingPdf = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF attached successfully'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isPickingPdf = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to attach PDF: $error'),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // REMOVE PDF
  // ----------------------------------------------------------

  Future<void> _removePdf() async {
    final path = _pdfPath;

    setState(() {
      _pdfName = null;
      _pdfPath = null;
    });

    if (path != null) {
      try {
        final file = File(path);

        if (await file.exists()) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('PDF delete error: $error');
      }
    }
  }

  // ----------------------------------------------------------
  // FORMATTED DATE
  // ----------------------------------------------------------

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${selectedDate.day} '
        '${months[selectedDate.month - 1]} '
        '${selectedDate.year}';
  }

  // ----------------------------------------------------------
  // FORMATTED TIME
  // ----------------------------------------------------------

  String get formattedTime {
    final hour = selectedTime.hourOfPeriod == 0
        ? 12
        : selectedTime.hourOfPeriod;

    final minute = selectedTime.minute.toString().padLeft(2, '0');

    final period =
    selectedTime.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  // ----------------------------------------------------------
  // DATE PICKER
  // ----------------------------------------------------------

  Future<void> _selectDate() async {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: today,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select task date',
      builder: (context, child) {
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

    if (date != null && mounted) {
      setState(() {
        selectedDate = DateUtils.dateOnly(date);
      });
    }
  }

  // ----------------------------------------------------------
  // TIME PICKER
  // ----------------------------------------------------------

  Future<void> _selectTime() async {
    final theme = Theme.of(context);

    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      helpText: 'Select task time',
      builder: (context, child) {
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

    if (time != null && mounted) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  // ----------------------------------------------------------
  // REMINDER DURATION
  // ----------------------------------------------------------

  int _reminderMinutes(String reminder) {
    switch (reminder) {
      case '1 minute before':
        return 1;
      case '5 minutes before':
        return 5;
      case '10 minutes before':
        return 10;
      case '15 minutes before':
        return 15;
      case '30 minutes before':
        return 30;
      case '1 hour before':
        return 60;
      default:
        return 10;
    }
  }

  // upcoming reaminder
  int _upcomingReminderMinutes(String reminder) {
    switch (reminder) {
      case '1 minute before':
        return 1;
      case '5 minutes before':
        return 5;
      case '10 minutes before':
        return 10;
      case '15 minutes before':
        return 15;
      case '30 minutes before':
        return 30;
      case '1 hour before':
        return 60;
      default:
        return 5;
    }
  }

  // ----------------------------------------------------------
  // NOTIFICATION ID
  // ----------------------------------------------------------

  int notificationIdFromTaskId(String taskId) {
    var hash = 0;

    for (final codeUnit in taskId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return hash == 0 ? 1 : hash;
  }

  // ----------------------------------------------------------
  // SAVE TASK
  // ----------------------------------------------------------
  Future<void> _saveTaskUI() async {
    if (_isSaving || _isPickingPdf) return;

    if (!_formKey.currentState!.validate()) return;

    final categories = ref.read(categoryProvider);

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a category first'),
        ),
      );
      return;
    }

    // Prevent saving a task with a past date/time.
    final taskDateTime = selectedTaskDateTime;

    if (!taskDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future date and time'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final selectedCategory = categories.firstWhere(
            (category) => category.id == selectedCategoryId,
        orElse: () => categories.first,
      );

      final now = DateTime.now();
      final taskId = now.microsecondsSinceEpoch.toString();

      final task = TaskEntity(
        id: taskId,
        title: _titleController.text.trim(),
        category: selectedCategory.name,

        categoryColor: selectedCategory.categoryColor,
        categoryBackgroundColor:
        selectedCategory.categoryBackgroundColor,
        categoryIcon: selectedCategory.categoryIcon,

        scheduledDate: DateUtils.dateOnly(selectedDate),
        time: formattedTime,

        priority: selectedPriority,
        // chnage
        // Task Reminder
        reminderEnable: reminderEnabled,
        reminderMinutesBefore: reminderEnabled
            ? _reminderMinutes(selectedReminder)
            : 0,
        reminderTime: reminderEnabled ? selectedReminder : '',

       // Upcoming Task Reminder
        upcomingReminderEnabled: upcomingReminderEnabled,
        upcomingReminderMinutesBefore: upcomingReminderEnabled
            ? _upcomingReminderMinutes(selectedUpcomingReminder)
            : 0,



        repeat: selectedRepeat,
        notes: _notesController.text.trim(),

        isCompleted: false,

        pdfName: _pdfName,
        pdfPath: _pdfPath,

        folderId: null,
        folderName: null,

        createdAt: now,
        updatedAt: now,
      );

      // Save task through Riverpod.
      await ref.read(taskProvider.notifier).addTask(task);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Task save error: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save task: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  // ----------------------------------------------------------
  // SECTION TITLE
  // ----------------------------------------------------------

  Widget _sectionTitle(String title) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: colors.onSurface,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // COMMON CONTAINER DECORATION
  // ----------------------------------------------------------

  BoxDecoration _boxDecoration() {
    final colors = Theme.of(context).colorScheme;

    return BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: colors.outlineVariant,
      ),
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final categories = ref.watch(categoryProvider);

    final CategoryEntity? selectedCategory = categories.isEmpty
        ? null
        : categories.firstWhere(
          (category) => category.id == selectedCategoryId,
      orElse: () => categories.first,
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
            Icons.arrow_back_ios_new_rounded,
            color: colors.onSurface,
          ),
        ),
        title: Text(
          'Add Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                'Add New Task',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 24),

              // Task title
              _sectionTitle('Task title'),

              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: colors.onSurface),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
                decoration: TaskInputDecoration.build(
                  context: context,
                  hint: 'What do you need to do?',
                  icon: Icons.edit_note_rounded,
                ),
              ),

              const SizedBox(height: 20),

              // Attachments
              _sectionTitle('Attachments'),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: _boxDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.red,
                            size: 26,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attach PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add notes, study material or documents',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        OutlinedButton(
                          onPressed: _isPickingPdf || _isSaving
                              ? null
                              : _pickPdf,
                          child: Text(
                            _isPickingPdf ? 'Adding...' : 'Choose',
                          ),
                        ),
                      ],
                    ),

                    if (_pdfName != null) ...[
                      const SizedBox(height: 14),

                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pdfPath != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewerScreen(
                                      filePath: _pdfPath!,
                                      title: _pdfName,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.red,
                                size: 28,
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pdfName!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to preview',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_pdfPath != null)
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PdfViewerScreen(
                                          filePath: _pdfPath!,
                                          title: _pdfName,
                                        ),
                                      ),
                                    );
                                  },
                                  tooltip: 'Preview PDF',
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                ),

                              IconButton(
                                onPressed: _isSaving ? null : _removePdf,
                                tooltip: 'Remove PDF',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category
              _sectionTitle('Category'),

              if (categories.isEmpty)
                Text(
                  'No categories available. Please add a category.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                CategoryGrid(
                  categories: categories,
                  selectedCategory: selectedCategory!,
                  onCategorySelected: (category) {
                    setState(() {
                      selectedCategoryId = category.id;
                    });
                  },
                ),

              const SizedBox(height: 22),

              // Date and time
              _sectionTitle('Date & Time'),

              Row(
                children: [
                  Expanded(
                    child: dateTimeTile(
                      context: context,
                      icon: Icons.calendar_month_rounded,
                      label: 'Date',
                      value: formattedDate,
                      onTap: _selectDate,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: dateTimeTile(
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

              // Reminder
              _sectionTitle('Reminder'),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: _boxDecoration(),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Enable reminder',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      value: reminderEnabled,
                      activeColor: purple,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                        setState(() {
                          reminderEnabled = value;
                        });
                      },
                    ),

                    if (reminderEnabled) ...[
                      Divider(
                        height: 1,
                        color: colors.outlineVariant,
                      ),

                      const SizedBox(height: 10),

                      buildDropdown(
                        context: context,
                        value: selectedReminder,
                        items: const [
                          '1 minute before',
                          '5 minutes before',
                          '10 minutes before',
                          '15 minutes before',
                          '30 minutes before',
                          '1 hour before',
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedReminder = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              //
              // Upcoming Task Reminder
              _sectionTitle('Upcoming Task Reminder'),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: _boxDecoration(),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Enable upcoming task reminder',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      value: upcomingReminderEnabled,
                      activeColor: purple,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                        setState(() {
                          upcomingReminderEnabled = value;
                        });
                      },
                    ),
                    if (upcomingReminderEnabled) ...[
                      Divider(
                        height: 1,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: 10),
                      buildDropdown(
                        context: context,
                        value: selectedUpcomingReminder,
                        items: const [
                          '1 minute before',
                          '5 minutes before',
                          '10 minutes before',
                          '15 minutes before',
                          '30 minutes before',
                          '1 hour before',
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedUpcomingReminder = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const SizedBox(height: 22),

              // Repeat
              _sectionTitle('Repeat'),

              buildDropdown(
                context: context,
                value: selectedRepeat,
                items: const [
                  'Never',
                  'Daily',
                  'Weekly',
                  'Monthly',
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedRepeat = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              // Priority
              _sectionTitle('Priority'),

              PrioritySelector(
                selectedPriority: selectedPriority,
                onPrioritySelected: (priority) {
                  setState(() {
                    selectedPriority = priority;
                  });
                },
              ),

              const SizedBox(height: 22),

              // Notes
              _sectionTitle('Notes (optional)'),

              TextFormField(
                controller: _notesController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: colors.onSurface),
                decoration: TaskInputDecoration.build(
                  context: context,
                  hint: 'Add some details...',
                  icon: Icons.notes_rounded,
                ).copyWith(
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),

              // Streak card
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: purple.withAlpha(15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: purple.withAlpha(35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: purple,
                      size: 32,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep your streak going!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colors.onSurface,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Small steps every day lead to big results.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom save button
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant,
              ),
            ),
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving || _isPickingPdf
                  ? null
                  : _saveTaskUI,
              icon: _isSaving
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Task',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
