import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/audit_action_type.dart';
import '../../core/enums/content_type.dart';
import '../../core/enums/learning_material_type.dart';
import '../../core/enums/material_publication_status.dart';
import '../../core/utils/result.dart';
import '../../models/learning_content_model.dart';
import '../../models/learning_material_model.dart';
import '../../repositories/learning_material_repository.dart';
import '../../repositories/learning_repository.dart';
import '../audit/audit_log_service.dart';

/// The result of one run of [LearningContentMigrationService.migrateAll].
class MigrationReport {
  final int migrated;
  final int skippedAlreadyMigrated;
  final int failed;
  final List<String> failedIds;

  const MigrationReport({
    required this.migrated,
    required this.skippedAlreadyMigrated,
    required this.failed,
    required this.failedIds,
  });

  static const empty = MigrationReport(migrated: 0, skippedAlreadyMigrated: 0, failed: 0, failedIds: []);

  String get summary =>
      '$migrated migrated, $skippedAlreadyMigrated already migrated, $failed failed'
      '${failedIds.isNotEmpty ? ' (${failedIds.join(', ')})' : ''}';
}

/// Stage 3.5 — controlled migration from the deprecated `learning_content`
/// collection into the official `learning_materials` collection.
///
/// Per the spec: **do not build two parallel libraries.** This service
/// is what lets the Admin CMS retire `learning_content` gradually rather
/// than all at once —
///
///  1. Every legacy [LearningContentModel] doc maps onto a
///     [LearningMaterialModel] with the *same document id*, so
///     anything already referencing a `learning_content` id by URL/deep
///     link keeps resolving after migration.
///  2. Existing files are never re-uploaded — `fileUrl`/`thumbnailUrl`
///     are copied across as-is, so Storage objects and course/user
///     relationships (`courseId`, `uploadedBy` → `authorId`) survive
///     untouched.
///  3. The legacy doc is marked `migratedTo` (not deleted) so
///     [LearningContentRepository] readers and this service itself can
///     tell a doc has already been handled, and so the old data is
///     still there as a fallback until the new module is verified in
///     production.
class LearningContentMigrationService {
  LearningContentMigrationService._();
  static final LearningContentMigrationService instance = LearningContentMigrationService._();

  final LearningContentRepository _legacyRepository = LearningContentRepository();
  final LearningMaterialRepository _materialRepository = LearningMaterialRepository();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Maps one legacy document onto the new shape. `contentId` is reused
  /// as `materialId` — see class doc, point 1.
  LearningMaterialModel _mapToMaterial(LearningContentModel legacy) {
    return LearningMaterialModel(
      materialId: legacy.contentId,
      title: legacy.title,
      type: _mapType(legacy.type),
      thumbnailUrl: legacy.thumbnailUrl,
      authorId: legacy.uploadedBy ?? '',
      createdAt: legacy.createdAt,
      updatedAt: legacy.createdAt,
      courseId: legacy.courseId,
      fileUrl: legacy.fileUrl,
      fileSizeBytes: legacy.fileSizeBytes,
      status: legacy.isDeleted
          ? MaterialPublicationStatus.archived
          : legacy.isArchived
              ? MaterialPublicationStatus.archived
              : legacy.isPublished
                  ? MaterialPublicationStatus.published
                  : MaterialPublicationStatus.draft,
      downloadCount: legacy.downloadCount,
      isDeleted: legacy.isDeleted,
    );
  }

  LearningMaterialType _mapType(LearningContentType legacyType) => switch (legacyType) {
        LearningContentType.pdf => LearningMaterialType.pdf,
        LearningContentType.video => LearningMaterialType.video,
        LearningContentType.audio => LearningMaterialType.audio,
        LearningContentType.download => LearningMaterialType.archive,
        LearningContentType.assignment => LearningMaterialType.document,
        LearningContentType.timetable => LearningMaterialType.document,
        LearningContentType.flashcard => LearningMaterialType.richText,
        LearningContentType.note => LearningMaterialType.richText,
      };

  /// Migrates every not-yet-migrated `learning_content` document.
  /// Idempotent — safe to run more than once; already-migrated docs
  /// (flagged `migratedTo` server-side) are skipped.
  Future<MigrationReport> migrateAll() async {
    int migrated = 0, skipped = 0, failed = 0;
    final failedIds = <String>[];
    final operationId = AuditLogService.instance.newOperationId();

    try {
      final snapshot = await _db.collection(AppConstants.learningContentCollection).get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['migratedTo'] != null) {
          skipped++;
          continue;
        }
        try {
          final legacy = LearningContentModel.fromMap(data, doc.id);
          final material = _mapToMaterial(legacy);
          final saveResult = await _materialRepository.save(material);
          if (saveResult.isFailure) {
            failed++;
            failedIds.add(doc.id);
            continue;
          }
          await doc.reference.update({'migratedTo': material.materialId});
          AuditLogService.instance.log(
            action: AuditActionType.create,
            module: AuditModules.learningMaterials,
            targetCollection: AppConstants.learningMaterialsCollection,
            targetId: material.materialId,
            targetTitle: material.title,
            summary: 'Migrated "${material.title}" from Learning Content',
            operationId: operationId,
          );
          migrated++;
        } catch (_) {
          failed++;
          failedIds.add(doc.id);
        }
      }
    } catch (_) {
      // Best-effort — return whatever was accomplished before the
      // failure rather than throwing out of an admin-triggered action.
    }

    return MigrationReport(migrated: migrated, skippedAlreadyMigrated: skipped, failed: failed, failedIds: failedIds);
  }
}
