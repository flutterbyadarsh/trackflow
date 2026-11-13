
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data_model/notification_Entity.dart';

class NotificationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw Exception('User not logged in');
    }

    return _db.collection('users').doc(uid).collection('notifications');
  }

  // Watch only active notifications.
  Stream<List<NotificationEntity>> watchNotifications() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];

        return NotificationEntity(
          id: int.tryParse(doc.id) ?? 0,
          type: data['type'] as String? ?? '',
          title: data['title'] as String? ?? '',
          message: data['message'] as String? ?? '',
          createdAt: createdAt is Timestamp
              ? createdAt.toDate()
              : DateTime.now(),
          isRead: data['isRead'] as bool? ?? false,
          isDeleted: data['isDeleted'] as bool? ?? false,
        );
      })
          .where((notification) => !notification.isDeleted)
          .toList();
    });
  }

  // Add a new notification.

  Future<void> addNotification(
      NotificationEntity notification,
      ) async {
    final document = _collection.doc(notification.id.toString());

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      // Create only if this ID has never existed.
      if (!snapshot.exists) {
        transaction.set(document, {
          'type': notification.type,
          'title': notification.title,
          'message': notification.message,
          'createdAt': Timestamp.fromDate(notification.createdAt),
          'isRead': notification.isRead,
          'isDeleted': false,
        });
      }
    });
  }


  // Create only when document does not already exist.
  Future<void> createReminderIfMissing({
    required int id,
    required String type,
    required String title,
    required String message,
    required DateTime createdAt,
  }) async {
    final document = _collection.doc(id.toString());

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        transaction.set(document, {
          'type': type,
          'title': title,
          'message': message,
          'createdAt': Timestamp.fromDate(createdAt),
          'isRead': false,
          'isDeleted': false,
        });
      }
    });
  }

  // Mark one notification as read.
  Future<void> markAsRead(int id) async {
    await _collection.doc(id.toString()).update({
      'isRead': true,
    });
  }

  // Mark all visible unread notifications as read.
  Future<void> markAllAsRead(
      List<NotificationEntity> notifications,
      ) async {
    final unread = notifications.where(
          (item) => !item.isRead && !item.isDeleted,
    );

    final batch = _db.batch();

    for (final notification in unread) {
      batch.update(
        _collection.doc(notification.id.toString()),
        {'isRead': true},
      );
    }

    await batch.commit();
  }

  // Soft delete: keep document in Firestore.
  Future<void> deleteNotifications(Set<int> ids) async {
    if (ids.isEmpty) return;

    final batch = _db.batch();

    for (final id in ids) {
      batch.update(
        _collection.doc(id.toString()),
        {
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  // Clear all currently visible notifications.
  Future<void> clearNotifications(
      List<NotificationEntity> notifications,
      ) async {
    final ids = notifications.map((item) => item.id).toSet();

    await deleteNotifications(ids);
  }
}
