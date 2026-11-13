
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  final Future<void> Function() pauseSync;
  final Future<void> Function(String uid) clearLocalData;
  final Future<void> Function() cancelNotifications;

  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    required this.pauseSync,
    required this.clearLocalData,
    required this.cancelNotifications,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No signed-in user found.');
    }

    final uid = user.uid;

    // Stop background sync before deleting data.
    await pauseSync();

    // Delete user's Firestore collections.
    await _deleteCollection('tasks', uid);
    await _deleteCollection('notes', uid);
    await _deleteCollection('noteFolders', uid);
    await _deleteCollection('notifications', uid);

    // Clear only this user's local database records.
    await clearLocalData(uid);

    // Cancel local scheduled notifications.
    await cancelNotifications();

    // Delete parent user document.
    await _firestore.collection('users').doc(uid).delete();

    // Firebase Auth account must be deleted LAST.
    await user.delete();
  }

  Future<void> _deleteCollection(
      String collectionName,
      String uid,
      ) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection(collectionName);

    while (true) {
      final snapshot = await collection.limit(400).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();
    }
  }
}
