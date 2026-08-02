import 'package:equatable/equatable.dart';
import '../core/enums/learning_material_type.dart';
import '../core/enums/material_publication_status.dart';
import 'firestore_model.dart';

/// `learning_materials/{materialId}` — Stage 3.5's Learning Materials
/// Module. This is the official, permanent content library for
/// University coursework, JAMB/WAEC/NECO prep, and every future
/// educational program EduSphere adds — the successor to Stage 1's
/// `learning_content` collection (see [LearningContentModel]'s doc
/// comment for the deprecation note).
///
/// Every field that could plausibly need to change from the Control
/// Center without a rebuild (visibility, display order, tags, academic
/// structure) is database-driven here rather than hardcoded anywhere
/// downstream.
class LearningMaterialModel extends Equatable implements FirestoreModel {
  // ---- Basic information -------------------------------------------
  final String materialId;
  final String title;
  final String description;
  final LearningMaterialType type;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final String authorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ---- Academic structure --------------------------------------------
  // All optional: a JAMB past-question set has no institution/department,
  // a 300-level course PDF has every field populated. `courseId` is the
  // one query filters lean on most; the rest refine within it.
  final String? institutionId; // "School"
  final String? departmentId;
  final String? levelId;
  final String? semesterId;
  final String? courseId;
  final String? topic;
  final String? week;
  final List<String> tags;

  // ---- Content ---------------------------------------------------------
  // Exactly one of these is populated, matching `type`:
  // fileUrl for pdf/video/image/audio/document/presentation/archive,
  // externalUrl for link, richTextContent for richText.
  final String? fileUrl;
  final String? fileName;
  final int fileSizeBytes;
  final int? durationSeconds; // video/audio
  final int? pageCount; // pdf/document/presentation
  final String? externalUrl;
  final String? richTextContent;

  // ---- Publishing system ------------------------------------------------
  final MaterialPublicationStatus status;
  final DateTime? scheduledFor;
  final MaterialVisibility visibility;
  final int displayOrder;

  // ---- Analytics ------------------------------------------------------
  final int viewCount;
  final int downloadCount;
  final int bookmarkCount;
  final int shareCount;

  // ---- Soft delete (Data Integrity convention carried over from the
  // legacy module — see `LearningContentModel.isDeleted`) --------------
  final bool isDeleted;

  const LearningMaterialModel({
    required this.materialId,
    required this.title,
    this.description = '',
    required this.type,
    this.thumbnailUrl,
    this.bannerUrl,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
    this.institutionId,
    this.departmentId,
    this.levelId,
    this.semesterId,
    this.courseId,
    this.topic,
    this.week,
    this.tags = const [],
    this.fileUrl,
    this.fileName,
    this.fileSizeBytes = 0,
    this.durationSeconds,
    this.pageCount,
    this.externalUrl,
    this.richTextContent,
    this.status = MaterialPublicationStatus.draft,
    this.scheduledFor,
    this.visibility = MaterialVisibility.everyone,
    this.displayOrder = 0,
    this.viewCount = 0,
    this.downloadCount = 0,
    this.bookmarkCount = 0,
    this.shareCount = 0,
    this.isDeleted = false,
  });

  /// Lowercased title for cheap `startAt`/`endAt` prefix search —
  /// Firestore has no native full-text search, so
  /// `LearningMaterialRepository.searchMaterials` relies on this
  /// pre-computed field rather than scanning every document client-side.
  String get titleLower => title.toLowerCase();

  bool get isPublished => status == MaterialPublicationStatus.published && !isDeleted;
  bool get isArchived => status == MaterialPublicationStatus.archived;
  bool get isScheduled => status == MaterialPublicationStatus.scheduled;

  factory LearningMaterialModel.fromMap(Map<String, dynamic> map, String materialId) {
    return LearningMaterialModel(
      materialId: materialId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: LearningMaterialType.fromId(map['type'] as String? ?? ''),
      thumbnailUrl: map['thumbnailUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      authorId: map['authorId'] as String? ?? '',
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
      updatedAt: FirestoreConvert.dateTime(map['updatedAt'], fallback: FirestoreConvert.dateTime(map['createdAt'])),
      institutionId: map['institutionId'] as String?,
      departmentId: map['departmentId'] as String?,
      levelId: map['levelId'] as String?,
      semesterId: map['semesterId'] as String?,
      courseId: map['courseId'] as String?,
      topic: map['topic'] as String?,
      week: map['week'] as String?,
      tags: FirestoreConvert.stringList(map['tags']),
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      durationSeconds: map['durationSeconds'] as int?,
      pageCount: map['pageCount'] as int?,
      externalUrl: map['externalUrl'] as String?,
      richTextContent: map['richTextContent'] as String?,
      status: MaterialPublicationStatus.fromId(map['status'] as String? ?? 'draft'),
      scheduledFor: FirestoreConvert.dateTimeOrNull(map['scheduledFor']),
      visibility: MaterialVisibility.fromId(map['visibility'] as String? ?? 'everyone'),
      displayOrder: map['displayOrder'] as int? ?? 0,
      viewCount: map['viewCount'] as int? ?? 0,
      downloadCount: map['downloadCount'] as int? ?? 0,
      bookmarkCount: map['bookmarkCount'] as int? ?? 0,
      shareCount: map['shareCount'] as int? ?? 0,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'titleLower': titleLower,
        'description': description,
        'type': type.id,
        'thumbnailUrl': thumbnailUrl,
        'bannerUrl': bannerUrl,
        'authorId': authorId,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
        'updatedAt': FirestoreConvert.toTimestamp(updatedAt),
        'institutionId': institutionId,
        'departmentId': departmentId,
        'levelId': levelId,
        'semesterId': semesterId,
        'courseId': courseId,
        'topic': topic,
        'week': week,
        'tags': tags,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'durationSeconds': durationSeconds,
        'pageCount': pageCount,
        'externalUrl': externalUrl,
        'richTextContent': richTextContent,
        'status': status.id,
        'scheduledFor': scheduledFor == null ? null : FirestoreConvert.toTimestamp(scheduledFor!),
        'visibility': visibility.id,
        'displayOrder': displayOrder,
        'viewCount': viewCount,
        'downloadCount': downloadCount,
        'bookmarkCount': bookmarkCount,
        'shareCount': shareCount,
        'isDeleted': isDeleted,
      };

  LearningMaterialModel copyWith({
    String? title,
    String? description,
    LearningMaterialType? type,
    String? thumbnailUrl,
    String? bannerUrl,
    String? institutionId,
    String? departmentId,
    String? levelId,
    String? semesterId,
    String? courseId,
    String? topic,
    String? week,
    List<String>? tags,
    String? fileUrl,
    String? fileName,
    int? fileSizeBytes,
    int? durationSeconds,
    int? pageCount,
    String? externalUrl,
    String? richTextContent,
    MaterialPublicationStatus? status,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
    MaterialVisibility? visibility,
    int? displayOrder,
    int? viewCount,
    int? downloadCount,
    int? bookmarkCount,
    int? shareCount,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return LearningMaterialModel(
      materialId: materialId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      authorId: authorId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      institutionId: institutionId ?? this.institutionId,
      departmentId: departmentId ?? this.departmentId,
      levelId: levelId ?? this.levelId,
      semesterId: semesterId ?? this.semesterId,
      courseId: courseId ?? this.courseId,
      topic: topic ?? this.topic,
      week: week ?? this.week,
      tags: tags ?? this.tags,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pageCount: pageCount ?? this.pageCount,
      externalUrl: externalUrl ?? this.externalUrl,
      richTextContent: richTextContent ?? this.richTextContent,
      status: status ?? this.status,
      scheduledFor: clearScheduledFor ? null : (scheduledFor ?? this.scheduledFor),
      visibility: visibility ?? this.visibility,
      displayOrder: displayOrder ?? this.displayOrder,
      viewCount: viewCount ?? this.viewCount,
      downloadCount: downloadCount ?? this.downloadCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      shareCount: shareCount ?? this.shareCount,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String get id => materialId;

  @override
  List<Object?> get props => [
        materialId,
        title,
        type,
        status,
        courseId,
        isDeleted,
        viewCount,
        downloadCount,
      ];
}
