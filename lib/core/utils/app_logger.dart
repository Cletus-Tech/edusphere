import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// The single logging entry point for EduSphere.
///
/// Every `print()`/`debugPrint()` scattered across services and screens
/// should be replaced with a call here instead. Debug-level logs are
/// automatically silenced in release builds (see [_shouldLog]); error
/// logs always print, so crash reports and support requests can be
/// diagnosed from a release build's console/crashlytics feed.
///
/// This does not itself talk to Firebase Crashlytics/Analytics — it's a
/// thin, swappable façade. When Crashlytics/Analytics packages are added
/// in a later stage, wire them into [AppLogger.error] and
/// [AppLogger.analytics] without touching any call site.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // Debug/verbose logs are dropped entirely in release builds so they
    // never leak into a shipped app's console output.
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  /// General debug information. Disabled in release builds.
  static void debug(String message, {String? tag}) {
    if (!_shouldLog) return;
    _logger.d(_withTag(message, tag));
  }

  /// Informational, non-error events worth tracing (e.g. "upload
  /// started", "feature flag changed").
  static void info(String message, {String? tag}) {
    if (!_shouldLog) return;
    _logger.i(_withTag(message, tag));
  }

  /// Recoverable problems that aren't full errors (e.g. a retried
  /// network call, a fallback path taken).
  static void warning(String message, {String? tag, Object? error}) {
    _logger.w(_withTag(message, tag), error: error);
  }

  /// Errors — always logged, even in release builds, so real user-facing
  /// failures are never silently dropped.
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _logger.e(_withTag(message, tag), error: error, stackTrace: stackTrace);
    // TODO(stage-2): forward to Firebase Crashlytics once added to pubspec.
  }

  /// Firebase-originated events (Auth/Firestore/Storage/Messaging state
  /// changes) — kept as its own category so they're easy to filter.
  static void firebase(String message, {Object? error}) {
    if (error != null) {
      _logger.w(_withTag(message, 'firebase'), error: error);
    } else if (_shouldLog) {
      _logger.i(_withTag(message, 'firebase'));
    }
  }

  /// Analytics-style events (screen views, taps, conversions). Swappable
  /// to forward to Firebase Analytics later without changing call sites.
  static void analytics(String eventName, {Map<String, Object?>? params}) {
    if (!_shouldLog) return;
    _logger.i(_withTag('$eventName ${params ?? const {}}', 'analytics'));
    // TODO(stage-2): forward to FirebaseAnalytics.instance.logEvent(...).
  }

  static bool get _shouldLog => !kReleaseMode;

  static String _withTag(String message, String? tag) => tag == null ? message : '[$tag] $message';
}
