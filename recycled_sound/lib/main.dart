import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_bootstrap.dart';
import 'firebase_options.dart';

/// Mount the UI as fast as possible so the diagnostic boot screen replaces
/// the blank iOS launch storyboard within a frame, then run Firebase init in
/// parallel. The boot screen awaits [AppBootstrap.ready] before advancing.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppBootstrap.start(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  });

  runApp(const ProviderScope(child: RecycledSoundApp()));
}
