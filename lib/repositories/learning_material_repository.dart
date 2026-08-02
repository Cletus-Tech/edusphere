import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/storage_paths.dart';
import '../core/enums/audit_action_type.dart';
import '../core/enums/material_publication_status.dart';
import '../core/utils/result.dart';
import '../models/firestore_model.dart';
import '../models/learning_material_model.dart';
import '../models/upload_task_model.dart';
import '../services/audit/audit_log_service.dart';
import '../services/firebase/storage_service.dart';
import '../services/upload/upload_engine.dart';
import 'base_repository.dart';

/// `learning_materials/{materialId}` — Stage 3.5's Learning Materials
/// Module repository, and the **official** replacement for
/// `LearningContentRepository` (see that class's deprecation note).
///
/// Every write path — create, edit, publish, unpublish, schedule,
/// archive, restore, duplicate, soft delete, thumbnail/banner/file
/// upload — logs through [AuditLogService], mirroring the convention
/// `LearningContentRepository` established in Stage 3.6.2.
///
/// Large-file uploads (the main content file) go through
/// [UploadEngine], which is what actually provides the "upload
/// progress indicator / retry / cancel" requirements from the spec —
/// this repository only attaches the resulting URL once a queued
/// [UploadTaskModel] reaches [UploadStatus.success]. Small, immediate
/// uploads (thumbnail, banner) go straight through [StorageService],
/// same as the legacy module did.
class LearningMaterialRepository extends BaseRepository<LearningMaterialModel> {
  LearningMaterialRepository() : super(AppConstants.learningMaterialsCollection);

  final StorageService _storageService = StorageService();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  LearningMaterialModel fromMap(Map<String, dynamic> map, String id) =>
      LearningMaterialModel.fromMap(map, id);

  // ---------------------------------------------------------------------
  // Part 2 — Repository Layer: Create / Read
  // ---------------------------------------------------------------------

  Future<Result<void>> createMaterial(LearningMaterialModel material) async {
    final result = await save(material);
    if (result.isSuccess) {
      AuditLogService.instance.logCreate(
        module: AuditModules.learningMaterials,
        targetCollection: collection,
        targetId: material.materialId,
        targetTitle: material.title,
        newValues: _auditContext(material),
      );
    }
    return result;
  }

  Future<LearningMaterialModel?> getMaterialById(String id) async {
    final result = await getById(id);
    return switch (result) {
      Success(data: final data) => data,
      Failure() => null,
    };
  }

  /// Student-facing stream — published, non-deleted materials only,
  /// optionally narrowed to one course/institution/type. Ordered by
  /// [LearningMaterialModel.displayOrder] then recency so admin-pinned
  /// items surface first within a given filter.
  Stream<List<LearningMaterialModel>> watchMaterials({
    String? courseId,
    String? institutionId,
    String? departmentId,
    String? levelId,
    String? semesterId,
    String? type,
    int limit = 50,
  }) {
    return streamCollection(
      limit: limit,
      query: (q) {
        var ref = q.where('status', isEqualTo: MaterialPublicationStatus.published.id);
        if (courseId != null && courseId.isNotEmpty) ref = ref.where('courseId', isEqualTo: courseId);
        if (institutionId != null && institutionId.isNotEmpty) {
          ref = ref.where('institutionId', isEqualTo: institutionId);
        }
        if (departmentId != null && departmentId.isNotEmpty) {
          ref = ref.where('departmentId', isEqualTo: departmentId);
        }
        if (levelId != null && levelId.isNotEmpty) ref = ref.where('levelId', isEqualTo: levelId);
        if (semesterId != null && semesterId.isNotEmpty) {
          ref = ref.where('semesterId', isEqualTo: semesterId);
        }
        if (type != null && type.isNotEmpty) ref = ref.where('type', isEqualTo: type);
        return ref.orderBy('displayOrder').orderBy('createdAt', descending: true);
      },
    ).map((list) => list.where((m) => !m.isDeleted).toList());
  }

  Stream<List<LearningMaterialModel>> watchRecentlyAdded({int limit = 10}) {
    return streamCollection(
      limit: limit,
      query: (q) => q
          .where('status', isEqualTo: MaterialPublicationStatus.published.id)
          .orderBy('createdAt', descending: true),
    ).map((list) => list.where((m) => !m.isDeleted).toList());
  }

  /// Bounded admin stream across every status (draft/scheduled/
  /// published/archived), including soft-deleted items so staff can
  /// still find and restore them. Deliberately uses a plain `limit`
  /// rather than real cursor pagination — the same "grow the limit"
  /// convention `AuditLogRepository`'s doc comment contrasts itself
  /// against — because [AdminLearningMaterialsScreen]'s "Load more"
  /// simply re-subscribes with a larger [limit] rather than needing a
  /// document cursor. Swap to `fetchPage`-style pagination if a single
  /// institution's catalog ever grows past a few thousand items.
  Stream<List<LearningMaterialModel>> watchAllForAdmin({
    int limit = 50,
    MaterialPublicationStatus? status,
    String? courseId,
  }) {
    return streamCollection(
      limit: limit,
      query: (q) {
        var ref = q.orderBy('updatedAt', descending: true);
        if (status != null) ref = ref.where('status', isEqualTo: status.id);
        if (courseId != null && courseId.isNotEmpty) ref = ref.where('courseId', isEqualTo: courseId);
        return ref;
      },
    );
  }

  /// Prefix search on [LearningMaterialModel.titleLower]. `forAdmin`
  /// includes drafts/scheduled/archived/deleted items; otherwise only
  /// published, non-deleted materials are returned.
  Future<Result<List<LearningMaterialModel>>> searchMaterials(
    String query, {
    bool forAdmin = false,
    int limit = 30,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const Result.success([]);
    return getWhere(
      limit: limit,
      query: (q) => q
          .orderBy('titleLower')
          .startAt([needle]).endAt(['$needle\uf8ff']),
    ).then((result) => switch (result) {
          Success(data: final data) => Result.success(
              forAdmin ? data : data.where((m) => m.isPublished).toList(),
            ),
          Failure(message: final m) => Result.failure(m),
        });
  }

  /// General-purpose filter for the Admin CMS list — any combination of
  /// these may be null/empty, in which case that axis is unfiltered.
  /// [type] is `LearningMaterialType.id` (a plain string) rather than
  /// the enum itself, so callers building a filter UI from checkboxes
  /// don't need to round-trip through `fromId` just to call this.
  Future<Result<List<LearningMaterialModel>>> filterMaterials({
    String? courseId,
    String? institutionId,
    String? type,
    MaterialPublicationStatus? status,
    int limit = 100,
  }) async {
    return getWhere(
      limit: limit,
      query: (q) {
        var ref = q;
        if (courseId != null && courseId.isNotEmpty) ref = ref.where('courseId', isEqualTo: courseId);
        if (institutionId != null && institutionId.isNotEmpty) {
          ref = ref.where('institutionId', isEqualTo: institutionId);
        }
        if (type != null && type.isNotEmpty) ref = ref.where('type', isEqualTo: type);
        if (status != null) ref = ref.where('status', isEqualTo: status.id);
        return ref.orderBy('updatedAt', descending: true);
      },
    );
  }

  // ---------------------------------------------------------------------
  // Part 2 — Update / lifecycle
  // ---------------------------------------------------------------------

  Future<Result<void>> updateMaterial(
    LearningMaterialModel previous,
    LearningMaterialModel updated,
  ) async {
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    final result = await save(withTimestamp);
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.learningMaterials,
        targetCollection: collection,
        targetId: updated.materialId,
        targetTitle: updated.title,
        previousValues: {'title': previous.title, 'status': previous.status.id, ..._auditContext(previous)},
        newValues: {'title': updated.title, 'status': updated.status.id, ..._auditContext(updated)},
      );
    }
    return result;
  }

  Future<Result<void>> publishMaterial(LearningMaterialModel material) => _setLifecycle(
        material,
        material.copyWith(status: MaterialPublicationStatus.published, clearScheduledFor: true),
        AuditActionType.publish,
      );

  Future<Result<void>> unpublishMaterial(LearningMaterialModel material) => _setLifecycle(
        material,
        material.copyWith(status: MaterialPublicationStatus.draft),
        AuditActionType.unpublish,
      );

  /// Sets the material to publish itself at [publishAt]. Nothing in
  /// this codebase snapshot runs a server-side scheduler (no Cloud
  /// Functions), so a due item is only flipped to [published] the next
  /// time [publishDueScheduled] runs — see that method's doc comment
  /// and the changelog's "Known limitations" section.
  Future<Result<void>> scheduleMaterial(LearningMaterialModel material, DateTime publishAt) => _setLifecycle(
        material,
        material.copyWith(status: MaterialPublicationStatus.scheduled, scheduledFor: publishAt),
        AuditActionType.edit,
      );

  Future<Result<void>> archiveMaterial(LearningMaterialModel material) => _setLifecycle(
        material,
        material.copyWith(status: MaterialPublicationStatus.archived),
        AuditActionType.archive,
      );

  /// Bulk version of [archiveMaterial] — one atomic `WriteBatch` instead
  /// of N sequential round-trips (Stage 3.5.2 audit fix; the Admin
  /// CMS's multi-select "Archive selected" action was awaiting
  /// `archiveMaterial` in a loop). Audit entries are still written one
  /// per material — that granularity is correct, only the document
  /// writes benefit from batching — but all share one [operationId] so
  /// they group together in the Audit Log screen.
  Future<Result<void>> archiveManyMaterials(List<LearningMaterialModel> materials) async {
    if (materials.isEmpty) return const Result.success(null);
    try {
      final batch = _db.batch();
      final now = DateTime.now();
      for (final material in materials) {
        final updated = material.copyWith(status: MaterialPublicationStatus.archived, updatedAt: now);
        batch.set(_db.collection(collection).doc(material.materialId), updated.toMap(), SetOptions(merge: true));
      }
      await batch.commit();

      final operationId = AuditLogService.instance.newOperationId();
      for (final material in materials) {
        AuditLogService.instance.log(
          action: AuditActionType.archive,
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: material.materialId,
          targetTitle: material.title,
          newValues: _auditContext(material),
          operationId: operationId,
        );
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> restoreMaterial(LearningMaterialModel material) => _setLifecycle(
        material,
        material.copyWith(status: MaterialPublicationStatus.draft, isDeleted: false),
        AuditActionType.restore,
      );

  /// Soft delete only — per the Data Integrity convention this codebase
  /// already follows for `learning_content`, a learning material is
  /// never hard-deleted by ordinary admin action.
  Future<Result<void>> softDeleteMaterial(LearningMaterialModel material) => _setLifecycle(
        material,
        material.copyWith(isDeleted: true),
        AuditActionType.delete,
      );

  Future<Result<void>> _setLifecycle(
    LearningMaterialModel previous,
    LearningMaterialModel updated,
    AuditActionType action,
  ) async {
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    final result = await save(withTimestamp);
    if (result.isSuccess) {
      AuditLogService.instance.log(
        action: action,
        module: AuditModules.learningMaterials,
        targetCollection: collection,
        targetId: updated.materialId,
        targetTitle: updated.title,
        newValues: _auditContext(updated),
      );
    }
    return result;
  }

  /// Checks for [MaterialPublicationStatus.scheduled] items whose
  /// [LearningMaterialModel.scheduledFor] has passed and flips them to
  /// [MaterialPublicationStatus.published]. Cheap enough to call from
  /// [AdminLearningMaterialsScreen.initState] and the Learning Library's
  /// refresh — see the class doc comment re: no Cloud Functions here.
  Future<void> publishDueScheduled() async {
    try {
      final now = FirestoreConvert.toTimestamp(DateTime.now());
      final snapshot = await _db
          .collection(collection)
          .where('status', isEqualTo: MaterialPublicationStatus.scheduled.id)
          .where('scheduledFor', isLessThanOrEqualTo: now)
          .get();
      for (final doc in snapshot.docs) {
        final material = fromMap(doc.data(), doc.id);
        await publishMaterial(material);
      }
    } catch (_) {
      // Best-effort — a missed auto-publish tick isn't fatal; the item
      // simply publishes the next time this runs.
    }
  }

  /// Duplicates [material] into a new document — new id, "Copy of"
  /// title, reset analytics, always starts as a [MaterialPublicationStatus.draft]
  /// so the duplicate never goes live silently.
  Future<Result<LearningMaterialModel>> duplicateMaterial(LearningMaterialModel material) async {
    final newMaterialId = newId();
    final now = DateTime.now();
    final copy = LearningMaterialModel(
      materialId: newMaterialId,
      title: 'Copy of ${material.title}',
      description: material.description,
      type: material.type,
      thumbnailUrl: material.thumbnailUrl,
      bannerUrl: material.bannerUrl,
      authorId: material.authorId,
      createdAt: now,
      updatedAt: now,
      institutionId: material.institutionId,
      departmentId: material.departmentId,
      levelId: material.levelId,
      semesterId: material.semesterId,
      courseId: material.courseId,
      topic: material.topic,
      week: material.week,
      tags: material.tags,
      fileUrl: material.fileUrl,
      fileName: material.fileName,
      fileSizeBytes: material.fileSizeBytes,
      durationSeconds: material.durationSeconds,
      pageCount: material.pageCount,
      externalUrl: material.externalUrl,
      richTextContent: material.richTextContent,
      status: MaterialPublicationStatus.draft,
      visibility: material.visibility,
      displayOrder: material.displayOrder,
    );
    final result = await save(copy);
    if (result case Failure(message: final m)) return Result.failure(m);

    AuditLogService.instance.logDuplicate(
      module: AuditModules.learningMaterials,
      targetCollection: collection,
      targetId: material.materialId,
      targetTitle: material.title,
      newTargetId: newMaterialId,
    );
    return Result.success(copy);
  }

  // ---------------------------------------------------------------------
  // Part 3 — File Storage
  // ---------------------------------------------------------------------

  /// Queues the material's main content file through [UploadEngine] —
  /// the caller should subscribe to `UploadEngine.instance.watchTasks()`
  /// to render progress, and call [attachFile] once the returned task
  /// reaches [UploadStatus.success].
  Future<Result<UploadTaskModel>> queueFileUpload({
    required LearningMaterialModel material,
    required File file,
    required String uid,
  }) {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';
    return UploadEngine.instance.enqueue(
      file: file,
      storagePath: StoragePaths.learningMaterialFile(material.materialId, fileName),
      uid: uid,
    );
  }

  /// Persists a completed upload task's URL onto [material] and logs
  /// the upload. Call this from the screen listening to
  /// `UploadEngine.instance.watchTasks()` once `task.status == success`.
  Future<Result<void>> attachFile(LearningMaterialModel material, UploadTaskModel task) async {
    final wasReplace = material.fileUrl != null && material.fileUrl!.isNotEmpty;
    final updated = material.copyWith(
      fileUrl: task.downloadUrl,
      fileName: task.fileName,
      fileSizeBytes: task.fileSizeBytes,
      updatedAt: DateTime.now(),
    );
    final result = await save(updated);
    if (result.isSuccess) {
      if (wasReplace) {
        // Stage 3.5.2 audit fix: the previous version of this method
        // saved the new URL and left the old Storage object behind —
        // a genuine orphaned-file leak on every replace. Best-effort:
        // a failed cleanup shouldn't roll back a successful replace,
        // same "never block/fail the primary action" rule AuditLogService
        // itself follows.
        final oldFileName = material.fileName;
        if (oldFileName != null && oldFileName.isNotEmpty) {
          unawaited(_storageService.deleteFile(StoragePaths.learningMaterialFile(material.materialId, oldFileName)));
        }
        AuditLogService.instance.logEdit(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: material.materialId,
          targetTitle: material.title,
          previousValues: {'fileUrl': material.fileUrl},
          newValues: {'fileUrl': task.downloadUrl},
          summary: 'Replaced file for "${material.title}"',
        );
      } else {
        AuditLogService.instance.logUpload(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: material.materialId,
          targetTitle: material.title,
          newValues: {'fileUrl': task.downloadUrl, 'fileName': task.fileName},
        );
      }
    }
    return result;
  }

  /// Uploads/replaces [material]'s thumbnail immediately (small image,
  /// no need for the full queue/progress machinery).
  Future<Result<String>> uploadThumbnail(LearningMaterialModel material, File file) async {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'thumbnail.jpg';
    final uploadResult = await _storageService.uploadFile(
      path: StoragePaths.learningMaterialThumbnail(material.materialId, fileName),
      file: file,
    );
    if (uploadResult case Success(data: final url)) {
      final updated = material.copyWith(thumbnailUrl: url, updatedAt: DateTime.now());
      final saveResult = await save(updated);
      if (saveResult.isSuccess) {
        AuditLogService.instance.logUpload(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: material.materialId,
          targetTitle: material.title,
          newValues: {'thumbnailUrl': url},
        );
      }
    }
    return uploadResult;
  }

  Future<Result<String>> uploadBanner(LearningMaterialModel material, File file) async {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'banner.jpg';
    final uploadResult = await _storageService.uploadFile(
      path: StoragePaths.learningMaterialBanner(material.materialId, fileName),
      file: file,
    );
    if (uploadResult case Success(data: final url)) {
      final updated = material.copyWith(bannerUrl: url, updatedAt: DateTime.now());
      final saveResult = await save(updated);
      if (saveResult.isSuccess) {
        AuditLogService.instance.logUpload(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: material.materialId,
          targetTitle: material.title,
          newValues: {'bannerUrl': url},
        );
      }
    }
    return uploadResult;
  }

  // ---------------------------------------------------------------------
  // Analytics — atomic counters. These bypass `save()`/full-document
  // rewrite in favor of `FieldValue.increment` so concurrent
  // view/download/bookmark/share events from different students never
  // clobber each other.
  // ---------------------------------------------------------------------

  Future<void> incrementView(String materialId) => _increment(materialId, 'viewCount');

  Future<void> incrementDownload(String materialId, {String? title}) async {
    await _increment(materialId, 'downloadCount');
    AuditLogService.instance.logDownload(
      module: AuditModules.learningMaterials,
      targetCollection: collection,
      targetId: materialId,
      targetTitle: title,
    );
  }

  Future<void> incrementBookmark(String materialId, {int by = 1}) => _increment(materialId, 'bookmarkCount', by: by);

  Future<void> incrementShare(String materialId) => _increment(materialId, 'shareCount');

  Future<void> _increment(String materialId, String field, {int by = 1}) async {
    try {
      await _db.collection(collection).doc(materialId).update({field: FieldValue.increment(by)});
    } catch (_) {
      // Best-effort — a missed analytics tick shouldn't surface to the
      // student trying to view/download something.
    }
  }

  Map<String, dynamic> _auditContext(LearningMaterialModel material) => {
        'materialTitle': material.title,
        'type': material.type.id,
        if (material.courseId != null) 'courseId': material.courseId,
      };
}

