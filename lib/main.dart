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
    await MessagingService().initialize();

    // Stage 1.2: start listening for remote configuration. These are
    // backend/data-layer only — no new screens are rendered from them
    // yet, but the dashboard, branding, and feature-gating repositories
    // stay warm from app launch so future UI work can just read them.
    FeatureFlagService.instance.start();
    BrandingService.instance.start();
    DashboardConfigService.instance.start();
    // Stage 3.5: the Learning Materials uploader (and any other
    // feature queuing through UploadEngine) needs live remote size/type
    // limits from launch, not just when a screen happens to open one.
    UploadEngine.instance.start();
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
}
