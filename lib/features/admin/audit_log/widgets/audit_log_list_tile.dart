import 'package:flutter/material.dart';
import '../../../../core/enums/audit_action_type.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../models/audit_log_model.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';

class AuditLogListTile extends StatelessWidget {
  final AuditLogModel log;
  final VoidCallback onTap;

  const AuditLogListTile({super.key, required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final action = log.actionType;

    return CustomCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: action.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(action.icon, color: action.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.summary.isEmpty ? action.label : log.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium(textColor),
                      ),
                    ),
                    _ModuleChip(module: log.module),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AppAvatar(name: log.userName, radius: 9),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        log.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall(bodyColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MetaTag(icon: Icons.schedule_rounded, label: FormatUtils.relative(log.createdAt)),
                    if (log.platform != null) _MetaTag(icon: Icons.devices_rounded, label: log.platform!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleChip extends StatelessWidget {
  final String module;
  const _ModuleChip({required this.module});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bodyColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(AuditModules.label(module), style: AppTextStyles.caption(bodyColor)),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: bodyColor),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption(bodyColor)),
      ],
    );
  }
}
