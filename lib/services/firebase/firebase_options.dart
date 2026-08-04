// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Stage 2 audit note: the `android` block below now mirrors the real
/// `android/app/google-services.json` (project `edusphere-ab1d1`), so
/// Android builds initialize against the real Firebase project.
///
/// `ios` and `web` are still PLACEHOLDER — no `GoogleService-Info.plist`
/// (iOS) or web app config was provided in this project, so those two
/// blocks will fail to initialize until you run, from the project root:
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// This regenerates this file with real values for every platform you
/// select. Do NOT ship the `ios`/`web` blocks below as-is.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform. '
          'Run `flutterfire configure` to generate them.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'edusphere-app',
    authDomain: 'edusphere-app.firebaseapp.com',
    storageBucket: 'edusphere-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC3antQmwf0cUcv8KL3FSIxNzvKHUWhwGo',
    appId: '1:857282447466:android:09ba229605d5ff0ca56213',
    messagingSenderId: '857282447466',
    projectId: 'edusphere-ab1d1',
    storageBucket: 'edusphere-ab1d1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'edusphere-app',
    storageBucket: 'edusphere-app.appspot.com',
    iosBundleId: 'com.edusphere.app',
  );
}
