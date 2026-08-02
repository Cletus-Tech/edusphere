import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Kind of content a `learning_materials/{materialId}` document carries.
/// Stage 3.5 — Learning Materials Module.
///
/// Every case carries its own label/icon/color/typical-extensions so the
/// Learning Library, Material Card, and Admin CMS all read from one
/// source of truth instead of re-declaring switch statements — the same
/// convention [AuditActionType] already establishes.
enum LearningMaterialType {
  pdf,
  video,
  image,
  audio,
  document,
  presentation,
  archive,
  link,
  richText;

  String get id => name;

  static LearningMaterialType fromId(String id) => LearningMaterialType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => LearningMaterialType.document,
      );

  /// Best-guess type from a picked file's extension — used by the admin
  /// uploader so staff don't have to hand-pick a type for an obvious
  /// file. Falls back to [document] for anything unrecognized.
  static LearningMaterialType fromExtension(String extension) {
    final ext = extension.toLowerCase();
    for (final type in LearningMaterialType.values) {
      if (type.extensions.contains(ext)) return type;
    }
    return LearningMaterialType.document;
  }

  String get label => switch (this) {
        LearningMaterialType.pdf => 'PDF',
        LearningMaterialType.video => 'Video',
        LearningMaterialType.image => 'Image',
        LearningMaterialType.audio => 'Audio',
        LearningMaterialType.document => 'Document',
        LearningMaterialType.presentation => 'Presentation',
        LearningMaterialType.archive => 'Resource Package',
        LearningMaterialType.link => 'External Link',
        LearningMaterialType.richText => 'Rich Text',
      };

  IconData get icon => switch (this) {
        LearningMaterialType.pdf => Icons.picture_as_pdf_rounded,
        LearningMaterialType.video => Icons.play_circle_rounded,
        LearningMaterialType.image => Icons.image_rounded,
        LearningMaterialType.audio => Icons.headphones_rounded,
        LearningMaterialType.document => Icons.description_rounded,
        LearningMaterialType.presentation => Icons.slideshow_rounded,
        LearningMaterialType.archive => Icons.folder_zip_rounded,
        LearningMaterialType.link => Icons.link_rounded,
        LearningMaterialType.richText => Icons.article_rounded,
      };

  Color get color => switch (this) {
        LearningMaterialType.pdf => AppColors.error,
        LearningMaterialType.video => AppColors.secondaryIndigo,
        LearningMaterialType.image => AppColors.accentGreen,
        LearningMaterialType.audio => AppColors.highlightOrange,
        LearningMaterialType.document => AppColors.primaryBlue,
        LearningMaterialType.presentation => AppColors.highlightOrange,
        LearningMaterialType.archive => AppColors.textSecondary,
        LearningMaterialType.link => AppColors.primaryBlue,
        LearningMaterialType.richText => AppColors.accentGreen,
      };

  /// Whether this type stores its content as an uploaded file (as
  /// opposed to [link]'s URL field or [richText]'s inline content).
  bool get isFileBased => this != LearningMaterialType.link && this != LearningMaterialType.richText;

  List<String> get extensions => switch (this) {
        LearningMaterialType.pdf => const ['pdf'],
        LearningMaterialType.video => const ['mp4', 'mov', 'mkv', 'webm', 'avi'],
        LearningMaterialType.image => const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        LearningMaterialType.audio => const ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
        LearningMaterialType.document => const ['doc', 'docx', 'txt', 'rtf'],
        LearningMaterialType.presentation => const ['ppt', 'pptx', 'key'],
        LearningMaterialType.archive => const ['zip', 'rar', '7z'],
        LearningMaterialType.link => const [],
        LearningMaterialType.richText => const [],
      };
}
