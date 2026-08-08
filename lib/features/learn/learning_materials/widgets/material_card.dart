import 'package:flutter/material.dart';
import '../../../../core/enums/learning_material_type.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../models/learning_material_model.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../theme/app_theme.dart';

/// One material in the Learning Library grid/list. Deliberately built
/// per the spec's "professional platform" rule: no emoji, no default
/// Material clipart — a tinted, type-colored icon tile stands in for a
/// thumbnail when none is set, and a real network thumbnail is used
/// when [LearningMaterialModel.thumbnailUrl] is present.
class MaterialCard extends StatelessWidget {
  final LearningMaterialModel material;
  final VoidCallback onTap;

  const MaterialCard({super.key, required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final type = material.type;

    return CustomCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      // Stage B6 — reuses the accentColor stripe param B2/B4 already
      // added to CustomCard (previously only used on Home's "Recently
      // Added" rows) so the Library grid carries the same per-type
      // identity treatment instead of a flat, untinted edge.
      accentColor: type.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _Preview(material: material),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(label: type.label, accent: type.color),
                    const Spacer(),
                    if (material.isScheduled)
                      Icon(Icons.schedule_rounded, size: 16, color: AppColors.highlightOrange),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  material.title,
                  style: AppTextStyles.titleMedium(textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(_metaLine(), style: AppTextStyles.bodySmall(bodyColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine() {
    final parts = <String>[];
    switch (material.type) {
      case LearningMaterialType.video:
      case LearningMaterialType.audio:
        if (material.durationSeconds != null) parts.add(FormatUtils.duration(material.durationSeconds!));
      case LearningMaterialType.pdf:
      case LearningMaterialType.document:
      case LearningMaterialType.presentation:
        if (material.pageCount != null) parts.add(FormatUtils.pageCount(material.pageCount!));
      default:
        break;
    }
    if (material.fileSizeBytes > 0) parts.add(FormatUtils.fileSize(material.fileSizeBytes));
    parts.add(FormatUtils.relative(material.createdAt));
    return parts.join(' • ');
  }
}

class _Preview extends StatelessWidget {
  final LearningMaterialModel material;
  const _Preview({required this.material});

  @override
  Widget build(BuildContext context) {
    final type = material.type;
    if (material.thumbnailUrl != null && material.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        material.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(type),
      );
    }
    return _fallback(type);
  }

  Widget _fallback(LearningMaterialType type) {
    return Container(
      color: type.color.withOpacity(0.10),
      alignment: Alignment.center,
      child: Icon(type.icon, size: 40, color: type.color),
    );
  }
}
