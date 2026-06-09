// File generated from the Firebase console web config for project
// managementsystem-5dd61. Equivalent to FlutterFire CLI output.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '$defaultTargetPlatform. Re-run flutterfire configure to add it.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBFnJ3M4qJPRtM_zu-NUMK3QKWNiKswXGE',
    appId: '1:420761174006:web:f0f74c74d18aad06aad1d7',
    messagingSenderId: '420761174006',
    projectId: 'managementsystem-5dd61',
    authDomain: 'managementsystem-5dd61.firebaseapp.com',
    storageBucket: 'managementsystem-5dd61.firebasestorage.app',
    measurementId: 'G-TT7E7RPM4N',
  );
}
