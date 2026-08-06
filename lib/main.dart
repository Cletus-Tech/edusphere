import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/config/branding_service.dart';
import 'services/config/dashboard_config_service.dart';
import 'services/config/feature_flag_service.dart';
import 'services/firebase/firebase_options.dart';
import 'services/firebase/messaging_service.dart';
import 'services/upload/upload_engine.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Stage 1 safeguard: don't let a missing/placeholder Firebase config
    // crash the whole app during design review — log and continue so
    // UI-only screens (splash, onboarding, theming) remain testable.
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const EduSphereApp(),
    ),
  );

  // None of this blocks the first frame. MessagingService in particular
  // requests notification permission and fetches an FCM token over the
  // network — awaiting it before runApp() was the actual cause of the
  // multi-second delay before the splash screen ever appeared. Firebase
  // itself is already initialized above, so Auth/Firestore calls from
  // SplashScreen or anywhere else remain safe to make immediately.
  unawaited(() async {
    try {
      await MessagingService().initialize();
      FeatureFlagService.instance.start();
      BrandingService.instance.start();
      DashboardConfigService.instance.start();
      UploadEngine.instance.start();
    } catch (e) {
      if (kDebugMode) debugPrint('Background service init failed: $e');
    }
  }());
}
