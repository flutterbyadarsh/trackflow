import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:trackflow/Screen_file/profile_card.dart';
import 'package:trackflow/features/AddTaskScreen.dart';
import 'package:trackflow/features/Category_Screen.dart';
import 'package:trackflow/notes/Notes_Screen.dart';

import '../Statemanage_riverpod/provider/notification_provider.dart';
import '../Statemanage_riverpod/provider/task_provider.dart';
import '../features/Ai _Assistant_screen.dart';

import '../features/Task_detail_screen.dart';
import '../features/calender_screen.dart';
import '../features/documents_pdf_screen.dart';
import '../features/notification_icon_screen/notification_screen.dart';
import '../widget/progress_card.dart';
import '../widget/task_filterchips.dart';
import '../widget/todays_card.dart';
import '../widget/utilities/view_all_task.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Filter chip
  String selectedFilter = 'All';

  // greaating + name
  final now = DateTime.now();
  late final hour = now.hour;

  late final String greeting = hour < 12
      ? 'Good Morning'
      : hour < 17
      ? 'Good Afternoon'
      : hour < 21
      ? 'Good Evening'
      : 'Good Night';

// Fetch logged-in user
  final user = FirebaseAuth.instance.currentUser;

  late final String userName =
  user?.displayName?.trim().isNotEmpty == true
      ? user!.displayName!.trim()
      : user?.email?.split('@').first ?? 'User';

 // static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _primaryColor = Color(0xFF8061B2);

  @override
  Widget build(BuildContext context) {

   // final allTasks = ref.watch(taskProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Get tasks from Riverpod
    final allTasks = ref.watch(taskProvider);
    final notifications = ref.watch(notificationProvider);

    final unreadCount = notifications
        .where((notification) => !notification.isRead)
        .length;

    final now = DateTime.now();

    // Filter today's tasks and convert TaskEntity into Map
    final List<Map<String, dynamic>> todayTasks = allTasks
        .where((task) {
      final isToday =
          task.scheduledDate.year == now.year &&
              task.scheduledDate.month == now.month &&
              task.scheduledDate.day == now.day;

      final matchesCategory = selectedFilter == 'All' ||
          task.category.toLowerCase() ==
              selectedFilter.toLowerCase();

      return isToday && matchesCategory;
    })
        .map((task) => {
      'id': task.id,
      'title': task.title,
      'time': task.time,
      'category': task.category,
      'categoryName': task.category,
      'categoryColor': task.categoryColor,
      'categoryBackgroundColor':
      task.categoryBackgroundColor,
      'categoryIcon': task.categoryIcon,
      'priority': task.priority,
      'reminderEnabled': task.reminderEnable,
      'reminderMinutesBefore':
      task.reminderMinutesBefore,
      'reminderTime': task.reminderTime,
      'scheduledDate': task.scheduledDate,
      'repeat': task.repeat,
      'notes': task.notes,
      'isCompleted': task.isCompleted,
      'pdfName': task.pdfName,
      'pdfPath': task.pdfPath,
      'folderId': task.folderId,
      'folderName': task.folderName,
    })
        .toList();

    final completedCount = todayTasks
        .where((task) => task['isCompleted'] == true)
        .length;

    final totalCount = todayTasks.length;

    final date = DateFormat('EEE, MMM d').format(now);

    // --------------------------------------------------------
    // Bottom Navigation Item
    // --------------------------------------------------------

    Widget navItem(
        IconData icon,
        String label, {
          required bool isSelected,
          required VoidCallback onTap,
        }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: isSelected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --------------------------------------------------------
    // Dashboard UI
    // --------------------------------------------------------

    return Scaffold(
      backgroundColor: colors.surface,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              Text(
                date,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),

              // Greeting + Notification + Profile
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Expanded(
                    child: Text(
                      '$greeting\n$userName 👋',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ),

                  // Notification
                  // Notification with unread badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationScreen(),
                          ),
                        );
                      },
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 28,
                            color: colors.onSurface,
                          ),

                          if (unreadCount > 0)
                            Positioned(
                              right: -9,
                              top: -7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colors.surfaceContainerHighest,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Documents & PDFs
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Documents & PDFs',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentsPdfScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 26,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Profile
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const ProfileScreen(),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.primary,
                      child: Icon(
                        Icons.person,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Category Filter Chips
              TaskFilterChips(
                selectedFilter: selectedFilter,
                onFilterSelected: (filter) {
                  setState(() {
                    selectedFilter = filter;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Scrollable Dashboard Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Card
                      ProgressCard(
                        completedTasks: completedCount,
                        totalTasks: totalCount,
                      ),

                      const SizedBox(height: 12),

                      // Today's Tasks Heading
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Tasks",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ViewAllTasksScreen(
                                        tasks: todayTasks,
                                      ),
                                ),
                              );
                            },
                            child: Text(
                              'View all (${todayTasks.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Today's Task Cards
                      if (todayTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                          ),
                          child: Center(
                            child: Text(
                              'No tasks for today. Add a task!',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...todayTasks.map((task) {
                          final categoryColorValue =
                          task['categoryColor'] as int?;

                          final categoryIconValue =
                          task['categoryIcon'] as int?;

                          return TodaysCard(
                            title: task['title']?.toString() ??
                                'Untitled Task',

                            time: task['time']?.toString() ?? '',

                            categoryColor: Color(
                              categoryColorValue ?? 0xFF625CF6,
                            ),

                            categoryIcon: IconData(
                              categoryIconValue ?? 0xe318,
                              fontFamily: 'MaterialIcons',
                            ),

                            categoryName:
                            task['categoryName']?.toString() ?? '',

                            priority:
                            task['priority']?.toString() ?? 'Medium',

                            reminderEnabled:
                            task['reminderEnabled'] == true,

                            reminderTime:
                            task['reminderTime']?.toString() ?? '',

                            isCompleted:
                            task['isCompleted'] == true,

                            // Open Task Detail
                            onTap: () async  {
                              final result = await
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaskDetailScreen(
                                    task: Map<String, dynamic>.from(task),
                                  ),
                                ),
                              );
                              if (!context.mounted) return;

                                if (result == true) {
                              ScaffoldMessenger.of(context)
                               ..hideCurrentSnackBar()
                                   ..showSnackBar(
                              const SnackBar(
                               content: Text('Task updated successfully!'),
                               behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                                 ),
                                );
                           }
                            },

                            // Toggle Task Completion
                            onChanged: (value) {
                              ref
                                  .read(taskProvider.notifier)
                                  .toggleTaskCompletion(
                                task['id'].toString(),
                              );
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ------------------------------------------------------
      // Floating Add Task Button
      // ------------------------------------------------------
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 12),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => const AddTaskScreen(),
              ),
            );

            if (!context.mounted) return;

            if (result == true) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Task added successfully!'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
            }
          },
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
          extendedIconLabelSpacing: 6,
          tooltip: 'Add Task',
          icon: const Icon(
            Icons.add_rounded,
            size: 16,
          ),
          label: const Text('Add Task'),
        ),
      ),

      // ------------------------------------------------------
      // Bottom Navigation Bar
      // ------------------------------------------------------

      bottomNavigationBar: BottomAppBar(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home
            navItem(
              Icons.home_rounded,
              'Home',
              isSelected: true,
              onTap: () {},
            ),

            // Calendar
            navItem(
              Icons.calendar_month_rounded,
              'Calendar',
              isSelected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalendarScreen(),
                  ),
                );
              },
            ),

            // Notes
            navItem(
              Icons.note_alt_outlined,
              'Notes',
              isSelected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NoteScreen(),
                  ),
                );
              },
            ),

            // Categories
            navItem(
              Icons.category_rounded,
              'Categories',
              isSelected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryScreen(),
                  ),
                );
              },
            ),

            // Assistant
            navItem(
              Icons.auto_awesome,
              'Assistant',
              isSelected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const AiAssistantScreen(),
                  ),
                );
              },
            ),
          ],

        ),
      ),
    );
  }
}