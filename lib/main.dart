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

  // Stage 3.6.6: these don't need to block the first frame — they're
  // network-dependent (FCM token fetch, remote config) and were
  // previously awaited before runApp(), which held the splash screen
  // behind them and caused a multi-second blank-screen launch delay.
  // The splash screen has its own fixed display duration, so these
  // still have time to finish warming up behind it.
  try {
    await MessagingService().initialize();
    FeatureFlagService.instance.start();
    BrandingService.instance.start();
    DashboardConfigService.instance.start();
    UploadEngine.instance.start();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Post-launch service init failed: $e');
    }
  }
}
