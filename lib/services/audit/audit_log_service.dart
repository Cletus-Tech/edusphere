import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;

import '../../core/constants/app_constants.dart';
import '../../core/enums/audit_action_type.dart';
import '../../core/utils/device_context.dart';
import '../../core/utils/result.dart';
import '../../models/audit_log_model.dart';
import '../../repositories/audit_log_repository.dart';
import '../../repositories/user_repository.dart';
import '../firebase/auth_service.dart';

/// Records who did what, to what, and when — the Stage 3.6.1 audit
/// trail every admin-facing module (present and future) writes through.
///
/// ```dart
/// AuditLogService.instance.logPublish(
///   module: AuditModules.learningMaterials,
///   targetCollection: AppConstants.learningMaterialsCollection,
///   targetId: material.materialId,
///   targetTitle: material.title,
/// );
/// ```
///
/// Design rules straight from the spec:
/// - **Never blocks the caller.** [log] and every `logX` convenience
///   method are synchronous, fire-and-forget calls — the actual Firestore
///   write happens on an un-awaited `Future`.
/// - **Never fails the primary action.** Every exception inside the
///   write path is caught and swallowed (debug-logged only). A missing
///   audit entry is an acceptable failure mode; a rolled-back publish/
///   delete/etc. because logging hiccuped is not.
/// - **Attribution is self-reported.** The signed-in user's uid/role/name
///   are looked up at write time — nothing here trusts a caller-supplied
///   identity, matching `firestore.rules`' `request.resource.data.userId
///   == uid()` check on `audit_logs`.
///
/// Stage 3.6.1 shipped the service, repository, model, and the Audit Log
/// screen without wiring `logX` calls into existing modules. **Stage
/// 3.6.2 does that wiring** (see `docs/STAGE_3.6.2_CHANGELOG.md`) —
/// `auth_service.dart`, `branding_service.dart`, and
/// `feature_flag_service.dart` all call through here now — and adds:
/// - **Operation Tracking (§7):** every entry now carries an
///   [AuditLogModel.operationId], [AuditLogModel.sessionId],
///   [AuditLogModel.appVersion], [AuditLogModel.deviceType]/
///   [AuditLogModel.deviceModel], and optionally a
///   [AuditLogModel.durationMs]. `operationId` defaults to a fresh id
///   per call; pass the *same* id (from [newOperationId]) to every
///   `logX` call belonging to one bulk action so they can be grouped
///   later.
/// - **Reusable hooks (Parts 5-6):** `logUserX`/community `logX` methods
///   below have no call sites yet — there's no User Management or
///   Community moderation UI in this codebase snapshot to wire them
///   into — but they exist now so that UI can call straight into them
///   without adding new logging logic of its own.
class AuditLogService {
  AuditLogService._();
  static final AuditLogService instance = AuditLogService._();

  final AuditLogRepository _repository = AuditLogRepository();
  final UserRepository _userRepository = UserRepository();
  final AuthService _authService = AuthService();

  String get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform.* throws on unsupported embedders — fall through.
    }
    return 'unknown';
  }

  /// A fresh id for one logical operation (e.g. bulk-archiving 40
  /// materials). Generate one, then pass it as `operationId` to every
  /// `logX` call that's part of the same operation.
  String newOperationId() => DeviceContext.instance.newOperationId();

  /// The general-purpose entry point every `logX` convenience method
  /// below funnels into. Prefer the convenience methods where one fits;
  /// call this directly for an action type/module combination none of
  /// them cover yet.
  void log({
    required AuditActionType action,
    required String module,
    String targetCollection = '',
    String targetId = '',
    String? targetTitle,
    String? summary,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
    String? actingUid,
    String? operationId,
    Duration? duration,
  }) {
    unawaited(_write(
      action: action,
      module: module,
      targetCollection: targetCollection,
      targetId: targetId,
      targetTitle: targetTitle,
      summary: summary,
      previousValues: previousValues,
      newValues: newValues,
      actingUid: actingUid,
      operationId: operationId,
      duration: duration,
    ));
  }

  Future<void> _write({
    required AuditActionType action,
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    String? summary,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
    String? actingUid,
    String? operationId,
    Duration? duration,
  }) async {
    try {
      final uid = actingUid ?? _authService.currentUser?.uid;
      if (uid == null || uid.isEmpty) return; // nothing to attribute; skip silently

      String? role;
      String name = _authService.currentUser?.displayName ??
          _authService.currentUser?.email ??
          'Unknown user';
      final profileResult = await _userRepository.getById(uid);
      if (profileResult case Success(data: final profile)) {
        if (profile != null) {
          if (profile.roles.isNotEmpty) role = profile.roles.first.id;
          if (profile.fullName.isNotEmpty) name = profile.fullName;
        }
      }

      // Best-effort context — never allowed to delay or break the write;
      // DeviceContext itself swallows every plugin failure internally.
      String? appVersion;
      String? deviceType;
      String? deviceModel;
      try {
        appVersion = await DeviceContext.instance.appVersion;
        deviceType = await DeviceContext.instance.deviceType;
        deviceModel = await DeviceContext.instance.deviceModel;
      } catch (_) {
        // Left null — see class doc, §8 Error Safety.
      }

      final entry = AuditLogModel(
        logId: _repository.newId(),
        userId: uid,
        userName: name,
        userRole: role,
        actionType: action,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        summary: summary ?? _defaultSummary(action, targetTitle),
        previousValues: previousValues,
        newValues: newValues,
        platform: _platform,
        createdAt: DateTime.now(),
        operationId: operationId ?? newOperationId(),
        sessionId: DeviceContext.instance.sessionId,
        appVersion: appVersion,
        deviceType: deviceType,
        deviceModel: deviceModel,
        durationMs: duration?.inMilliseconds,
      );

      final result = await _repository.record(entry);
      switch (result) {
        case Failure(message: final message):
          if (kDebugMode) debugPrint('AuditLogService: write failed — $message');
        case Success():
          break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuditLogService: failed to record log — $e');
      // Intentionally swallowed past this point — a logging failure must
      // never surface to the user or roll back the action it describes.
    }
  }

  String _defaultSummary(AuditActionType action, String? targetTitle) {
    final subject = (targetTitle == null || targetTitle.isEmpty) ? 'an item' : '"$targetTitle"';
    return '${action.label} $subject';
  }

  // ---------------------------------------------------------------------
  // Convenience wrappers — one per action type the spec lists. Callers
  // that already have a natural target (a material, a user profile, a
  // settings doc, ...) reach for these; [log] stays available for
  // anything more bespoke. Every wrapper accepts the same
  // `operationId`/`duration` pass-through as [log] (§7).
  // ---------------------------------------------------------------------

  void logCreate({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    Map<String, dynamic>? newValues,
    String? summary,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.create,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        newValues: newValues,
        summary: summary,
        operationId: operationId,
        duration: duration,
      );

  void logEdit({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
    String? summary,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.edit,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        previousValues: previousValues,
        newValues: newValues,
        summary: summary,
        operationId: operationId,
        duration: duration,
      );

  void logPublish({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.publish,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        operationId: operationId,
        duration: duration,
      );

  void logUnpublish({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.unpublish,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        operationId: operationId,
        duration: duration,
      );

  void logArchive({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.archive,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        operationId: operationId,
        duration: duration,
      );

  void logRestore({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.restore,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        operationId: operationId,
        duration: duration,
      );

  void logDuplicate({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    String? newTargetId,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.duplicate,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        newValues: newTargetId == null ? null : {'duplicatedAsId': newTargetId},
        operationId: operationId,
        duration: duration,
      );

  /// For a soft delete — per the spec's Data Integrity rules, this
  /// codebase should never hard-delete without a trace. Pass
  /// [isHardDelete] only for the rare, explicitly-permanent case (e.g. a
  /// superAdmin purge) so it reads distinctly in the log.
  void logDelete({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    bool isHardDelete = false,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.delete,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        summary: isHardDelete
            ? 'Permanently deleted ${targetTitle == null || targetTitle.isEmpty ? 'an item' : '"$targetTitle"'}'
            : null,
        operationId: operationId,
        duration: duration,
      );

  /// Call this **before** `AuthService.signOut()`/sign-in completes state
  /// changes elsewhere, or pass [uid] explicitly — `currentUser` is only
  /// guaranteed non-null while the session is still active.
  void logLogin({String? uid}) {
    final id = uid ?? _authService.currentUser?.uid;
    if (id == null) return;
    log(
      action: AuditActionType.login,
      module: AuditModules.authentication,
      targetCollection: AppConstants.usersCollection,
      targetId: id,
      summary: 'Signed in',
      actingUid: id,
    );
  }

  /// [uid] is required (rather than falling back to `currentUser`)
  /// because by the time sign-out is confirmed, `currentUser` is
  /// typically already null.
  void logLogout({required String uid}) => log(
        action: AuditActionType.logout,
        module: AuditModules.authentication,
        targetCollection: AppConstants.usersCollection,
        targetId: uid,
        summary: 'Signed out',
        actingUid: uid,
      );

  void logUpload({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
    Map<String, dynamic>? newValues,
    String? operationId,
    Duration? duration,
  }) =>
      log(
        action: AuditActionType.upload,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        newValues: newValues,
        operationId: operationId,
        duration: duration,
      );

  void logDownload({
    required String module,
    required String targetCollection,
    required String targetId,
    String? targetTitle,
  }) =>
      log(
        action: AuditActionType.download,
        module: module,
        targetCollection: targetCollection,
        targetId: targetId,
        targetTitle: targetTitle,
      );

  void logSettingsChange({
    required String targetId,
    String? targetTitle,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
  }) =>
      log(
        action: AuditActionType.settingsChanged,
        module: AuditModules.settings,
        targetCollection: AppConstants.settingsCollection,
        targetId: targetId,
        targetTitle: targetTitle,
        previousValues: previousValues,
        newValues: newValues,
      );

  // ---------------------------------------------------------------------
  // Stage 3.6.2 Part 2 — Authentication additions.
  // ---------------------------------------------------------------------

  /// [email] is logged for identification only — see class doc, never a
  /// password or credential of any kind.
  void logFailedLogin({String? email}) => log(
        action: AuditActionType.loginFailed,
        module: AuditModules.authentication,
        targetCollection: AppConstants.usersCollection,
        summary: email == null || email.isEmpty
            ? 'Failed sign-in attempt'
            : 'Failed sign-in attempt for $email',
        // No uid to attribute to yet (sign-in didn't succeed) — write
        // under a synthetic actor id instead of skipping the entry
        // outright; there is deliberately no real user document for this.
        actingUid: 'unauthenticated',
      );

  void logPasswordResetRequested({required String uid, String? email}) => log(
        action: AuditActionType.passwordResetRequested,
        module: AuditModules.authentication,
        targetCollection: AppConstants.usersCollection,
        targetId: uid,
        summary: email == null ? 'Requested a password reset' : 'Requested a password reset for $email',
        actingUid: uid,
      );

  void logPasswordChanged({required String uid}) => log(
        action: AuditActionType.passwordChanged,
        module: AuditModules.authentication,
        targetCollection: AppConstants.usersCollection,
        targetId: uid,
        summary: 'Changed password',
        actingUid: uid,
      );

  // ---------------------------------------------------------------------
  // Stage 3.6.2 Part 3 — Branding additions.
  // ---------------------------------------------------------------------

  /// Call with just the fields that changed in [newValues]/[previousValues]
  /// (logo, splash image, theme colors, contact info, social links,
  /// website, WhatsApp number, email, phone) rather than the whole
  /// branding document, so the log stays readable.
  void logBrandingChange({
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
    String? summary,
  }) =>
      log(
        action: AuditActionType.brandingChanged,
        module: AuditModules.branding,
        targetCollection: AppConstants.settingsCollection,
        targetId: AppConstants.brandingSettingsDoc,
        previousValues: previousValues,
        newValues: newValues,
        summary: summary,
      );

  // ---------------------------------------------------------------------
  // Stage 3.6.2 Part 4 — Feature Flags additions.
  // ---------------------------------------------------------------------

  void logFeatureFlagChange({
    required String flagId,
    String? flagLabel,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
  }) =>
      log(
        action: AuditActionType.featureFlagChanged,
        module: AuditModules.featureFlags,
        targetCollection: AppConstants.featureFlagsCollection,
        targetId: flagId,
        targetTitle: flagLabel,
        previousValues: previousValues,
        newValues: newValues,
      );

  // ---------------------------------------------------------------------
  // Stage 3.6.2 Part 5 — User Management: reusable hooks only.
  // No user-management UI exists in this codebase snapshot yet; these
  // exist so that UI, whenever it's built, logs through here from day
  // one instead of adding new logging logic of its own.
  // ---------------------------------------------------------------------

  void logUserCreated({required String targetUid, String? targetName, Map<String, dynamic>? newValues}) =>
      logCreate(
        module: AuditModules.users,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        newValues: newValues,
      );

  void logUserUpdated({
    required String targetUid,
    String? targetName,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
  }) =>
      logEdit(
        module: AuditModules.users,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        previousValues: previousValues,
        newValues: newValues,
      );

  void logUserSuspended({required String targetUid, String? targetName, String? reason}) => log(
        action: AuditActionType.archive,
        module: AuditModules.users,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        summary: reason == null ? 'Suspended user' : 'Suspended user — $reason',
      );

  void logUserRestored({required String targetUid, String? targetName}) => logRestore(
        module: AuditModules.users,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
      );

  void logUserDeleted({required String targetUid, String? targetName, bool isHardDelete = false}) =>
      logDelete(
        module: AuditModules.users,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        isHardDelete: isHardDelete,
      );

  void logRoleChanged({
    required String targetUid,
    String? targetName,
    required List<String> previousRoles,
    required List<String> newRoles,
  }) =>
      logEdit(
        module: AuditModules.users,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        previousValues: {'roles': previousRoles},
        newValues: {'roles': newRoles},
        summary: 'Changed role for ${targetName ?? targetUid}',
      );

  // ---------------------------------------------------------------------
  // Stage 3.6.2 Part 6 — Community: reusable hooks only. No moderation
  // UI exists in this codebase snapshot yet — see Part 5's note above.
  // ---------------------------------------------------------------------

  void logPostDeleted({required String postId, String? postTitle, bool isHardDelete = false}) => logDelete(
        module: AuditModules.moderation,
        targetCollection: AppConstants.communitiesCollection,
        targetId: postId,
        targetTitle: postTitle,
        isHardDelete: isHardDelete,
      );

  void logCommentDeleted({required String commentId, String? postId}) => logDelete(
        module: AuditModules.moderation,
        targetCollection: AppConstants.commentsCollection,
        targetId: commentId,
        targetTitle: postId == null ? null : 'Comment on $postId',
      );

  void logUserMuted({required String targetUid, String? targetName, Duration? muteDuration}) => log(
        action: AuditActionType.edit,
        module: AuditModules.moderation,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        summary: muteDuration == null ? 'Muted user' : 'Muted user for ${muteDuration.inHours}h',
      );

  void logUserBanned({required String targetUid, String? targetName, String? reason}) => log(
        action: AuditActionType.archive,
        module: AuditModules.moderation,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
        summary: reason == null ? 'Banned user' : 'Banned user — $reason',
      );

  void logUserUnbanned({required String targetUid, String? targetName}) => logRestore(
        module: AuditModules.moderation,
        targetCollection: AppConstants.usersCollection,
        targetId: targetUid,
        targetTitle: targetName,
      );

  void logCommunityCreated({required String communityId, String? communityName}) => logCreate(
        module: AuditModules.community,
        targetCollection: AppConstants.communitiesCollection,
        targetId: communityId,
        targetTitle: communityName,
      );
}
