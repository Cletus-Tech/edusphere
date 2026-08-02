import 'dart:async';
import '../../models/app_settings_models.dart';
import '../../repositories/settings_repository.dart';
import '../audit/audit_log_service.dart';

/// Reads `settings/branding` so logo, splash image, colors, app title,
/// tagline, and announcement banners can change without an app store
/// release. `app_theme.dart`/`app_colors.dart` still define the design
/// *system* (spacing, typography, the dark-luxury gold palette default);
/// this service supplies the *content* layered on top of it.
class BrandingService {
  BrandingService._();
  static final BrandingService instance = BrandingService._();

  final AppSettingsRepository _repository = AppSettingsRepository();

  BrandingSettingsModel _current = const BrandingSettingsModel();
  StreamSubscription<BrandingSettingsModel>? _subscription;
  final _controller = StreamController<BrandingSettingsModel>.broadcast();

  BrandingSettingsModel get current => _current;

  void start() {
    _subscription ??= _repository.watchBranding().listen((branding) {
      _current = branding;
      _controller.add(branding);
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  Stream<BrandingSettingsModel> watch() => _controller.stream;

  /// Stage 3.6.2 Part 3 — every branding update (logo, splash image,
  /// theme, contact info, social links, website, WhatsApp/email/phone)
  /// now logs a before/after audit entry. `_current` is whatever this
  /// service last streamed from Firestore, so the "before" side reflects
  /// the live value even if the admin screen was opened a while ago.
  Future<void> update(BrandingSettingsModel branding) async {
    final previous = _current;
    await _repository.saveBranding(branding);
    AuditLogService.instance.logBrandingChange(
      previousValues: previous.toMap(),
      newValues: branding.toMap(),
    );
  }
}
