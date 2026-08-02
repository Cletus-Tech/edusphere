import 'dart:async';
import '../../models/app_settings_models.dart';
import '../../repositories/settings_repository.dart';
import '../audit/audit_log_service.dart';

/// The single place the app asks "is module X enabled right now?".
///
/// Backed by `feature_flags/{featureKey}` documents in Firestore — see
/// [FeatureKeys] for the canonical set. Screens should never hardcode a
/// `true`/`false` for whether a module is available; they call
/// `FeatureFlagService.instance.isEnabled(FeatureKeys.aiTutor)`.
class FeatureFlagService {
  FeatureFlagService._();
  static final FeatureFlagService instance = FeatureFlagService._();

  final AppSettingsRepository _repository = AppSettingsRepository();

  Map<String, FeatureFlagModel> _cache = {};
  StreamSubscription<List<FeatureFlagModel>>? _subscription;
  final _cacheController = StreamController<Map<String, FeatureFlagModel>>.broadcast();

  /// Starts listening for remote flag changes. Call once, e.g. from
  /// `app.dart` during startup, after Firebase has initialized.
  void start() {
    _subscription ??= _repository.featureFlags.watchAll().listen((flags) {
      _cache = {for (final f in flags) f.featureKey: f};
      _cacheController.add(_cache);
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  Stream<Map<String, FeatureFlagModel>> watchAll() => _cacheController.stream;

  Stream<bool> watchEnabled(String featureKey, {String? institutionId}) {
    return _repository.featureFlags
        .watchFlag(featureKey)
        .map((flag) => flag?.isEnabledFor(institutionId) ?? _defaultEnabled(featureKey));
  }

  /// Synchronous check against the last-known cache. Defaults to `true`
  /// (fail open) for keys that don't have a document yet, so a brand
  /// new feature doesn't vanish just because nobody created its flag
  /// doc — the admin has to explicitly disable it, not explicitly
  /// enable it.
  bool isEnabled(String featureKey, {String? institutionId}) {
    final flag = _cache[featureKey];
    if (flag == null) return _defaultEnabled(featureKey);
    return flag.isEnabledFor(institutionId);
  }

  bool _defaultEnabled(String featureKey) => true;

  /// Stage 3.6.2 Part 4 addition — the admin-facing write path this
  /// service was previously missing (only reads existed before). Covers
  /// enabling/disabling a module and changing its rollout scope
  /// (`enabledForInstitutionIds`), and logs a before/after audit entry
  /// for either. `previous` is read from the live cache when available
  /// (accurate as of the last `start()` snapshot); falls back to a null
  /// "before" if this flag has never been seen yet (e.g. its very first
  /// save).
  Future<void> updateFlag(FeatureFlagModel updated) async {
    final previous = _cache[updated.featureKey];
    await _repository.featureFlags.save(updated);
    AuditLogService.instance.logFeatureFlagChange(
      flagId: updated.featureKey,
      flagLabel: updated.label,
      previousValues: previous?.toMap(),
      newValues: updated.toMap(),
    );
  }
}
