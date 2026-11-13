import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../Statemanage_riverpod/provider/task_provider.dart';
import '../data_model/task_entity.dart';
import '../widget/todays_card.dart';
import 'AddTaskScreen.dart';
import 'Task_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() =>
      _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime selectedDate = DateTime.now();
  DateTime visibleMonth = DateTime.now();

//  static const Color purple = Color(0xFF4F46E5);

  Future<void> addTaskFromScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTaskScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool isPastDate(DateTime date) {
    return dateOnly(date).isBefore(dateOnly(DateTime.now()));
  }

  List<TaskEntity> getSelectedTasks(List<TaskEntity> allTasks) {
    return allTasks.where((task) {
      return sameDay(task.scheduledDate, selectedDate);
    }).toList();
  }

  bool hasTasksOn(List<TaskEntity> allTasks, DateTime date) {
    return allTasks.any((task) {
      return sameDay(task.scheduledDate, date);
    });
  }

  void goToToday() {
    setState(() {
      selectedDate = DateTime.now();
      visibleMonth = DateTime.now();
    });
  }

  void changeMonth(int difference) {
    setState(() {
      visibleMonth = DateTime(
        visibleMonth.year,
        visibleMonth.month + difference,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final lavender = colors.primary;

    final allTasks = ref.watch(taskProvider);
    final selectedTasks = getSelectedTasks(allTasks);

    final firstDay = DateTime(
      visibleMonth.year,
      visibleMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;

    // Sunday = 0, Monday = 1, ... Saturday = 6.
    final offset = firstDay.weekday % 7;
    final daysCount = offset + daysInMonth;
    final rows = (daysCount / 7).ceil();

    return Scaffold(
      backgroundColor: colors.surface,

      // App bar
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Taskly Calendar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add task',
            onPressed: addTaskFromScreen,
            icon: Icon(
              Icons.add_rounded,
              color: lavender,
            ),
          ),
          IconButton(
            tooltip: 'Go to today',
            onPressed: goToToday,
            icon: Icon(
              Icons.today_rounded,
              color: lavender,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Month navigation
          Row(
            children: [
              IconButton(
                onPressed: () => changeMonth(-1),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: colors.onSurface,
                ),
              ),

              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(visibleMonth),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),

              IconButton(
                onPressed: () => changeMonth(1),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Calendar grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Week days
                Row(
                  children: [
                    ...['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map(
                          (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Dates
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows * 7,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    if (index < offset ||
                        index >= offset + daysInMonth) {
                      return const SizedBox.shrink();
                    }

                    final day = index - offset + 1;

                    final date = DateTime(
                      visibleMonth.year,
                      visibleMonth.month,
                      day,
                    );

                    final isSelected = sameDay(date, selectedDate);
                    final isToday = sameDay(date, DateTime.now());
                    final isPast = isPastDate(date);
                    final hasTasks = hasTasksOn(allTasks, date);

                    return InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        setState(() {
                          selectedDate = date;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? lavender
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(
                            color: lavender,
                            width: 1.5,
                          )
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : isPast
                                        ? colors.onSurfaceVariant
                                        : colors.onSurface,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                if (hasTasks)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white
                                          : lavender,
                                    ),
                                  ),
                              ],
                            ),

                            if (isPast)
                              const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFEF4444),
                                size: 27,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Selected date heading
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('d MMMM yyyy').format(selectedDate),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ),

              Text(
                '${selectedTasks.length} tasks',
                style:  TextStyle(
                  color: lavender,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tasks for selected date
          if (selectedTasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 32,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: lavender.withValues(alpha: 0.7),
                    size: 38,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'No tasks for this date.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Choose another date to view its tasks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...selectedTasks.map((task) {
              return TodaysCard(
                title: task.title,
                time: task.time,
                categoryColor: Color(task.categoryColor),
                categoryIcon: IconData(
                  task.categoryIcon,
                  fontFamily: 'MaterialIcons',
                ),
                categoryName: task.category,
                priority: task.priority,
                reminderEnabled: task.reminderEnable,
                reminderTime: task.reminderTime,
                isCompleted: task.isCompleted,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(
                        task: {
                          'id': task.id,
                          'title': task.title,
                          'category': task.category,
                          'categoryName': task.category,
                          'categoryColor': task.categoryColor,
                          'categoryBackgroundColor':
                          task.categoryBackgroundColor,
                          'categoryIcon': task.categoryIcon,
                          'scheduledDate': task.scheduledDate,
                          'time': task.time,
                          'priority': task.priority,
                          'reminderEnabled': task.reminderEnable,
                          'reminderMinutesBefore':
                          task.reminderMinutesBefore,
                          'reminderTime': task.reminderTime,
                          'repeat': task.repeat,
                          'notes': task.notes,
                          'isCompleted': task.isCompleted,
                          'pdfName': task.pdfName,
                          'pdfPath': task.pdfPath,
                          'folderId': task.folderId,
                          'folderName': task.folderName,
                        },
                      ),
                    ),
                  );
                },

                onChanged: (value) {
                  ref
                      .read(taskProvider.notifier)
                      .toggleTaskCompletion(task.id);
                },
              );
            }),
        ],
      ),
    );
  }
}