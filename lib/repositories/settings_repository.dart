import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/app_settings_models.dart';
import 'base_repository.dart';

class FeatureFlagRepository extends BaseRepository<FeatureFlagModel> {
  FeatureFlagRepository() : super(AppConstants.featureFlagsCollection);

  @override
  FeatureFlagModel fromMap(Map<String, dynamic> map, String id) => FeatureFlagModel.fromMap(map, id);

  Stream<List<FeatureFlagModel>> watchAll() => streamCollection();

  Stream<FeatureFlagModel?> watchFlag(String featureKey) => streamById(featureKey);
}

class BannerRepository extends BaseRepository<BannerModel> {
  BannerRepository() : super(AppConstants.bannersCollection);

  @override
  BannerModel fromMap(Map<String, dynamic> map, String id) => BannerModel.fromMap(map, id);

  Stream<List<BannerModel>> watchActive() {
    return streamCollection(query: (q) => q.where('isActive', isEqualTo: true).orderBy('order'));
  }
}

/// Wraps the `settings/*` singleton documents (branding, dashboard,
/// app_config). These aren't a per-id collection like everything else
/// in Stage 1.2 — each is exactly one document — so this repository
/// exposes them by name rather than extending [BaseRepository], while
/// still going through the same `settings` collection referenced by
/// [AppConstants.settingsCollection].
class AppSettingsRepository {
  final FeatureFlagRepository featureFlags = FeatureFlagRepository();
  final BannerRepository banners = BannerRepository();

  CollectionReference<Map<String, dynamic>> get _settings =>
      FirebaseFirestore.instance.collection(AppConstants.settingsCollection);

  Stream<BrandingSettingsModel> watchBranding() {
    return _settings.doc(AppConstants.brandingSettingsDoc).snapshots().map(
          (snap) => snap.data() == null
              ? const BrandingSettingsModel()
              : BrandingSettingsModel.fromMap(snap.data()!),
        );
  }

  Future<void> saveBranding(BrandingSettingsModel model) =>
      _settings.doc(AppConstants.brandingSettingsDoc).set(model.toMap(), SetOptions(merge: true));

  Stream<DashboardConfigModel> watchDashboard() {
    return _settings.doc(AppConstants.dashboardSettingsDoc).snapshots().map(
          (snap) => snap.data() == null
              ? const DashboardConfigModel()
              : DashboardConfigModel.fromMap(snap.data()!),
        );
  }

  Future<void> saveDashboard(DashboardConfigModel model) =>
      _settings.doc(AppConstants.dashboardSettingsDoc).set(model.toMap(), SetOptions(merge: true));

  Stream<AppConfigModel> watchAppConfig() {
    return _settings.doc(AppConstants.appSettingsDoc).snapshots().map(
          (snap) =>
              snap.data() == null ? const AppConfigModel() : AppConfigModel.fromMap(snap.data()!),
        );
  }

  Future<void> saveAppConfig(AppConfigModel model) =>
      _settings.doc(AppConstants.appSettingsDoc).set(model.toMap(), SetOptions(merge: true));

  Stream<UploadSettingsModel> watchUploadSettings() {
    return _settings.doc(AppConstants.uploadSettingsDoc).snapshots().map(
          (snap) => snap.data() == null
              ? const UploadSettingsModel()
              : UploadSettingsModel.fromMap(snap.data()!),
        );
  }

  Future<void> saveUploadSettings(UploadSettingsModel model) => _settings
      .doc(AppConstants.uploadSettingsDoc)
      .set(model.toMap(), SetOptions(merge: true));
}
