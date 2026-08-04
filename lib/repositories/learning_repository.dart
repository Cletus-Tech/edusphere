import 'dart:io';
import '../core/constants/app_constants.dart';
import '../core/constants/storage_paths.dart';
import '../core/enums/audit_action_type.dart';
import '../core/utils/result.dart';
import '../models/exam_model.dart';
import '../models/exam_session_model.dart';
import '../models/learning_content_model.dart';
import '../services/audit/audit_log_service.dart';
import '../services/firebase/storage_service.dart';
import 'base_repository.dart';
import 'course_repository.dart';

/// `learning_content/{contentId}` — Stage 1's course notes/assignments/
/// timetables content model.
///
/// **DEPRECATED as of Stage 3.5.** [LearningMaterialRepository] /
/// [LearningMaterialModel] is now the official Learning Materials
/// system — see `docs/STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md` and
/// `LearningContentMigrationService`, which copies existing documents
/// here into `learning_materials` (preserving ids, files, course/user
/// relationships, and audit continuity) rather than requiring a manual
/// re-upload.
///
/// This class is kept **read-only from new code**: nothing added after
/// Stage 3.5 should call [createContent] or any other write path below
/// to create new records. It stays in the codebase, functional, so
/// already-migrated collections remain queryable and so
/// `LearningContentMigrationService` has something to read from — it
/// will be deleted in a later stage once migration is verified
/// complete in production (per the spec's "remove old unused code only
/// after verification" rule).
///
/// Stage 3.6.2 Part 1: every write path below — create, edit, publish,
/// unpublish, archive, restore, duplicate, soft delete, thumbnail
/// upload, file upload/replace — logs through [AuditLogService].
/// Screens that already call [save] directly for a raw create/edit
/// still work (nothing removed, `save`/`delete` are still inherited from
/// [BaseRepository] unchanged), but should prefer the named methods
/// below going forward so the action is logged correctly.
class LearningContentRepository extends BaseRepository<LearningContentModel> {
  LearningContentRepository() : super(AppConstants.learningContentCollection);

  final StorageService _storageService = StorageService();
  final CourseRepository _courseRepository = CourseRepository();

  @override
  LearningContentModel fromMap(Map<String, dynamic> map, String id) =>
      LearningContentModel.fromMap(map, id);

  Stream<List<LearningContentModel>> watchByCourse(String courseId) {
    return streamCollection(
      query: (q) => q.where('courseId', isEqualTo: courseId).where('isPublished', isEqualTo: true),
    );
  }

  /// Best-effort course code lookup for audit context — never blocks or
  /// fails the caller; returns null if the course can't be found.
  Future<String?> _courseCode(String courseId) async {
    if (courseId.isEmpty) return null;
    try {
      final result = await _courseRepository.getById(courseId);
      if (result case Success(data: final course)) return course?.code;
    } catch (_) {
      // Best-effort only.
    }
    return null;
  }

  Future<Map<String, dynamic>> _auditContext(LearningContentModel content) async {
    final courseCode = await _courseCode(content.courseId);
    return {
      'materialTitle': content.title,
      'courseId': content.courseId,
      if (courseCode != null) 'courseCode': courseCode,
    };
  }

  Future<Result<void>> createContent(LearningContentModel content) async {
    final result = await save(content);
    if (result.isSuccess) {
      AuditLogService.instance.logCreate(
        module: AuditModules.learningMaterials,
        targetCollection: collection,
        targetId: content.contentId,
        targetTitle: content.title,
        newValues: await _auditContext(content),
      );
    }
    return result;
  }

  Future<Result<void>> updateContent(
    LearningContentModel previous,
    LearningContentModel updated,
  ) async {
    final result = await save(updated);
    if (result.isSuccess) {
      final context = await _auditContext(updated);
      AuditLogService.instance.logEdit(
        module: AuditModules.learningMaterials,
        targetCollection: collection,
        targetId: updated.contentId,
        targetTitle: updated.title,
        previousValues: {'title': previous.title, 'isPublished': previous.isPublished, ...context},
        newValues: {'title': updated.title, 'isPublished': updated.isPublished, ...context},
      );
    }
    return result;
  }

  Future<Result<void>> publish(LearningContentModel content) => _setLifecycle(
        content,
        content.copyWith(isPublished: true),
        AuditActionType.publish,
      );

  Future<Result<void>> unpublish(LearningContentModel content) => _setLifecycle(
        content,
        content.copyWith(isPublished: false),
        AuditActionType.unpublish,
      );

  Future<Result<void>> archive(LearningContentModel content) => _setLifecycle(
        content,
        content.copyWith(isArchived: true),
        AuditActionType.archive,
      );

  /// Clears whichever of archived/soft-deleted state [content] was in.
  Future<Result<void>> restore(LearningContentModel content) => _setLifecycle(
        content,
        content.copyWith(isArchived: false, isDeleted: false),
        AuditActionType.restore,
      );

  /// Soft delete — per Stage 3.6.1's Data Integrity rules, this never
  /// hard-deletes a learning material; [BaseRepository.delete] remains
  /// available directly for the rare explicit-purge case, which should
  /// call `AuditLogService.instance.logDelete(..., isHardDelete: true)`
  /// itself at the call site.
  Future<Result<void>> softDelete(LearningContentModel content) => _setLifecycle(
        content,
        content.copyWith(isDeleted: true),
        AuditActionType.delete,
      );

  Future<Result<void>> _setLifecycle(
    LearningContentModel previous,
    LearningContentModel updated,
    AuditActionType action,
  ) async {
    final result = await save(updated);
    if (result.isSuccess) {
      final context = await _auditContext(updated);
      AuditLogService.instance.log(
        action: action,
        module: AuditModules.learningMaterials,
        targetCollection: collection,
        targetId: updated.contentId,
        targetTitle: updated.title,
        newValues: context,
      );
    }
    return result;
  }

  /// Duplicates [content] into a brand-new document (new id, "Copy of"
  /// title, unpublished by default so the duplicate doesn't go live
  /// silently) and logs the duplication linking old → new id.
  Future<Result<LearningContentModel>> duplicate(LearningContentModel content) async {
    final newContentId = newId();
    final copy = LearningContentModel(
      contentId: newContentId,
      title: 'Copy of ${content.title}',
      type: content.type,
      courseId: content.courseId,
      fileUrl: content.fileUrl,
      thumbnailUrl: content.thumbnailUrl,
      uploadedBy: content.uploadedBy,
      isPublished: false,
      createdAt: DateTime.now(),
    );
    final result = await save(copy);
    if (result case Failure(message: final m)) return Result.failure(m);

    AuditLogService.instance.logDuplicate(
      module: AuditModules.learningMaterials,
      targetCollection: collection,
      targetId: content.contentId,
      targetTitle: content.title,
      newTargetId: newContentId,
    );
    return Result.success(copy);
  }

  /// Uploads/replaces [content]'s thumbnail and persists the new URL.
  Future<Result<String>> uploadThumbnail(LearningContentModel content, File file) async {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'thumbnail.jpg';
    final uploadResult = await _storageService.uploadFile(
      path: StoragePaths.learningContentThumbnail(content.contentId, fileName),
      file: file,
    );
    if (uploadResult case Success(data: final url)) {
      final updated = content.copyWith(thumbnailUrl: url);
      final saveResult = await save(updated);
      if (saveResult.isSuccess) {
        AuditLogService.instance.logUpload(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: content.contentId,
          targetTitle: content.title,
          newValues: {'thumbnailUrl': url},
        );
      }
    }
    return uploadResult;
  }

  /// Uploads a new file for [content] that doesn't have one yet. For
  /// swapping an existing file, use [replaceFile] instead — the audit
  /// action type differs (upload vs. edit-with-before/after) even
  /// though the storage call is identical.
  Future<Result<String>> uploadFile(LearningContentModel content, File file) async {
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';
    final uploadResult = await _storageService.uploadFile(
      path: StoragePaths.learningContentFile(content.contentId, fileName),
      file: file,
    );
    if (uploadResult case Success(data: final url)) {
      final updated = content.copyWith(fileUrl: url);
      final saveResult = await save(updated);
      if (saveResult.isSuccess) {
        AuditLogService.instance.logUpload(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: content.contentId,
          targetTitle: content.title,
          newValues: {'fileUrl': url},
        );
      }
    }
    return uploadResult;
  }

  /// Replaces an existing file, logging the previous URL as
  /// `previousValues` so the audit trail shows what was overwritten.
  Future<Result<String>> replaceFile(LearningContentModel content, File file) async {
    final previousUrl = content.fileUrl;
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';
    final uploadResult = await _storageService.uploadFile(
      path: StoragePaths.learningContentFile(content.contentId, fileName),
      file: file,
    );
    if (uploadResult case Success(data: final url)) {
      final updated = content.copyWith(fileUrl: url);
      final saveResult = await save(updated);
      if (saveResult.isSuccess) {
        AuditLogService.instance.logEdit(
          module: AuditModules.learningMaterials,
          targetCollection: collection,
          targetId: content.contentId,
          targetTitle: content.title,
          previousValues: {'fileUrl': previousUrl},
          newValues: {'fileUrl': url},
          summary: 'Replaced file for "${content.title}"',
        );
      }
    }
    return uploadResult;
  }
}

class ExamRepository extends BaseRepository<ExamModel> {
  ExamRepository() : super(AppConstants.examsCollection);

  @override
  ExamModel fromMap(Map<String, dynamic> map, String id) => ExamModel.fromMap(map, id);

  Stream<List<ExamModel>> watchByType(String typeId) {
    return streamCollection(
      query: (q) => q.where('type', isEqualTo: typeId).where('isActive', isEqualTo: true),
    );
  }
}

/// Stage 4.8A. Live, per-user, per-attempt session state — see
/// [ExamSessionModel] for why this is a separate collection from
/// `exam_attempts` rather than a status field on one document.
class ExamSessionRepository extends BaseRepository<ExamSessionModel> {
  ExamSessionRepository() : super(AppConstants.examSessionsCollection);

  @override
  ExamSessionModel fromMap(Map<String, dynamic> map, String id) => ExamSessionModel.fromMap(map, id);

  /// The single most important query for "Resume interrupted exam":
  /// is there already a non-terminal session for this user+exam? The
  /// runner should call this before creating a new session, and resume
  /// into whatever it finds instead.
  Future<ExamSessionModel?> findResumableSession(String userId, String examId) async {
    final result = await getWhere(
      query: (q) => q
          .where('userId', isEqualTo: userId)
          .where('examId', isEqualTo: examId)
          .where('status', whereIn: ['inProgress', 'paused']),
      limit: 1,
    );
    return switch (result) {
      Success(data: final data) => data.isEmpty ? null : data.first,
      Failure() => null,
    };
  }

  /// Every session a user could resume, across every exam — feeds a
  /// "Continue where you left off" list.
  Stream<List<ExamSessionModel>> watchResumableSessions(String userId) {
    return streamCollection(
      query: (q) => q.where('userId', isEqualTo: userId).where('status', whereIn: ['inProgress', 'paused']),
    );
  }

  /// Auto-save: the runner calls this on every answer/flag/bookmark/
  /// position change and on a periodic timer tick, not just at
  /// submission. Deliberately a plain [save] passthrough (not a
  /// partial-field update) so the session document — and therefore what
  /// "resume" restores — always reflects exactly one consistent
  /// in-memory state rather than a merge of partial writes.
  Future<Result<void>> autoSave(ExamSessionModel session) =>
      save(session.copyWith(lastSavedAt: DateTime.now()));
}

/// Stage 4.8A. The permanent, post-submission result record — see
/// [ExamAttemptModel] for why this is separate from `exam_sessions`.
class ExamAttemptRepository extends BaseRepository<ExamAttemptModel> {
  ExamAttemptRepository() : super(AppConstants.examAttemptsCollection);

  @override
  ExamAttemptModel fromMap(Map<String, dynamic> map, String id) => ExamAttemptModel.fromMap(map, id);

  /// Performance history — every attempt a user has ever submitted,
  /// most recent first.
  Stream<List<ExamAttemptModel>> watchHistoryForUser(String userId) {
    return streamCollection(
      query: (q) => q.where('userId', isEqualTo: userId).orderBy('submittedAt', descending: true),
    );
  }

  /// Attempts on one specific exam by one user — what "attempt limit"
  /// and "retake" checks both read.
  Future<List<ExamAttemptModel>> fetchAttemptsForExam(String userId, String examId) async {
    final result = await getWhere(
      query: (q) => q.where('userId', isEqualTo: userId).where('examId', isEqualTo: examId),
    );
    return switch (result) {
      Success(data: final data) => data,
      Failure() => const [],
    };
  }
}

class QuestionRepository extends BaseRepository<QuestionModel> {
  QuestionRepository() : super(AppConstants.questionsCollection);

  @override
  QuestionModel fromMap(Map<String, dynamic> map, String id) => QuestionModel.fromMap(map, id);

  /// Large exams should page through this rather than loading an entire
  /// bank at once.
  Future<List<QuestionModel>> fetchPageForExam(
    String examId, {
    int limit = 50,
  }) async {
    final result = await getWhere(
      query: (q) => q.where('examId', isEqualTo: examId),
      limit: limit,
    );
    return switch (result) {
      Success(data: final data) => data,
      Failure() => const [],
    };
  }
}
