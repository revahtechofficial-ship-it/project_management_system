import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/pwa_install.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Entry point: pre-run initialization before runApp (AGENTS.md §1).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Capture the browser's PWA install prompt early (web only; no-op elsewhere).
  initPwaInstall();
  // ProviderScope is the root of the Riverpod graph.
  runApp(const ProviderScope(child: RevahApp()));
}
