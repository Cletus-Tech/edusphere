import 'package:equatable/equatable.dart';
import '../core/enums/content_type.dart';
import 'firestore_model.dart';

/// `learning_content/{contentId}` — one piece of study material. The
/// `fileUrl` points at a path built by `StoragePaths`; never a raw string
/// assembled in a widget.
///
/// **DEPRECATED as of Stage 3.5** in favor of `LearningMaterialModel`
/// (`learning_materials/{materialId}`), which adds the academic
/// structure (institution/department/level/semester/topic/week),
/// richer content-type support, scheduling, visibility, and analytics
/// this flat shape never had room for. See
/// `LearningContentMigrationService` for the migration path and
/// `docs/STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md` for details. Left
/// in place, unmodified, so existing `learning_content` documents
/// remain readable during the migration window.
class LearningContentModel extends Equatable implements FirestoreModel {
  final String contentId;
  final String title;
  final LearningContentType type;
  final String courseId;
  final String? fileUrl;
  final String? thumbnailUrl;
  final String? uploadedBy;
  final int downloadCount;
  final int fileSizeBytes;
  final bool isPublished;
  // Stage 3.6.2 — needed so LearningContentRepository can offer real
  // archive/restore/soft-delete operations for AuditLogService to log
  // against; both default false so existing documents decode unchanged.
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;

  const LearningContentModel({
    required this.contentId,
    required this.title,
    required this.type,
    required this.courseId,
    this.fileUrl,
    this.thumbnailUrl,
    this.uploadedBy,
    this.downloadCount = 0,
    this.fileSizeBytes = 0,
    this.isPublished = true,
    this.isArchived = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory LearningContentModel.fromMap(Map<String, dynamic> map, String contentId) {
    return LearningContentModel(
      contentId: contentId,
      title: map['title'] as String? ?? '',
      type: LearningContentType.fromId(map['type'] as String? ?? ''),
      courseId: map['courseId'] as String? ?? '',
      fileUrl: map['fileUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      uploadedBy: map['uploadedBy'] as String?,
      downloadCount: map['downloadCount'] as int? ?? 0,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      isPublished: map['isPublished'] as bool? ?? true,
      isArchived: map['isArchived'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.id,
        'courseId': courseId,
        'fileUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'uploadedBy': uploadedBy,
        'downloadCount': downloadCount,
        'fileSizeBytes': fileSizeBytes,
        'isPublished': isPublished,
        'isArchived': isArchived,
        'isDeleted': isDeleted,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  LearningContentModel copyWith({
    String? title,
    String? fileUrl,
    String? thumbnailUrl,
    bool? isPublished,
    bool? isArchived,
    bool? isDeleted,
  }) {
    return LearningContentModel(
      contentId: contentId,
      title: title ?? this.title,
      type: type,
      courseId: courseId,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadedBy: uploadedBy,
      downloadCount: downloadCount,
      fileSizeBytes: fileSizeBytes,
      isPublished: isPublished ?? this.isPublished,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
    );
  }

  @override
  String get id => contentId;

  @override
  List<Object?> get props =>
      [contentId, title, type, courseId, isPublished, isArchived, isDeleted];
}
