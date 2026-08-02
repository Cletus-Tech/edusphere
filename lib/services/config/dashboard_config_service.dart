import 'dart:async';
import '../../models/app_settings_models.dart';
import '../../repositories/settings_repository.dart';
import 'feature_flag_service.dart';

/// Drives the entire home dashboard from `settings/dashboard` +
/// `banners/*` + `feature_flags/*`. The home screen should render
/// [visibleCards]/[activeBanners] rather than a fixed widget list, so
/// admins can reorder, add, hide, or pin dashboard content remotely.
class DashboardConfigService {
  DashboardConfigService._();
  static final DashboardConfigService instance = DashboardConfigService._();

  final AppSettingsRepository _repository = AppSettingsRepository();

  DashboardConfigModel _config = const DashboardConfigModel();
  List<BannerModel> _banners = const [];

  StreamSubscription<DashboardConfigModel>? _configSub;
  StreamSubscription<List<BannerModel>>? _bannersSub;
  final _controller = StreamController<DashboardConfigModel>.broadcast();

  DashboardConfigModel get config => _config;
  List<BannerModel> get activeBanners => _banners.where((b) => b.isCurrentlyActive).toList();

  void start() {
    _configSub ??= _repository.watchDashboard().listen((cfg) {
      _config = cfg;
      _controller.add(cfg);
    });
    _bannersSub ??= _repository.banners.watchActive().listen((banners) {
      _banners = banners;
    });
  }

  void dispose() {
    _configSub?.cancel();
    _bannersSub?.cancel();
    _configSub = null;
    _bannersSub = null;
  }

  Stream<DashboardConfigModel> watch() => _controller.stream;

  /// Cards to actually render: hidden-module cards removed, feature-gated
  /// cards checked against [FeatureFlagService], pinned cards first, then
  /// the rest in configured order.
  List<DashboardCardConfig> visibleCards({String? institutionId}) {
    final visible = _config.cards.where((card) {
      if (_config.hiddenModuleKeys.contains(card.key)) return false;
      if (card.featureKey != null &&
          !FeatureFlagService.instance.isEnabled(card.featureKey!, institutionId: institutionId)) {
        return false;
      }
      return true;
    }).toList();

    visible.sort((a, b) {
      final aPinned = _config.pinnedModuleKeys.contains(a.key);
      final bPinned = _config.pinnedModuleKeys.contains(b.key);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return a.order.compareTo(b.order);
    });

    return visible;
  }

  Future<void> update(DashboardConfigModel config) => _repository.saveDashboard(config);
}
