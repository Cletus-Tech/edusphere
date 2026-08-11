import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/storage_paths.dart';
import '../core/enums/audit_action_type.dart';
import '../core/utils/result.dart';
import '../models/creator_profile_model.dart';
import '../services/audit/audit_log_service.dart';
import '../services/firebase/storage_service.dart';
import 'base_repository.dart';

/// Stage 6.3 — Creator Profile module.
///
/// `CreatorProfileRepository` (the singleton "About the Owner" doc)
/// follows the exact fixed-doc-id pattern `AppSettingsRepository`
/// already uses for `BrandingSettingsModel`/`AppConfigModel` — a plain
/// class with `watch`/`save`, not a `BaseRepository<T>` — since a
/// singleton doc has no per-item CRUD to inherit. The four list
/// collections (skills/achievements/documents/projects) each get a
/// real `BaseRepository<T>`, same as everything else in the app.
///
/// Stage 6.3 **Part 2** adds the CMS write paths every Admin screen
/// calls into: image upload/replace/remove for the singleton doc, and
/// create/update/delete/publish/reorder for each list collection.
/// Every one of them logs through [AuditLogService] — nothing in the
/// admin screens talks to Firestore/Storage directly, and nothing here
/// duplicates the read paths ([watch]/[watchAll]) Part 1 already wrote.
class CreatorProfileRepository {
  final StorageService _storage = StorageService();

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(AppConstants.creatorProfileCollection);

  Stream<CreatorProfileModel> watch() {
    return _collection.doc(AppConstants.creatorProfileDoc).snapshots().map(
          (snap) => snap.data() == null
              ? const CreatorProfileModel()
              : CreatorProfileModel.fromMap(snap.data()!, AppConstants.creatorProfileDoc),
        );
  }

  Future<CreatorProfileModel> fetch() async {
    final snap = await _collection.doc(AppConstants.creatorProfileDoc).get();
    return snap.data() == null
        ? const CreatorProfileModel()
        : CreatorProfileModel.fromMap(snap.data()!, AppConstants.creatorProfileDoc);
  }

  Future<void> save(CreatorProfileModel model, {CreatorProfileModel? previous}) async {
    await _collection.doc(AppConstants.creatorProfileDoc).set(model.toMap(), SetOptions(merge: true));
    AuditLogService.instance.log(
      action: AuditActionType.edit,
      module: AuditModules.creatorProfile,
      targetCollection: AppConstants.creatorProfileCollection,
      targetId: AppConstants.creatorProfileDoc,
      targetTitle: 'Creator Profile',
      previousValues: previous?.toMap(),
      newValues: model.toMap(),
    );
  }

  /// Publish/unpublish the whole profile — the master switch the public
  /// screen's `hasContent` check reads (§8, "Publishing Controls").
  Future<Result<void>> setPublished(CreatorProfileModel current, bool isPublished) async {
    final updated = current.copyWith(isPublished: isPublished);
    try {
      await save(updated, previous: current);
      isPublished
          ? AuditLogService.instance.logPublish(
              module: AuditModules.creatorProfile,
              targetCollection: AppConstants.creatorProfileCollection,
              targetId: AppConstants.creatorProfileDoc,
              targetTitle: 'Creator Profile',
            )
          : AuditLogService.instance.logUnpublish(
              module: AuditModules.creatorProfile,
              targetCollection: AppConstants.creatorProfileCollection,
              targetId: AppConstants.creatorProfileDoc,
              targetTitle: 'Creator Profile',
            );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Uploads (or replaces) the profile picture, removing the previous
  /// file from Storage once the new one is live so unused profile
  /// pictures don't pile up in the bucket.
  Future<Result<String>> uploadProfileImage(File file, {required CreatorProfileModel current}) =>
      _uploadImage(
        file: file,
        pathBuilder: StoragePaths.creatorProfileImage,
        previousUrl: current.profileImageUrl,
        apply: (url) => save(current.copyWith(profileImageUrl: url), previous: current),
      );

  Future<Result<String>> uploadCoverImage(File file, {required CreatorProfileModel current}) =>
      _uploadImage(
        file: file,
        pathBuilder: StoragePaths.creatorCoverImage,
        previousUrl: current.coverImageUrl,
        apply: (url) => save(current.copyWith(coverImageUrl: url), previous: current),
      );

  Future<Result<void>> removeProfileImage(CreatorProfileModel current) => _removeImage(
        previousUrl: current.profileImageUrl,
        apply: () => save(current.copyWith(profileImageUrl: ''), previous: current),
      );

  Future<Result<void>> removeCoverImage(CreatorProfileModel current) => _removeImage(
        previousUrl: current.coverImageUrl,
        apply: () => save(current.copyWith(coverImageUrl: ''), previous: current),
      );

  Future<Result<String>> _uploadImage({
    required File file,
    required String Function(String fileName) pathBuilder,
    required String previousUrl,
    required Future<void> Function(String url) apply,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final path = pathBuilder(fileName);
    final uploadResult = await _storage.uploadFile(path: path, file: file);
    if (uploadResult case Failure(message: final m)) return Result.failure(m);
    final url = (uploadResult as Success<String>).data;
    await apply(url);
    if (previousUrl.isNotEmpty && previousUrl != url) {
      await _deleteByUrlBestEffort(previousUrl);
    }
    AuditLogService.instance.logUpload(
      module: AuditModules.creatorProfile,
      targetCollection: AppConstants.creatorProfileCollection,
      targetId: AppConstants.creatorProfileDoc,
      targetTitle: 'Creator Profile',
      newValues: {'imagePath': path},
    );
    return Result.success(url);
  }

  Future<Result<void>> _removeImage({
    required String previousUrl,
    required Future<void> Function() apply,
  }) async {
    await apply();
    if (previousUrl.isNotEmpty) await _deleteByUrlBestEffort(previousUrl);
    AuditLogService.instance.logDelete(
      module: AuditModules.creatorProfile,
      targetCollection: AppConstants.creatorProfileCollection,
      targetId: AppConstants.creatorProfileDoc,
      targetTitle: 'Creator Profile image',
    );
    return const Result.success(null);
  }

  /// Best-effort: a download URL, not a raw path, is what's stored on
  /// the model, and Storage deletion needs the reference it came from.
  /// `deleteByUrl` handles that translation; failures here (already-
  /// deleted file, transient network) are swallowed on purpose — an
  /// orphaned Storage object is an acceptable cost, a blocked save is
  /// not.
  Future<void> _deleteByUrlBestEffort(String url) async {
    try {
      await _storage.deleteByUrl(url);
    } catch (_) {
      // Intentionally ignored — see doc comment above.
    }
  }
}

class CreatorSkillRepository extends BaseRepository<CreatorSkillModel> {
  CreatorSkillRepository() : super(AppConstants.creatorSkillsCollection);

  @override
  CreatorSkillModel fromMap(Map<String, dynamic> map, String id) => CreatorSkillModel.fromMap(map, id);

  /// All skills, any publish state — what the Admin manager needs.
  /// [CreatorProfileScreen] (the public page) filters `isPublished`
  /// itself after reading this same stream, rather than this repository
  /// exposing a second query — see that screen's comment.
  Stream<List<CreatorSkillModel>> watchAll() {
    return streamCollection(query: (q) => q.orderBy('sortOrder'));
  }

  Future<Result<void>> createSkill(CreatorSkillModel skill) async {
    final result = await save(skill);
    if (result.isSuccess) {
      AuditLogService.instance.logCreate(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: skill.skillId,
        targetTitle: skill.label,
        newValues: skill.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> updateSkill(CreatorSkillModel previous, CreatorSkillModel updated) async {
    final result = await save(updated);
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: updated.skillId,
        targetTitle: updated.label,
        previousValues: previous.toMap(),
        newValues: updated.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> deleteSkill(CreatorSkillModel skill) async {
    final result = await delete(skill.skillId);
    if (result.isSuccess) {
      AuditLogService.instance.logDelete(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: skill.skillId,
        targetTitle: skill.label,
      );
    }
    return result;
  }

  Future<Result<void>> setPublished(CreatorSkillModel skill, bool isPublished) async {
    final result = await save(skill.copyWith(isPublished: isPublished));
    if (result.isSuccess) {
      isPublished
          ? AuditLogService.instance.logPublish(
              module: AuditModules.creatorProfile, targetCollection: collection, targetId: skill.skillId, targetTitle: skill.label)
          : AuditLogService.instance.logUnpublish(
              module: AuditModules.creatorProfile, targetCollection: collection, targetId: skill.skillId, targetTitle: skill.label);
    }
    return result;
  }

  Future<Result<void>> reorder(List<CreatorSkillModel> orderedSkills) async {
    final result = await reorderSortOrder(orderedSkills.map((s) => s.skillId).toList());
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: 'reorder',
        targetTitle: 'Skills',
        summary: 'Reordered skills',
      );
    }
    return result;
  }
}

class CreatorAchievementRepository extends BaseRepository<CreatorAchievementModel> {
  CreatorAchievementRepository() : super(AppConstants.creatorAchievementsCollection);

  @override
  CreatorAchievementModel fromMap(Map<String, dynamic> map, String id) =>
      CreatorAchievementModel.fromMap(map, id);

  Stream<List<CreatorAchievementModel>> watchAll() {
    return streamCollection(query: (q) => q.orderBy('sortOrder'));
  }

  Future<Result<void>> createAchievement(CreatorAchievementModel achievement) async {
    final result = await save(achievement);
    if (result.isSuccess) {
      AuditLogService.instance.logCreate(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: achievement.achievementId,
        targetTitle: achievement.title,
        newValues: achievement.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> updateAchievement(CreatorAchievementModel previous, CreatorAchievementModel updated) async {
    final result = await save(updated);
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: updated.achievementId,
        targetTitle: updated.title,
        previousValues: previous.toMap(),
        newValues: updated.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> deleteAchievement(CreatorAchievementModel achievement) async {
    final result = await delete(achievement.achievementId);
    if (result.isSuccess) {
      AuditLogService.instance.logDelete(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: achievement.achievementId,
        targetTitle: achievement.title,
      );
    }
    return result;
  }

  Future<Result<void>> setPublished(CreatorAchievementModel achievement, bool isPublished) async {
    final result = await save(achievement.copyWith(isPublished: isPublished));
    if (result.isSuccess) {
      isPublished
          ? AuditLogService.instance.logPublish(
              module: AuditModules.creatorProfile,
              targetCollection: collection,
              targetId: achievement.achievementId,
              targetTitle: achievement.title)
          : AuditLogService.instance.logUnpublish(
              module: AuditModules.creatorProfile,
              targetCollection: collection,
              targetId: achievement.achievementId,
              targetTitle: achievement.title);
    }
    return result;
  }

  Future<Result<void>> reorder(List<CreatorAchievementModel> orderedAchievements) async {
    final result = await reorderSortOrder(orderedAchievements.map((a) => a.achievementId).toList());
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: 'reorder',
        targetTitle: 'Achievements',
        summary: 'Reordered achievements',
      );
    }
    return result;
  }
}

class CreatorDocumentRepository extends BaseRepository<CreatorDocumentModel> {
  final StorageService _storage = StorageService();

  CreatorDocumentRepository() : super(AppConstants.creatorDocumentsCollection);

  @override
  CreatorDocumentModel fromMap(Map<String, dynamic> map, String id) => CreatorDocumentModel.fromMap(map, id);

  Stream<List<CreatorDocumentModel>> watchAll() {
    return streamCollection(query: (q) => q.orderBy('sortOrder'));
  }

  /// Upload flow (§6): pick file -> upload -> save metadata. Creates the
  /// Firestore doc first (id is needed to build the Storage path via
  /// `StoragePaths.creatorDocument`), then attaches the uploaded URL —
  /// same create-then-attach ordering `MaterialEditorScreen` uses.
  Future<Result<CreatorDocumentModel>> uploadDocument({
    required File file,
    required String title,
    String description = '',
    void Function(double progress)? onProgress,
  }) async {
    final documentId = newId();
    final fileName = file.path.split('/').last;
    final uploadResult = await _storage.uploadFile(
      path: StoragePaths.creatorDocument(documentId, fileName),
      file: file,
      onProgress: onProgress,
    );
    if (uploadResult case Failure(message: final m)) return Result.failure(m);
    final url = (uploadResult as Success<String>).data;

    final doc = CreatorDocumentModel(
      documentId: documentId,
      title: title,
      description: description,
      storagePath: StoragePaths.creatorDocument(documentId, fileName),
      downloadUrl: url,
      uploadedAt: DateTime.now(),
    );
    final saveResult = await save(doc);
    if (saveResult case Failure(message: final m)) return Result.failure(m);

    AuditLogService.instance.logUpload(
      module: AuditModules.creatorProfile,
      targetCollection: collection,
      targetId: documentId,
      targetTitle: title,
      newValues: doc.toMap(),
    );
    return Result.success(doc);
  }

  /// Replaces the file behind an existing document entry, keeping its
  /// id/title/description/sortOrder, and removes the old file from
  /// Storage once the new one is uploaded.
  Future<Result<CreatorDocumentModel>> replaceFile(CreatorDocumentModel document, File file) async {
    final fileName = file.path.split('/').last;
    final path = StoragePaths.creatorDocument(document.documentId, fileName);
    final uploadResult = await _storage.uploadFile(path: path, file: file);
    if (uploadResult case Failure(message: final m)) return Result.failure(m);
    final url = (uploadResult as Success<String>).data;

    final updated = document.copyWith(storagePath: path, downloadUrl: url, uploadedAt: DateTime.now());
    final saveResult = await save(updated);
    if (saveResult case Failure(message: final m)) return Result.failure(m);

    if (document.storagePath.isNotEmpty && document.storagePath != path) {
      try {
        await _storage.deleteFile(document.storagePath);
      } catch (_) {
        // Best-effort — see CreatorProfileRepository._deleteByUrlBestEffort.
      }
    }
    AuditLogService.instance.logUpload(
      module: AuditModules.creatorProfile,
      targetCollection: collection,
      targetId: document.documentId,
      targetTitle: document.title,
      newValues: {'replacedFile': fileName},
    );
    return Result.success(updated);
  }

  Future<Result<void>> updateMetadata(CreatorDocumentModel previous, CreatorDocumentModel updated) async {
    final result = await save(updated);
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: updated.documentId,
        targetTitle: updated.title,
        previousValues: previous.toMap(),
        newValues: updated.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> deleteDocument(CreatorDocumentModel document) async {
    final result = await delete(document.documentId);
    if (result.isSuccess) {
      if (document.storagePath.isNotEmpty) {
        try {
          await _storage.deleteFile(document.storagePath);
        } catch (_) {
          // Best-effort — see CreatorProfileRepository._deleteByUrlBestEffort.
        }
      }
      AuditLogService.instance.logDelete(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: document.documentId,
        targetTitle: document.title,
      );
    }
    return result;
  }

  Future<Result<void>> setPublished(CreatorDocumentModel document, bool isPublished) async {
    final result = await save(document.copyWith(isPublished: isPublished));
    if (result.isSuccess) {
      isPublished
          ? AuditLogService.instance.logPublish(
              module: AuditModules.creatorProfile,
              targetCollection: collection,
              targetId: document.documentId,
              targetTitle: document.title)
          : AuditLogService.instance.logUnpublish(
              module: AuditModules.creatorProfile,
              targetCollection: collection,
              targetId: document.documentId,
              targetTitle: document.title);
    }
    return result;
  }

  Future<Result<void>> reorder(List<CreatorDocumentModel> orderedDocuments) async {
    final result = await reorderSortOrder(orderedDocuments.map((d) => d.documentId).toList());
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: 'reorder',
        targetTitle: 'Documents',
        summary: 'Reordered documents',
      );
    }
    return result;
  }
}

class CreatorProjectRepository extends BaseRepository<CreatorProjectModel> {
  final StorageService _storage = StorageService();

  CreatorProjectRepository() : super(AppConstants.creatorProjectsCollection);

  @override
  CreatorProjectModel fromMap(Map<String, dynamic> map, String id) => CreatorProjectModel.fromMap(map, id);

  Stream<List<CreatorProjectModel>> watchAll() {
    return streamCollection(query: (q) => q.orderBy('sortOrder'));
  }

  Future<Result<void>> createProject(CreatorProjectModel project) async {
    final result = await save(project);
    if (result.isSuccess) {
      AuditLogService.instance.logCreate(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: project.projectId,
        targetTitle: project.title,
        newValues: project.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> updateProject(CreatorProjectModel previous, CreatorProjectModel updated) async {
    final result = await save(updated);
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: updated.projectId,
        targetTitle: updated.title,
        previousValues: previous.toMap(),
        newValues: updated.toMap(),
      );
    }
    return result;
  }

  Future<Result<void>> deleteProject(CreatorProjectModel project) async {
    final result = await delete(project.projectId);
    if (result.isSuccess) {
      if (project.imageUrl.isNotEmpty) {
        try {
          await _storage.deleteByUrl(project.imageUrl);
        } catch (_) {
          // Best-effort — see CreatorProfileRepository._deleteByUrlBestEffort.
        }
      }
      AuditLogService.instance.logDelete(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: project.projectId,
        targetTitle: project.title,
      );
    }
    return result;
  }

  Future<Result<void>> setPublished(CreatorProjectModel project, bool isPublished) async {
    final result = await save(project.copyWith(isPublished: isPublished));
    if (result.isSuccess) {
      isPublished
          ? AuditLogService.instance.logPublish(
              module: AuditModules.creatorProfile, targetCollection: collection, targetId: project.projectId, targetTitle: project.title)
          : AuditLogService.instance.logUnpublish(
              module: AuditModules.creatorProfile,
              targetCollection: collection,
              targetId: project.projectId,
              targetTitle: project.title);
    }
    return result;
  }

  Future<Result<void>> reorder(List<CreatorProjectModel> orderedProjects) async {
    final result = await reorderSortOrder(orderedProjects.map((p) => p.projectId).toList());
    if (result.isSuccess) {
      AuditLogService.instance.logEdit(
        module: AuditModules.creatorProfile,
        targetCollection: collection,
        targetId: 'reorder',
        targetTitle: 'Projects',
        summary: 'Reordered projects',
      );
    }
    return result;
  }

  /// Uploads a project's cover image, keyed by the project's own id
  /// (`StoragePaths.creatorProjectImage`) so it can be replaced later
  /// without orphaning the old file under a random name.
  Future<Result<String>> uploadProjectImage(String projectId, File file, {String? previousUrl}) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final uploadResult = await _storage.uploadFile(path: StoragePaths.creatorProjectImage(projectId, fileName), file: file);
    if (uploadResult case Failure(message: final m)) return Result.failure(m);
    final url = (uploadResult as Success<String>).data;
    if (previousUrl != null && previousUrl.isNotEmpty && previousUrl != url) {
      try {
        await _storage.deleteByUrl(previousUrl);
      } catch (_) {
        // Best-effort — see CreatorProfileRepository._deleteByUrlBestEffort.
      }
    }
    return Result.success(url);
  }
}
