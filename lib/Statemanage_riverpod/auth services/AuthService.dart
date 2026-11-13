
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'acc_deletion_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Google Login + Save Profile in Firestore
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount googleUser =
    await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final OAuthCredential credential =
    GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential =
    await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user != null) {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': '',
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return userCredential;
  }

  // Email Login
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Email Signup
  Future<UserCredential> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      final userName = name.trim();

      await user.updateDisplayName(userName);

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': userName,
        'email': user.email,
        'phone': '',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return credential;
  }

  // Forgot Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // Reauthenticate with Email and Password
  Future<void> reauthenticateWithPassword({
    required String password,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw Exception('Email address not found.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Reauthenticate with Google
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final googleUser = await _googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Authentication State
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Delete Account
  Future<void> deleteAccount({
    required bool useGoogle,
    String? password,
    required Future<void> Function() pauseSync,
    required Future<void> Function(String uid) clearLocalData,
    required Future<void> Function() cancelNotifications,
  }) async {
    // Step 1: Reauthenticate user.
    if (useGoogle) {
      await reauthenticateWithGoogle();
    } else {
      if (password == null || password.isEmpty) {
        throw Exception('Password is required.');
      }

      await reauthenticateWithPassword(password: password);
    }

    // Step 2: Create deletion service.
    final deletionService = AccountDeletionService(
      pauseSync: pauseSync,
      clearLocalData: clearLocalData,
      cancelNotifications: cancelNotifications,
    );

    // Step 3: Delete cloud and local account data.
    await deletionService.deleteAccount();

    // Step 4: Sign out Google session if applicable.
    if (useGoogle) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint(
          'Google sign-out after account deletion failed: $e',
        );
      }
    }
  }
}
