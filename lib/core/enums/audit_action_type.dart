import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Every action [AuditLogService] can record (Stage 3.6.1 — Admin
/// Productivity Pack & Data Integrity). Mirrors the spec's explicit list:
/// create, edit, publish, unpublish, archive, restore, duplicate, delete
/// (soft delete), login, logout, upload, download, and settings changes.
///
/// Each case carries its own label/icon/color so the Audit Log screen,
/// filter sheet, and list tile all read from one source of truth instead
/// of re-declaring switch statements — the same convention
/// `MaterialPublicationStatus`/`LearningMaterialType` already establish.
enum AuditActionType {
  create,
  edit,
  publish,
  unpublish,
  archive,
  restore,
  duplicate,
  delete,
  login,
  logout,
  upload,
  download,
  settingsChanged,
  // Stage 3.6.2 — Audit Integration additions.
  loginFailed,
  passwordResetRequested,
  passwordChanged,
  brandingChanged,
  featureFlagChanged,
  /// Fallback for a stored id this build of the app doesn't recognize
  /// (e.g. a newer app version wrote an action type this one predates).
  /// Never written intentionally — only ever a decode fallback.
  other;

  String get id => name;

  static AuditActionType fromId(String id) => AuditActionType.values.firstWhere(
        (a) => a.id == id,
        orElse: () => AuditActionType.other,
      );

  String get label => switch (this) {
        AuditActionType.create => 'Created',
        AuditActionType.edit => 'Edited',
        AuditActionType.publish => 'Published',
        AuditActionType.unpublish => 'Unpublished',
        AuditActionType.archive => 'Archived',
        AuditActionType.restore => 'Restored',
        AuditActionType.duplicate => 'Duplicated',
        AuditActionType.delete => 'Deleted',
        AuditActionType.login => 'Signed in',
        AuditActionType.logout => 'Signed out',
        AuditActionType.upload => 'Uploaded',
        AuditActionType.download => 'Downloaded',
        AuditActionType.settingsChanged => 'Changed settings',
        AuditActionType.loginFailed => 'Failed sign-in',
        AuditActionType.passwordResetRequested => 'Requested password reset',
        AuditActionType.passwordChanged => 'Changed password',
        AuditActionType.brandingChanged => 'Changed branding',
        AuditActionType.featureFlagChanged => 'Changed feature flag',
        AuditActionType.other => 'Other',
      };

  IconData get icon => switch (this) {
        AuditActionType.create => Icons.add_circle_rounded,
        AuditActionType.edit => Icons.edit_rounded,
        AuditActionType.publish => Icons.publish_rounded,
        AuditActionType.unpublish => Icons.unpublished_rounded,
        AuditActionType.archive => Icons.archive_rounded,
        AuditActionType.restore => Icons.restore_rounded,
        AuditActionType.duplicate => Icons.copy_all_rounded,
        AuditActionType.delete => Icons.delete_rounded,
        AuditActionType.login => Icons.login_rounded,
        AuditActionType.logout => Icons.logout_rounded,
        AuditActionType.upload => Icons.cloud_upload_rounded,
        AuditActionType.download => Icons.cloud_download_rounded,
        AuditActionType.settingsChanged => Icons.tune_rounded,
        AuditActionType.loginFailed => Icons.error_rounded,
        AuditActionType.passwordResetRequested => Icons.lock_reset_rounded,
        AuditActionType.passwordChanged => Icons.password_rounded,
        AuditActionType.brandingChanged => Icons.palette_rounded,
        AuditActionType.featureFlagChanged => Icons.flag_rounded,
        AuditActionType.other => Icons.more_horiz_rounded,
      };

  Color get color => switch (this) {
        AuditActionType.create => AppColors.success,
        AuditActionType.edit => AppColors.primaryBlue,
        AuditActionType.publish => AppColors.success,
        AuditActionType.unpublish => AppColors.highlightOrange,
        AuditActionType.archive => AppColors.highlightOrange,
        AuditActionType.restore => AppColors.accentGreen,
        AuditActionType.duplicate => AppColors.secondaryIndigo,
        AuditActionType.delete => AppColors.error,
        AuditActionType.login => AppColors.accentGreen,
        AuditActionType.logout => AppColors.textSecondary,
        AuditActionType.upload => AppColors.primaryBlue,
        AuditActionType.download => AppColors.secondaryIndigo,
        AuditActionType.settingsChanged => AppColors.highlightOrange,
        AuditActionType.loginFailed => AppColors.error,
        AuditActionType.passwordResetRequested => AppColors.highlightOrange,
        AuditActionType.passwordChanged => AppColors.primaryBlue,
        AuditActionType.brandingChanged => AppColors.secondaryIndigo,
        AuditActionType.featureFlagChanged => AppColors.primaryBlue,
        AuditActionType.other => AppColors.textSecondary,
      };
}

/// Known feature-module ids audit entries can be grouped/filtered by.
/// Deliberately a set of `String` constants rather than an enum — the
/// spec's whole point is that "future modules (Community, CBT, AI
/// Tutor, JAMB, WAEC, Marketplace, etc.) can plug into the same
/// management experience", and a new module should be able to log
/// against its own id without an enum edit/app-wide rebuild here.
/// [all]/[label] cover the modules that exist as of this stage; an
/// unrecognized id still round-trips fine, [label] just title-cases it.
class AuditModules {
  AuditModules._();

  static const String learningMaterials = 'learning_materials';
  static const String authentication = 'auth';
  static const String settings = 'settings';
  static const String users = 'users';
  static const String community = 'community';
  static const String moderation = 'moderation';
  static const String storage = 'storage';
  static const String branding = 'branding';
  static const String featureFlags = 'feature_flags';

  static const List<String> all = [
    learningMaterials,
    authentication,
    settings,
    users,
    community,
    moderation,
    storage,
    branding,
    featureFlags,
  ];

  static String label(String id) => switch (id) {
        learningMaterials => 'Learning Materials',
        authentication => 'Authentication',
        settings => 'Settings',
        users => 'Users & Roles',
        community => 'Community',
        moderation => 'Moderation',
        storage => 'Storage',
        branding => 'Branding',
        featureFlags => 'Feature Flags',
        _ when id.isEmpty => 'General',
        _ => id
            .split('_')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' '),
      };
}
