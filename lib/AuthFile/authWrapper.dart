import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trackflow/AuthFile/screenFile/screens/splash_screen.dart'; // Apni splash import karo

import '../Screen_file/Dashboard_screen.dart';
import '../AuthFile/screenFile/screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Jab tak Firebase check kar raha hai, tab tak stunning SplashScreen dikhao!
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;

        if (user != null) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
