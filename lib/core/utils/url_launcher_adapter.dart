import 'package:url_launcher/url_launcher.dart' as launcher;

/// Thin seam over `package:url_launcher` so [SmartLinksService] depends
/// on a small interface instead of the plugin directly — keeps the
/// plugin swappable and the smart-links logic testable.
class UrlLauncherAdapter {
  Future<bool> canLaunch(Uri uri) => launcher.canLaunchUrl(uri);

  /// Attempts to launch [uri]. When [preferNativeApp] is true, tries to
  /// hand off to an installed native app (App Links/Universal Links);
  /// when false, falls back to the platform's default external handler
  /// (usually the browser). Returns false — rather than throwing — if
  /// nothing could handle the link.
  Future<bool> launch(Uri uri, {required bool preferNativeApp}) async {
    final canOpen = await launcher.canLaunchUrl(uri);
    if (!canOpen) return false;
    try {
      return await launcher.launchUrl(
        uri,
        mode: preferNativeApp
            ? launcher.LaunchMode.externalNonBrowserApplication
            : launcher.LaunchMode.externalApplication,
      );
    } catch (_) {
      // No app registered for `externalNonBrowserApplication` on this
      // platform — let the caller fall back to the browser instead.
      return false;
    }
  }
}
