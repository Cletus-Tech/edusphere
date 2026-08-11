import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// `creator_profile/main` — Stage 6.3. The single "About the Owner"
/// document. A fixed-id singleton doc, not a `BaseRepository<T>`
/// collection — exactly the pattern `AppSettingsRepository` already
/// uses for `BrandingSettingsModel`/`AppConfigModel` (one doc,
/// `watch`/`save`, no per-item CRUD). Skills, achievements, documents,
/// and projects are separate list collections (see the other models
/// in this file) rather than arrays on this document, so admin can
/// add/reorder/delete one item without rewriting the whole profile.
///
/// Every field defaults to empty/null, never to placeholder copy —
/// per the "nothing hardcoded" requirement, an unconfigured profile
/// should render as genuinely empty (handled by the public screen's
/// empty states), not silently show made-up text.
class CreatorProfileModel extends Equatable implements FirestoreModel {
  final String name;
  final String title;
  final String profileImageUrl;
  final String coverImageUrl;
  final String introduction;
  final String biography;
  final String mission;
  final String vision;
  final String journey;
  final String email;
  final String website;
  final Map<String, String> socialLinks; // e.g. {"twitter": "https://...", "github": "https://..."}
  final bool isPublished;

  const CreatorProfileModel({
    this.name = '',
    this.title = '',
    this.profileImageUrl = '',
    this.coverImageUrl = '',
    this.introduction = '',
    this.biography = '',
    this.mission = '',
    this.vision = '',
    this.journey = '',
    this.email = '',
    this.website = '',
    this.socialLinks = const {},
    this.isPublished = false,
  });

  CreatorProfileModel copyWith({
    String? name,
    String? title,
    String? profileImageUrl,
    String? coverImageUrl,
    String? introduction,
    String? biography,
    String? mission,
    String? vision,
    String? journey,
    String? email,
    String? website,
    Map<String, String>? socialLinks,
    bool? isPublished,
  }) =>
      CreatorProfileModel(
        name: name ?? this.name,
        title: title ?? this.title,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        introduction: introduction ?? this.introduction,
        biography: biography ?? this.biography,
        mission: mission ?? this.mission,
        vision: vision ?? this.vision,
        journey: journey ?? this.journey,
        email: email ?? this.email,
        website: website ?? this.website,
        socialLinks: socialLinks ?? this.socialLinks,
        isPublished: isPublished ?? this.isPublished,
      );

  factory CreatorProfileModel.fromMap(Map<String, dynamic> map, String id) {
    return CreatorProfileModel(
      name: map['name'] as String? ?? '',
      title: map['title'] as String? ?? '',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String? ?? '',
      introduction: map['introduction'] as String? ?? '',
      biography: map['biography'] as String? ?? '',
      mission: map['mission'] as String? ?? '',
      vision: map['vision'] as String? ?? '',
      journey: map['journey'] as String? ?? '',
      email: map['email'] as String? ?? '',
      website: map['website'] as String? ?? '',
      socialLinks: FirestoreConvert.map(map['socialLinks']).map((k, v) => MapEntry(k, v.toString())),
      isPublished: map['isPublished'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'title': title,
        'profileImageUrl': profileImageUrl,
        'coverImageUrl': coverImageUrl,
        'introduction': introduction,
        'biography': biography,
        'mission': mission,
        'vision': vision,
        'journey': journey,
        'email': email,
        'website': website,
        'socialLinks': socialLinks,
        'isPublished': isPublished,
      };

  /// Whether there's enough here to actually show a page — used by
  /// the public screen to decide between the real profile and an
  /// [EmptyView] rather than rendering an all-blank hero.
  bool get hasContent => isPublished && (name.isNotEmpty || introduction.isNotEmpty);

  @override
  String get id => 'main';

  @override
  List<Object?> get props => [name, title, isPublished];
}

/// `creator_skills/{id}`. Deliberately its own collection, not part of
/// `CreatorProfileModel` — see that class's doc comment.
class CreatorSkillModel extends Equatable implements FirestoreModel {
  final String skillId;
  final String label;
  final String? category;
  final int sortOrder;
  // Stage 6.3 Part 2 — Admin CMS "enable/disable" control (§3, §8).
  // Defaults to true so every skill written by Part 1 (before this field
  // existed) still reads as published — a minimal, additive schema change
  // rather than a migration.
  final bool isPublished;

  const CreatorSkillModel({
    required this.skillId,
    required this.label,
    this.category,
    this.sortOrder = 0,
    this.isPublished = true,
  });

  factory CreatorSkillModel.fromMap(Map<String, dynamic> map, String skillId) {
    return CreatorSkillModel(
      skillId: skillId,
      label: map['label'] as String? ?? '',
      category: map['category'] as String?,
      sortOrder: map['sortOrder'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? true,
    );
  }

  CreatorSkillModel copyWith({
    String? label,
    String? category,
    bool clearCategory = false,
    int? sortOrder,
    bool? isPublished,
  }) =>
      CreatorSkillModel(
        skillId: skillId,
        label: label ?? this.label,
        category: clearCategory ? null : (category ?? this.category),
        sortOrder: sortOrder ?? this.sortOrder,
        isPublished: isPublished ?? this.isPublished,
      );

  @override
  Map<String, dynamic> toMap() => {
        'label': label,
        'category': category,
        'sortOrder': sortOrder,
        'isPublished': isPublished,
      };

  @override
  String get id => skillId;

  @override
  List<Object?> get props => [skillId, label, sortOrder, isPublished];
}

/// `creator_achievements/{id}`. Named `creator_achievements`
/// specifically — not `achievements` — because that collection
/// already exists for student gamification (`AchievementModel` in
/// `engagement_models.dart`, via `AchievementRepository`). Reusing it
/// here would silently mix two unrelated document shapes in one
/// collection; confirmed via audit before naming this.
class CreatorAchievementModel extends Equatable implements FirestoreModel {
  final String achievementId;
  final String title;
  final String description;
  final String? category; // e.g. "Certification", "Award", "Milestone"
  final DateTime? date;
  final int sortOrder;
  final bool isPublished; // see CreatorSkillModel.isPublished doc comment

  const CreatorAchievementModel({
    required this.achievementId,
    required this.title,
    this.description = '',
    this.category,
    this.date,
    this.sortOrder = 0,
    this.isPublished = true,
  });

  factory CreatorAchievementModel.fromMap(Map<String, dynamic> map, String achievementId) {
    return CreatorAchievementModel(
      achievementId: achievementId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String?,
      date: FirestoreConvert.dateTimeOrNull(map['date']),
      sortOrder: map['sortOrder'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? true,
    );
  }

  CreatorAchievementModel copyWith({
    String? title,
    String? description,
    String? category,
    bool clearCategory = false,
    DateTime? date,
    bool clearDate = false,
    int? sortOrder,
    bool? isPublished,
  }) =>
      CreatorAchievementModel(
        achievementId: achievementId,
        title: title ?? this.title,
        description: description ?? this.description,
        category: clearCategory ? null : (category ?? this.category),
        date: clearDate ? null : (date ?? this.date),
        sortOrder: sortOrder ?? this.sortOrder,
        isPublished: isPublished ?? this.isPublished,
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'category': category,
        if (date != null) 'date': FirestoreConvert.toTimestamp(date!),
        'sortOrder': sortOrder,
        'isPublished': isPublished,
      };

  @override
  String get id => achievementId;

  @override
  List<Object?> get props => [achievementId, title, date, isPublished];
}

/// `creator_documents/{id}` — CV, certificates, portfolio PDF, etc.
/// `storagePath` follows the same Cloud Storage convention every other
/// upload in the app uses (see `StoragePaths.creatorDocument`) rather
/// than a bespoke storage flow.
class CreatorDocumentModel extends Equatable implements FirestoreModel {
  final String documentId;
  final String title;
  final String description;
  final String storagePath;
  final String downloadUrl;
  final DateTime uploadedAt;
  final int sortOrder;
  final bool isPublished; // see CreatorSkillModel.isPublished doc comment

  const CreatorDocumentModel({
    required this.documentId,
    required this.title,
    this.description = '',
    this.storagePath = '',
    this.downloadUrl = '',
    required this.uploadedAt,
    this.sortOrder = 0,
    this.isPublished = true,
  });

  factory CreatorDocumentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CreatorDocumentModel(
      documentId: documentId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      downloadUrl: map['downloadUrl'] as String? ?? '',
      uploadedAt: FirestoreConvert.dateTime(map['uploadedAt']),
      sortOrder: map['sortOrder'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? true,
    );
  }

  CreatorDocumentModel copyWith({
    String? title,
    String? description,
    String? storagePath,
    String? downloadUrl,
    DateTime? uploadedAt,
    int? sortOrder,
    bool? isPublished,
  }) =>
      CreatorDocumentModel(
        documentId: documentId,
        title: title ?? this.title,
        description: description ?? this.description,
        storagePath: storagePath ?? this.storagePath,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        sortOrder: sortOrder ?? this.sortOrder,
        isPublished: isPublished ?? this.isPublished,
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'uploadedAt': FirestoreConvert.toTimestamp(uploadedAt),
        'sortOrder': sortOrder,
        'isPublished': isPublished,
      };

  @override
  String get id => documentId;

  @override
  List<Object?> get props => [documentId, title, uploadedAt, isPublished];
}

/// `creator_projects/{id}` — portfolio project showcase entries.
class CreatorProjectModel extends Equatable implements FirestoreModel {
  final String projectId;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> technologies;
  final Map<String, String> links; // e.g. {"website": "...", "github": "..."}
  final int sortOrder;
  final bool isPublished; // see CreatorSkillModel.isPublished doc comment

  const CreatorProjectModel({
    required this.projectId,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.technologies = const [],
    this.links = const {},
    this.sortOrder = 0,
    this.isPublished = true,
  });

  factory CreatorProjectModel.fromMap(Map<String, dynamic> map, String projectId) {
    return CreatorProjectModel(
      projectId: projectId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      technologies: FirestoreConvert.stringList(map['technologies']),
      links: FirestoreConvert.map(map['links']).map((k, v) => MapEntry(k, v.toString())),
      sortOrder: map['sortOrder'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? true,
    );
  }

  CreatorProjectModel copyWith({
    String? title,
    String? description,
    String? imageUrl,
    List<String>? technologies,
    Map<String, String>? links,
    int? sortOrder,
    bool? isPublished,
  }) =>
      CreatorProjectModel(
        projectId: projectId,
        title: title ?? this.title,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        technologies: technologies ?? this.technologies,
        links: links ?? this.links,
        sortOrder: sortOrder ?? this.sortOrder,
        isPublished: isPublished ?? this.isPublished,
      );

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'technologies': technologies,
        'links': links,
        'sortOrder': sortOrder,
        'isPublished': isPublished,
      };

  @override
  String get id => projectId;

  @override
  List<Object?> get props => [projectId, title, sortOrder, isPublished];
}
