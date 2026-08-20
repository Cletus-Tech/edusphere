import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// `feature_flags/{featureKey}` — one document per toggleable module.
/// Anything a Super Admin should be able to turn on/off remotely (AI
/// Tutor, Community, Marketplace, Scholarships, JAMB, WAEC, NECO, CBT,
/// Parents Portal, Professional Exams, and every future module) is a row
/// here, never an `if (kFeatureX)` compile-time constant in the app.
class FeatureFlagModel extends Equatable implements FirestoreModel {
  final String featureKey;
  final String label;
  final bool isEnabled;
  final Set<String> enabledForInstitutionIds; // empty = enabled for all
  final String? minAppVersion;
  final String? description;

  const FeatureFlagModel({
    required this.featureKey,
    required this.label,
    this.isEnabled = true,
    this.enabledForInstitutionIds = const {},
    this.minAppVersion,
    this.description,
  });

  factory FeatureFlagModel.fromMap(Map<String, dynamic> map, String featureKey) {
    return FeatureFlagModel(
      featureKey: featureKey,
      label: map['label'] as String? ?? featureKey,
      isEnabled: map['isEnabled'] as bool? ?? true,
      enabledForInstitutionIds:
          FirestoreConvert.stringList(map['enabledForInstitutionIds']).toSet(),
      minAppVersion: map['minAppVersion'] as String?,
      description: map['description'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'label': label,
        'isEnabled': isEnabled,
        'enabledForInstitutionIds': enabledForInstitutionIds.toList(),
        'minAppVersion': minAppVersion,
        'description': description,
      };

  /// Whether this feature should show for a given institution. Pass
  /// `null` for users not yet tied to an institution.
  bool isEnabledFor(String? institutionId) {
    if (!isEnabled) return false;
    if (enabledForInstitutionIds.isEmpty) return true;
    return institutionId != null && enabledForInstitutionIds.contains(institutionId);
  }

  @override
  String get id => featureKey;

  @override
  List<Object?> get props => [featureKey, isEnabled, enabledForInstitutionIds];
}

/// Canonical, well-known feature keys. Adding a new module later is a
/// matter of adding a key here and a document in Firestore — no app
/// update, no code path change required to gate it.
class FeatureKeys {
  FeatureKeys._();

  static const String aiTutor = 'ai_tutor';
  static const String community = 'community';
  static const String marketplace = 'marketplace';
  static const String scholarships = 'scholarships';
  static const String jamb = 'jamb';
  static const String waec = 'waec';
  static const String neco = 'neco';
  static const String cbt = 'cbt';
  static const String parentsPortal = 'parents_portal';
  static const String professionalExams = 'professional_exams';
}

/// `settings/branding` — a singleton document. Nothing about visual
/// identity is compiled into the app; every field here can be changed
/// from the Control Center and picked up on next app launch/refresh.
class BrandingSettingsModel extends Equatable implements FirestoreModel {
  final String appTitle;
  final String tagline;
  final String? logoUrl;
  final String? splashImageUrl;
  final String? primaryColorHex;
  final String? secondaryColorHex;
  final String? accentColorHex;
  final List<String> announcementBannerIds;

  const BrandingSettingsModel({
    this.appTitle = 'EduSphere',
    this.tagline = 'Learn. Connect. Succeed.',
    this.logoUrl,
    this.splashImageUrl,
    this.primaryColorHex,
    this.secondaryColorHex,
    this.accentColorHex,
    this.announcementBannerIds = const [],
  });

  factory BrandingSettingsModel.fromMap(Map<String, dynamic> map) {
    return BrandingSettingsModel(
      appTitle: map['appTitle'] as String? ?? 'EduSphere',
      tagline: map['tagline'] as String? ?? 'Learn. Connect. Succeed.',
      logoUrl: map['logoUrl'] as String?,
      splashImageUrl: map['splashImageUrl'] as String?,
      primaryColorHex: map['primaryColorHex'] as String?,
      secondaryColorHex: map['secondaryColorHex'] as String?,
      accentColorHex: map['accentColorHex'] as String?,
      announcementBannerIds: FirestoreConvert.stringList(map['announcementBannerIds']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'appTitle': appTitle,
        'tagline': tagline,
        'logoUrl': logoUrl,
        'splashImageUrl': splashImageUrl,
        'primaryColorHex': primaryColorHex,
        'secondaryColorHex': secondaryColorHex,
        'accentColorHex': accentColorHex,
        'announcementBannerIds': announcementBannerIds,
      };

  @override
  String get id => 'branding';

  @override
  List<Object?> get props => [appTitle, tagline, primaryColorHex];
}

/// `settings/dashboard` — a singleton document driving the entire home
/// dashboard layout: which cards show, in what order, what's pinned or
/// hidden. The home screen renders this list; it never hardcodes cards.
class DashboardConfigModel extends Equatable implements FirestoreModel {
  final List<DashboardCardConfig> cards;
  final List<String> pinnedModuleKeys;
  final List<String> hiddenModuleKeys;

  const DashboardConfigModel({
    this.cards = const [],
    this.pinnedModuleKeys = const [],
    this.hiddenModuleKeys = const [],
  });

  factory DashboardConfigModel.fromMap(Map<String, dynamic> map) {
    final rawCards = map['cards'];
    return DashboardConfigModel(
      cards: rawCards is List
          ? rawCards
              .whereType<Map>()
              .map((c) => DashboardCardConfig.fromMap(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
      pinnedModuleKeys: FirestoreConvert.stringList(map['pinnedModuleKeys']),
      hiddenModuleKeys: FirestoreConvert.stringList(map['hiddenModuleKeys']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'cards': cards.map((c) => c.toMap()).toList(),
        'pinnedModuleKeys': pinnedModuleKeys,
        'hiddenModuleKeys': hiddenModuleKeys,
      };

  @override
  String get id => 'dashboard';

  @override
  List<Object?> get props => [cards, pinnedModuleKeys, hiddenModuleKeys];
}

/// One dashboard card/quick-action/recommendation slot.
class DashboardCardConfig extends Equatable {
  final String key;
  final String title;
  final String? subtitle;
  final String? iconName;
  final String kind; // 'feature' | 'banner' | 'quick_action' | 'recommended' | 'trending'
  final String? deepLink;
  final int order;
  final String? featureKey; // gates this card via FeatureFlagModel, if set

  const DashboardCardConfig({
    required this.key,
    required this.title,
    this.subtitle,
    this.iconName,
    this.kind = 'feature',
    this.deepLink,
    this.order = 0,
    this.featureKey,
  });

  factory DashboardCardConfig.fromMap(Map<String, dynamic> map) {
    return DashboardCardConfig(
      key: map['key'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      iconName: map['iconName'] as String?,
      kind: map['kind'] as String? ?? 'feature',
      deepLink: map['deepLink'] as String?,
      order: map['order'] as int? ?? 0,
      featureKey: map['featureKey'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'title': title,
        'subtitle': subtitle,
        'iconName': iconName,
        'kind': kind,
        'deepLink': deepLink,
        'order': order,
        'featureKey': featureKey,
      };

  @override
  List<Object?> get props => [key, title, kind, order, featureKey];
}

/// `banners/{bannerId}` — a promotional/announcement banner shown on the
/// dashboard or elsewhere, fully admin-managed.
class BannerModel extends Equatable implements FirestoreModel {
  final String bannerId;
  final String imageUrl;
  final String? title;
  final String? deepLink;
  final int order;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const BannerModel({
    required this.bannerId,
    required this.imageUrl,
    this.title,
    this.deepLink,
    this.order = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map, String bannerId) {
    return BannerModel(
      bannerId: bannerId,
      imageUrl: map['imageUrl'] as String? ?? '',
      title: map['title'] as String?,
      deepLink: map['deepLink'] as String?,
      order: map['order'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      startsAt: FirestoreConvert.dateTimeOrNull(map['startsAt']),
      endsAt: FirestoreConvert.dateTimeOrNull(map['endsAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'imageUrl': imageUrl,
        'title': title,
        'deepLink': deepLink,
        'order': order,
        'isActive': isActive,
        'startsAt': startsAt == null ? null : FirestoreConvert.toTimestamp(startsAt!),
        'endsAt': endsAt == null ? null : FirestoreConvert.toTimestamp(endsAt!),
      };

  /// Whether this banner should currently display, honoring optional
  /// scheduling windows.
  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  @override
  String get id => bannerId;

  @override
  List<Object?> get props => [bannerId, imageUrl, isActive, order];
}

/// `settings/app_config` — a singleton document for global app-level
/// settings that don't belong under branding or dashboard specifically
/// (e.g. maintenance mode, minimum supported version).
class AppConfigModel extends Equatable implements FirestoreModel {
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? minSupportedVersion;
  final String? latestVersion;

  const AppConfigModel({
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minSupportedVersion,
    this.latestVersion,
  });

  factory AppConfigModel.fromMap(Map<String, dynamic> map) {
    return AppConfigModel(
      maintenanceMode: map['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: map['maintenanceMessage'] as String?,
      minSupportedVersion: map['minSupportedVersion'] as String?,
      latestVersion: map['latestVersion'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'maintenanceMode': maintenanceMode,
        'maintenanceMessage': maintenanceMessage,
        'minSupportedVersion': minSupportedVersion,
        'latestVersion': latestVersion,
      };

  @override
  String get id => 'app_config';

  @override
  List<Object?> get props => [maintenanceMode, minSupportedVersion, latestVersion];
}

/// `settings/uploads` — a singleton document controlling every limit the
/// Upload Engine enforces client-side before a byte ever leaves the
/// device. Server-side Storage rules (`storage.rules`) remain the real
/// enforcement boundary; this is what lets the app reject an oversized
/// or wrong-type file immediately with a friendly message instead of a
/// failed upload after a long wait.
class UploadSettingsModel extends Equatable implements FirestoreModel {
  final int maxFileSizeMb;
  final List<String> allowedExtensions;
  final int maxConcurrentUploads;
  final bool backgroundUploadsEnabled;

  const UploadSettingsModel({
    this.maxFileSizeMb = 25,
    this.allowedExtensions = const [
      'jpg', 'jpeg', 'png', 'gif', 'webp',
      'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt',
      'mp4', 'mov', 'mp3', 'wav',
    ],
    this.maxConcurrentUploads = 2,
    this.backgroundUploadsEnabled = false,
  });

  factory UploadSettingsModel.fromMap(Map<String, dynamic> map) {
    return UploadSettingsModel(
      maxFileSizeMb: map['maxFileSizeMb'] as int? ?? 25,
      allowedExtensions: map['allowedExtensions'] is List
          ? FirestoreConvert.stringList(map['allowedExtensions'])
          : const UploadSettingsModel().allowedExtensions,
      maxConcurrentUploads: map['maxConcurrentUploads'] as int? ?? 2,
      backgroundUploadsEnabled: map['backgroundUploadsEnabled'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'maxFileSizeMb': maxFileSizeMb,
        'allowedExtensions': allowedExtensions,
        'maxConcurrentUploads': maxConcurrentUploads,
        'backgroundUploadsEnabled': backgroundUploadsEnabled,
      };

  int get maxFileSizeBytes => maxFileSizeMb * 1024 * 1024;

  @override
  String get id => 'uploads';

  @override
  List<Object?> get props => [maxFileSizeMb, allowedExtensions, maxConcurrentUploads];
}

/// `settings/cbt` — Stage CBT-3. The **global** counterpart to
/// [ExamModel]'s per-exam config: whether Practice/Mock are available
/// at all right now, and the free/trial/premium attempt-limit
/// *defaults* an exam falls back to when its own `attemptLimit` is
/// left unset. This never overrides a per-exam `attemptLimit` — that
/// field, when set, always wins; these are only what applies when it's
/// not.
///
/// Nothing in the engine reads this doc yet — same "configuration
/// exists, enforcement is a later stage" status [ExamModel.isPremium]
/// already had as of CBT-2. `requirePremiumForPractice`/
/// `requirePremiumForMock` are configuration for the future
/// entitlement system, not active gates, exactly like
/// [ExamModel.isPremium]. `offlinePracticeEnabled` is the same kind of
/// reserved switch as [ExamModel.offlineAvailable] — there is still no
/// sync/replay engine to turn on (see the CBT-1/CBT-2 audits), so this
/// field controls nothing at runtime; it only reserves the setting so
/// the admin doesn't lose the choice once that engine exists.
class CbtSettingsModel extends Equatable implements FirestoreModel {
  final bool practiceEnabled;
  final bool mockEnabled;
  final int? freeAttemptLimit;
  final int? trialAttemptLimit;
  final int? premiumAttemptLimit;
  final bool requirePremiumForPractice;
  final bool requirePremiumForMock;
  final int? freeUserQuestionLimit;
  final bool offlinePracticeEnabled;

  const CbtSettingsModel({
    this.practiceEnabled = true,
    this.mockEnabled = true,
    this.freeAttemptLimit,
    this.trialAttemptLimit,
    this.premiumAttemptLimit,
    this.requirePremiumForPractice = false,
    this.requirePremiumForMock = false,
    this.freeUserQuestionLimit,
    this.offlinePracticeEnabled = false,
  });

  factory CbtSettingsModel.fromMap(Map<String, dynamic> map) {
    return CbtSettingsModel(
      practiceEnabled: map['practiceEnabled'] as bool? ?? true,
      mockEnabled: map['mockEnabled'] as bool? ?? true,
      freeAttemptLimit: map['freeAttemptLimit'] as int?,
      trialAttemptLimit: map['trialAttemptLimit'] as int?,
      premiumAttemptLimit: map['premiumAttemptLimit'] as int?,
      requirePremiumForPractice: map['requirePremiumForPractice'] as bool? ?? false,
      requirePremiumForMock: map['requirePremiumForMock'] as bool? ?? false,
      freeUserQuestionLimit: map['freeUserQuestionLimit'] as int?,
      offlinePracticeEnabled: map['offlinePracticeEnabled'] as bool? ?? false,
    );
  }

  CbtSettingsModel copyWith({
    bool? practiceEnabled,
    bool? mockEnabled,
    int? freeAttemptLimit,
    bool clearFreeAttemptLimit = false,
    int? trialAttemptLimit,
    bool clearTrialAttemptLimit = false,
    int? premiumAttemptLimit,
    bool clearPremiumAttemptLimit = false,
    bool? requirePremiumForPractice,
    bool? requirePremiumForMock,
    int? freeUserQuestionLimit,
    bool clearFreeUserQuestionLimit = false,
    bool? offlinePracticeEnabled,
  }) =>
      CbtSettingsModel(
        practiceEnabled: practiceEnabled ?? this.practiceEnabled,
        mockEnabled: mockEnabled ?? this.mockEnabled,
        freeAttemptLimit: clearFreeAttemptLimit ? null : (freeAttemptLimit ?? this.freeAttemptLimit),
        trialAttemptLimit: clearTrialAttemptLimit ? null : (trialAttemptLimit ?? this.trialAttemptLimit),
        premiumAttemptLimit: clearPremiumAttemptLimit ? null : (premiumAttemptLimit ?? this.premiumAttemptLimit),
        requirePremiumForPractice: requirePremiumForPractice ?? this.requirePremiumForPractice,
        requirePremiumForMock: requirePremiumForMock ?? this.requirePremiumForMock,
        freeUserQuestionLimit: clearFreeUserQuestionLimit ? null : (freeUserQuestionLimit ?? this.freeUserQuestionLimit),
        offlinePracticeEnabled: offlinePracticeEnabled ?? this.offlinePracticeEnabled,
      );

  @override
  Map<String, dynamic> toMap() => {
        'practiceEnabled': practiceEnabled,
        'mockEnabled': mockEnabled,
        'freeAttemptLimit': freeAttemptLimit,
        'trialAttemptLimit': trialAttemptLimit,
        'premiumAttemptLimit': premiumAttemptLimit,
        'requirePremiumForPractice': requirePremiumForPractice,
        'requirePremiumForMock': requirePremiumForMock,
        'freeUserQuestionLimit': freeUserQuestionLimit,
        'offlinePracticeEnabled': offlinePracticeEnabled,
      };

  @override
  String get id => 'cbt';

  @override
  List<Object?> get props => [
        practiceEnabled,
        mockEnabled,
        freeAttemptLimit,
        trialAttemptLimit,
        premiumAttemptLimit,
        requirePremiumForPractice,
        requirePremiumForMock,
        freeUserQuestionLimit,
        offlinePracticeEnabled,
      ];
}
