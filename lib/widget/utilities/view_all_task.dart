
import 'package:flutter/material.dart';
import '../../features/Task_detail_screen.dart';
import '../todays_card.dart';

class ViewAllTasksScreen extends StatefulWidget {
final List<Map<String, dynamic>> tasks;

const ViewAllTasksScreen({
super.key,
required this.tasks,
});

@override
State<ViewAllTasksScreen> createState() =>
_ViewAllTasksScreenState();
}

class _ViewAllTasksScreenState extends State<ViewAllTasksScreen> {
  static const Color primaryColor = Color(0xFF4F46E5);

  final TextEditingController _searchController =
  TextEditingController();

  String _selectedFilter = 'All';
  String _searchQuery = '';

  List<Map<String, dynamic>> get _tasks => widget.tasks;

  int get _totalCount => _tasks.length;

  int get _pendingCount =>
      _tasks
          .where((task) => task['isCompleted'] != true)
          .length;

  int get _completedCount =>
      _tasks
          .where((task) => task['isCompleted'] == true)
          .length;

  List<Map<String, dynamic>> get _filteredTasks {
    return _tasks.where((task) {
      final title = (task['title'] ?? '').toString();

      final matchesSearch =
      title.toLowerCase().contains(_searchQuery.toLowerCase());

      final isCompleted = task['isCompleted'] == true;

      final matchesFilter = switch (_selectedFilter) {
        'Pending' => !isCompleted,
        'Completed' => isCompleted,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _taskTitle(Map<String, dynamic> task) {
    return (task['title'] ?? 'Untitled Task').toString();
  }

  String _taskCategory(Map<String, dynamic> task) {
    return (task['categoryName'] ?? task['category'] ?? 'General')
        .toString();
  }

  Color _taskColor(Map<String, dynamic> task) {
    final value = task['categoryColor'];

    if (value is Color) return value;
    if (value is int) return Color(value);

    return primaryColor;
  }

  IconData _taskIcon(Map<String, dynamic> task) {
    final value = task['categoryIcon'];

    if (value is IconData) return value;

    if (value is int) {
      return IconData(
        value,
        fontFamily: 'MaterialIcons',
      );
    }

    return Icons.task_alt_rounded;
  }

  void _toggleTask(Map<String, dynamic> task, bool value) {
    setState(() {
      task['isCompleted'] = value;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filteredTasks = _filteredTasks;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
// Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'All Tasks',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

// Search bar
              TextField(
                controller: _searchController,
                style: TextStyle(color: colors.onSurface),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colors.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

// Filter chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('All', _totalCount),
                  _filterChip('Pending', _pendingCount),
                  _filterChip('Completed', _completedCount),
                ],
              ),

              const SizedBox(height: 20),

// Section heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Tasks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    '${filteredTasks.length} tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

// Task list
              Expanded(
                child: filteredTasks.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 48,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tasks found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];

                    return TodaysCard(
                      title: _taskTitle(task),
                      time: task['time']?.toString() ?? '',
                      categoryColor: _taskColor(task),
                      categoryIcon: _taskIcon(task),
                      categoryName: _taskCategory(task),
                      priority:
                      task['priority']?.toString() ?? 'Medium',
                      reminderEnabled:
                      task['reminderEnabled'] == true,
                      reminderTime:
                      task['reminderTime']?.toString() ?? '',
                      isCompleted:
                      task['isCompleted'] == true,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TaskDetailScreen(
                                  task: Map<String, dynamic>.from(task),
                                ),
                          ),
                        );

                        if (!mounted) return;

                        setState(() {});
                      },
                      onChanged: (value) {
                        _toggleTask(task, value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int count) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final selected = _selectedFilter == label;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: primaryColor,
      backgroundColor: colors.surface,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? primaryColor
              : colors.outlineVariant,
        ),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
