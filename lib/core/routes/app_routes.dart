import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/jamb/jamb_dashboard_screen.dart';
import '../../features/waec/waec_dashboard_screen.dart';
import '../../features/neco/neco_dashboard_screen.dart';
import '../../features/cbt/cbt_screen.dart';
import '../../features/university/university_dashboard_screen.dart';

/// Central route table. Every new top-level screen — including future
/// modules (Marketplace, Scholarships, etc.) — is registered here
/// rather than navigated to via raw MaterialPageRoute elsewhere.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';

  // Stage 4.1 — real destinations for Home dashboard tiles that don't
  // have a dedicated module yet, so they land on an honest "coming
  // soon" screen instead of silently reusing the Learning Library.
  static const String jamb = '/jamb';
  static const String waec = '/waec';
  static const String neco = '/neco';
  static const String cbt = '/cbt';

  // Stage 4.4 — the real University module, replacing the Stage 4.1
  // stand-in that pointed the "University" dashboard tile straight at
  // the Learn tab.
  static const String university = '/university';

  static Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    home: (_) => const HomeShell(),
    jamb: (_) => const JambDashboardScreen(),
    waec: (_) => const WaecDashboardScreen(),
    neco: (_) => const NecoDashboardScreen(),
    cbt: (_) => const CbtScreen(),
    university: (_) => const UniversityDashboardScreen(),
  };
}
