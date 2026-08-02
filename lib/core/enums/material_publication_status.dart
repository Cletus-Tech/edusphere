import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Lifecycle state of a `learning_materials/{materialId}` document.
/// Stage 3.5 — Learning Materials Module, Part 1 (Publishing System).
///
/// [scheduled] is a distinct state from [draft] so the Admin CMS can
/// show "goes live on <date>" instead of treating a future-dated item
/// as an ordinary draft; [LearningMaterialRepository] is responsible
/// for flipping a due [scheduled] item to [published] (see
/// `LearningMaterialRepository.publishDueScheduled`).
enum MaterialPublicationStatus {
  draft,
  published,
  scheduled,
  archived;

  String get id => name;

  static MaterialPublicationStatus fromId(String id) => MaterialPublicationStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => MaterialPublicationStatus.draft,
      );

  String get label => switch (this) {
        MaterialPublicationStatus.draft => 'Draft',
        MaterialPublicationStatus.published => 'Published',
        MaterialPublicationStatus.scheduled => 'Scheduled',
        MaterialPublicationStatus.archived => 'Archived',
      };

  IconData get icon => switch (this) {
        MaterialPublicationStatus.draft => Icons.edit_note_rounded,
        MaterialPublicationStatus.published => Icons.check_circle_rounded,
        MaterialPublicationStatus.scheduled => Icons.schedule_rounded,
        MaterialPublicationStatus.archived => Icons.archive_rounded,
      };

  Color get color => switch (this) {
        MaterialPublicationStatus.draft => AppColors.textSecondary,
        MaterialPublicationStatus.published => AppColors.success,
        MaterialPublicationStatus.scheduled => AppColors.highlightOrange,
        MaterialPublicationStatus.archived => AppColors.error,
      };
}

/// Who can see a published material. Kept as a small enum (rather than
/// a free-form string) so the Admin CMS can offer a fixed picker;
/// `firestore.rules` only enforces the coarse published/staff split —
/// [everyone] vs [institutionOnly] is a client-side/query-level filter
/// on top of that, same trust boundary as the rest of this codebase's
/// "UI-level gating, rules are the source of truth" convention.
enum MaterialVisibility {
  everyone,
  institutionOnly,
  courseOnly;

  String get id => name;

  static MaterialVisibility fromId(String id) => MaterialVisibility.values.firstWhere(
        (v) => v.id == id,
        orElse: () => MaterialVisibility.everyone,
      );

  String get label => switch (this) {
        MaterialVisibility.everyone => 'Everyone',
        MaterialVisibility.institutionOnly => 'My Institution Only',
        MaterialVisibility.courseOnly => 'Enrolled Course Only',
      };
}
