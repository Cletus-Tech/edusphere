import '../utils/app_logger.dart';
import '../utils/result.dart';
import 'smart_link_type.dart';
import 'url_launcher_adapter.dart';

/// Recognizes and opens every link type EduSphere's backend can send:
/// phone, WhatsApp, email, SMS, Facebook, Instagram, YouTube, TikTok,
/// X/Twitter, LinkedIn, Telegram, Google Maps, and general websites.
///
/// Nothing here hardcodes a destination — every value passed to
/// [open] comes from Firestore-backed configuration (a contact item's
/// `value`, a payment method's support link, a branding social link,
/// etc.). This service only classifies *how* to open a value the
/// backend already supplied.
///
/// Strategy: rather than fragile custom URI schemes per social app
/// (which break across app versions/platforms), this always builds a
/// standard `https://`/`tel:`/`mailto:`/`sms:` URI. Android App Links
/// and iOS Universal Links mean the OS opens the installed native app
/// automatically for supported hosts (wa.me, instagram.com, etc.);
/// [openExternal] falls back to the browser/handler chooser otherwise.
class SmartLinksService {
  SmartLinksService._();
  static final SmartLinksService instance = SmartLinksService._();

  final UrlLauncherAdapter _launcher = UrlLauncherAdapter();

  /// Best-effort classification of a raw backend value. Prefer passing
  /// an explicit `type` from the backend's own `action` field (e.g. a
  /// [ContactItemModel.action]) when one exists — this is a fallback
  /// for free-form values.
  SmartLinkType detect(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return SmartLinkType.unknown;

    if (value.startsWith('mailto:') || _emailPattern.hasMatch(value)) {
      return SmartLinkType.email;
    }
    if (value.startsWith('tel:') || _phonePattern.hasMatch(value)) {
      return SmartLinkType.phone;
    }
    if (value.startsWith('sms:')) return SmartLinkType.sms;

    final lower = value.toLowerCase();
    if (lower.contains('wa.me') || lower.contains('whatsapp.com')) return SmartLinkType.whatsapp;
    if (lower.contains('facebook.com') || lower.contains('fb.com')) return SmartLinkType.facebook;
    if (lower.contains('instagram.com')) return SmartLinkType.instagram;
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return SmartLinkType.youtube;
    if (lower.contains('tiktok.com')) return SmartLinkType.tiktok;
    if (lower.contains('twitter.com') || lower.contains('x.com')) return SmartLinkType.twitter;
    if (lower.contains('linkedin.com')) return SmartLinkType.linkedin;
    if (lower.contains('t.me') || lower.contains('telegram.me')) return SmartLinkType.telegram;
    if (lower.contains('maps.google') || lower.contains('goo.gl/maps') || value.startsWith('geo:')) {
      return SmartLinkType.googleMaps;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) return SmartLinkType.website;

    return SmartLinkType.unknown;
  }

  bool isValid(String raw, SmartLinkType type) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    switch (type) {
      case SmartLinkType.email:
        return _emailPattern.hasMatch(value.replaceFirst('mailto:', ''));
      case SmartLinkType.phone:
      case SmartLinkType.whatsapp:
      case SmartLinkType.sms:
        return _phonePattern.hasMatch(value.replaceAll(RegExp(r'^(tel:|sms:|whatsapp:)'), ''));
      case SmartLinkType.unknown:
        return false;
      default:
        // Social/web/maps links: must at least look like a URL once we
        // build it — validated for real in [_buildUri].
        return true;
    }
  }

  /// Builds the URI actually handed to the OS. Returns null for
  /// invalid/unrecognized input so callers can show a friendly error
  /// instead of attempting to launch garbage.
  Uri? _buildUri(String raw, SmartLinkType type) {
    final value = raw.trim();

    switch (type) {
      case SmartLinkType.phone:
        return Uri(scheme: 'tel', path: _digitsOnly(value));
      case SmartLinkType.sms:
        return Uri(scheme: 'sms', path: _digitsOnly(value.replaceFirst('sms:', '')));
      case SmartLinkType.email:
        final address = value.replaceFirst('mailto:', '');
        return Uri(scheme: 'mailto', path: address);
      case SmartLinkType.whatsapp:
        if (lowerHost(value) case final h when h != null && h.contains('wa.me')) {
          return Uri.tryParse(value);
        }
        // A bare phone number configured as a WhatsApp contact.
        return Uri.parse('https://wa.me/${_digitsOnly(value)}');
      case SmartLinkType.googleMaps:
        if (value.startsWith('geo:') || value.startsWith('http')) return Uri.tryParse(value);
        return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}');
      case SmartLinkType.facebook:
      case SmartLinkType.instagram:
      case SmartLinkType.youtube:
      case SmartLinkType.tiktok:
      case SmartLinkType.twitter:
      case SmartLinkType.linkedin:
      case SmartLinkType.telegram:
      case SmartLinkType.website:
        final normalized = value.startsWith('http') ? value : 'https://$value';
        return Uri.tryParse(normalized);
      case SmartLinkType.unknown:
        return null;
    }
  }

  String? lowerHost(String value) => Uri.tryParse(value)?.host.toLowerCase();

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^\d+]'), '');

  /// Opens [raw]. If [type] isn't supplied, it's auto-detected. Tries
  /// the installed native app first (App Links/Universal Links), then
  /// falls back to the browser/system chooser. Never throws — always
  /// returns a [Result] with a user-friendly message on failure.
  Future<Result<void>> open(String raw, {SmartLinkType? type}) async {
    final resolvedType = type ?? detect(raw);

    if (resolvedType == SmartLinkType.unknown || !isValid(raw, resolvedType)) {
      AppLogger.warning('Smart link rejected: "$raw" (type=$resolvedType)', tag: 'smart_links');
      return const Result.failure("This link doesn't look valid.");
    }

    final uri = _buildUri(raw, resolvedType);
    if (uri == null) {
      return const Result.failure("This link doesn't look valid.");
    }

    try {
      final launchedNatively = await _launcher.launch(uri, preferNativeApp: true);
      if (launchedNatively) return const Result.success(null);

      final launchedExternally = await _launcher.launch(uri, preferNativeApp: false);
      if (launchedExternally) return const Result.success(null);

      AppLogger.warning('No handler available for $uri', tag: 'smart_links');
      return const Result.failure('No app was found to open this link.');
    } catch (e) {
      AppLogger.error('Failed to open link $uri', tag: 'smart_links', error: e);
      return const Result.failure("Couldn't open this link. Please try again.");
    }
  }

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
  static final RegExp _phonePattern = RegExp(r'^\+?[\d\s()-]{6,20}$');
}
