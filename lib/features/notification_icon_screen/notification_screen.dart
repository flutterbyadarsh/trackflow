

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Statemanage_riverpod/provider/notification_provider.dart';
import '../../data_model/notification_Entity.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final Color purple = const Color(0xFF625CF6);

  String selectedFilter = 'All';
  bool selectionMode = false;

  final Set<int> selectedNotifications = {};

  final List<String> filters = [
    'All',
    'Task Reminder',
    'Upcoming Task',
  ];

  // Convert Firestore notification type into display name.
  String displayNotificationType(String type) {
    switch (type) {
      case 'task_reminder':
        return 'Task Reminder';

      case 'upcoming_task':
        return 'Upcoming Task';



      default:
        return type;
    }
  }

  // Filter notifications.
  List<NotificationEntity> getFilteredNotifications(
      List<NotificationEntity> notifications,
      ) {
    if (selectedFilter == 'All') {
      return notifications;
    }

    return notifications.where((item) {
      return displayNotificationType(item.type) == selectedFilter;
    }).toList();
  }

  // Select or deselect one notification.
  void toggleSelection(int id) {
    setState(() {
      if (selectedNotifications.contains(id)) {
        selectedNotifications.remove(id);
      } else {
        selectedNotifications.add(id);
      }

      selectionMode = selectedNotifications.isNotEmpty;
    });
  }

  // Select all visible notifications.
  void selectAll(List<NotificationEntity> visibleNotifications) {
    setState(() {
      final visibleIds =
      visibleNotifications.map((item) => item.id).toSet();

      if (selectedNotifications.containsAll(visibleIds)) {
        selectedNotifications.removeAll(visibleIds);
      } else {
        selectedNotifications.addAll(visibleIds);
      }

      selectionMode = selectedNotifications.isNotEmpty;
    });
  }

  // Delete selected notifications.
  Future<void> deleteSelected() async {
    if (selectedNotifications.isEmpty) return;

    final idsToDelete = Set<int>.from(selectedNotifications);

    try {
      await ref
          .read(notificationProvider.notifier)
          .deleteNotifications(idsToDelete);

      if (!mounted) return;

      setState(() {
        selectedNotifications.clear();
        selectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected notifications deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete notifications: $error'),
        ),
      );
    }
  }

  // Delete one notification.
  Future<void> deleteSingleNotification(int id) async {
    try {
      await ref
          .read(notificationProvider.notifier)
          .deleteNotifications({id});

      if (!mounted) return;

      setState(() {
        selectedNotifications.remove(id);
        selectionMode = selectedNotifications.isNotEmpty;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete notification: $error'),
        ),
      );
    }
  }

  // Clear all notifications with confirmation.
  Future<void> clearAllNotifications() async {
    final notifications = ref.read(notificationProvider);

    if (notifications.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear All Notifications?'),
          content: const Text(
            'Are you sure you want to delete all notifications? '
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(notificationProvider.notifier).clearNotifications();

      if (!mounted) return;

      setState(() {
        selectedNotifications.clear();
        selectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to clear notifications: $error'),
        ),
      );
    }
  }

  // Mark all notifications as read.
  Future<void> markAllAsRead() async {
    final unreadNotifications = ref
        .read(notificationProvider)
        .where((item) => !item.isRead)
        .toList();

    if (unreadNotifications.isEmpty) return;

    try {
      await ref
          .read(notificationProvider.notifier)
          .markAllAsRead();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update notifications: $error'),
        ),
      );
    }
  }

  // Notification time.
  String getNotificationTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    return '${difference.inDays} days ago';
  }

  // Notification icons.
  IconData getNotificationIcon(String type) {
    switch (displayNotificationType(type)) {

      case 'Task Reminder':
        return Icons.notifications_active_rounded;


      case 'Upcoming Task':
        return Icons.access_time_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  // Notification colors.
  Color getNotificationColor(String type) {
    switch (displayNotificationType(type)) {


      case 'Task Reminder':
        return const Color(0xFF7C3AED);



      case 'Upcoming Task':
        return const Color(0xFFD97706);

      default:
        return purple;
    }
  }

  // Notification background colors.
  Color getNotificationBackground(String type) {
    switch (displayNotificationType(type)) {


      case 'Task Reminder':
        return const Color(0xFFEDE9FE);



      case 'Upcoming Task':
        return const Color(0xFFFEF3C7);

      default:
        return const Color(0xFFEDE9FE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Firestore stream data through Riverpod.
    final notifications = ref.watch(notificationProvider);

    final visibleNotifications =
    getFilteredNotifications(notifications);

    final allVisibleSelected = visibleNotifications.isNotEmpty &&
        visibleNotifications.every(
              (item) => selectedNotifications.contains(item.id),
        );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // APP BAR
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF252538),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (selectionMode) {
              setState(() {
                selectedNotifications.clear();
                selectionMode = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 24,
          ),
        ),
        title: Text(
          selectionMode
              ? '${selectedNotifications.length} Selected'
              : 'Notifications',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF252538),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Select all',
            onPressed: visibleNotifications.isEmpty
                ? null
                : () => selectAll(visibleNotifications),
            icon: Icon(
              allVisibleSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
            ),
          ),
          if (selectionMode)
            IconButton(
              tooltip: 'Delete selected',
              onPressed: selectedNotifications.isEmpty
                  ? null
                  : deleteSelected,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 24,
              ),
            ),
        ],
      ),

      body: Column(
        children: [
          // FILTER CHIPS
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;

                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      selectedFilter = filter;
                      selectedNotifications.clear();
                      selectionMode = false;
                    });
                  },
                  selectedColor: purple,
                  backgroundColor: theme.cardColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected ? purple : theme.dividerColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),

          // RECENT ACTIVITY HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(
              children: [
                TextButton(
                  onPressed: notifications.any((item) => !item.isRead)
                      ? markAllAsRead
                      : null,
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      color: purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: notifications.isEmpty || selectionMode
                      ? null
                      : clearAllNotifications,
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // NOTIFICATION LIST
          Expanded(
            child: visibleNotifications.isEmpty
                ? _emptyState(context)
                : ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 5,
              ),
              itemCount: visibleNotifications.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = visibleNotifications[index];

                final isSelected =
                selectedNotifications.contains(item.id);

                return _notificationCard(
                  context,
                  item,
                  isSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // NOTIFICATION CARD
  Widget _notificationCard(
      BuildContext context,
      NotificationEntity item,
      bool isSelected,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(item.id),

      direction: selectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,

      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
        ),
      ),

      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
        ),
      ),

      onDismissed: (_) {
        deleteSingleNotification(item.id);
      },

      child: GestureDetector(
        // Long press starts selection.
        onLongPress: () {
          if (!selectionMode) {
            toggleSelection(item.id);
          }
        },

        // Normal tap marks as read.
        onTap: () async {
          if (selectionMode) {
            toggleSelection(item.id);
          } else if (!item.isRead) {
            try {
              await ref
                  .read(notificationProvider.notifier)
                  .markAsRead(item.id);
            } catch (error) {
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Unable to mark as read: $error'),
                ),
              );
            }
          }
        },

        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isSelected
                ? purple.withOpacity(isDark ? 0.25 : 0.12)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? purple : theme.dividerColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SELECTION CHECK ICON
              if (selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: isSelected ? purple : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // NOTIFICATION ICON
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: getNotificationBackground(item.type),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  getNotificationIcon(item.type),
                  color: getNotificationColor(item.type),
                  size: 23,
                ),
              ),

              const SizedBox(width: 13),

              // NOTIFICATION DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Text(
                      getNotificationTime(item.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),

              // NEW NOTIFICATION DOT
              if (!item.isRead && !selectionMode)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 5),
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: purple,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // EMPTY STATE
  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 65,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),

          const SizedBox(height: 15),

          Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'No notifications right now.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
