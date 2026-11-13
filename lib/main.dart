import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:trackflow/firebase_options.dart';

import 'Statemanage_riverpod/auth services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firebase App Check
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider(
            debugToken: '986F3F0E-9817-4FC0-B300-28F1D6F204B1',
          )
        : const AndroidPlayIntegrityProvider(),
  );


  // Firestore Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Google Sign-In initialization
  await GoogleSignIn.instance.initialize(
    serverClientId:
    '322978352826-g1cd1leull3ktup85nrb0b7c1lho3cna.apps.googleusercontent.com',
  );

  // Local Notification initialization
  await NotificationService.initialize();

  // Run app
  runApp(
    const ProviderScope(
      child: TrackFlow(),
    ),
  );
}

//62159A58-61FF-4639-817E-5DF138860E33