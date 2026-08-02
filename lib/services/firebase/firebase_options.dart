// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// PLACEHOLDER — this file must be regenerated for your real Firebase
/// project before running the app. Do NOT ship these dummy keys.
///
/// From the project root, run:
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// This will overwrite this file with real values for Android, iOS,
/// and Web, wired to your Firebase project.
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
