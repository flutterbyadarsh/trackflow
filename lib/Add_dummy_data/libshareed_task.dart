/*
// ye use nhi ho rha abb
final List<Map<String, dynamic>> sharedTasks = [];

void addSharedTask(Map<String, dynamic> task) {
  sharedTasks.add({
    ...task,
    'title': (task['title'] ?? 'Untitled Task').toString(),
    'date': task['date'] is DateTime
        ? task['date']
        : DateTime.now(),
    'time': (task['time'] ?? 'No time').toString(),
    'color': task['color'] is Color
        ? task['color']
        : const Color(0xFF4F46E5),
    'icon': task['icon'] is IconData
        ? task['icon']
        : Icons.task_alt_rounded,

    // remainder ,  priority ,  category, task status

    // Category details
    'category': (task['category'] ?? 'Personal').toString(),
    'categoryName': (task['categoryName'] ?? 'Personal').toString(),
    'categoryColor': task['categoryColor'] is Color
        ? task['categoryColor']
        : const Color(0xFF4F46E5),

    // Priority
    'priority': (task['priority'] ?? 'Medium').toString(),

    // Reminder and repeat
    'reminder': (task['reminder'] ?? '10 minutes before').toString(),
    'reminderEnabled': task['reminderEnabled'] ?? true,
    'repeat': (task['repeat'] ?? 'Never').toString(),

    // Task status
    'isCompleted': task['isCompleted'] ?? false,
  });
}

 */