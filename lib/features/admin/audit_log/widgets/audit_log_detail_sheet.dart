import 'package:flutter/material.dart';
import '../../../../core/enums/audit_action_type.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../models/audit_log_model.dart';
import '../../../../shared/components/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';

void showAuditLogDetailSheet(BuildContext context, AuditLogModel log) {
  AppBottomSheet.show(context, child: _AuditLogDetailBody(log: log));
}

class _AuditLogDetailBody extends StatelessWidget {
  final AuditLogModel log;
  const _AuditLogDetailBody({required this.log});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final action = log.actionType;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: action.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(action.icon, color: action.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.label, style: AppTextStyles.titleMedium(textColor)),
                      Text(AuditModules.label(log.module), style: AppTextStyles.bodySmall(bodyColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (log.summary.isNotEmpty) ...[
              Text(log.summary, style: AppTextStyles.bodyMedium(textColor)),
              const SizedBox(height: 16),
            ],
            _DetailRow(label: 'Performed by', child: Row(
              children: [
                AppAvatar(name: log.userName, radius: 12),
                const SizedBox(width: 8),
                Flexible(child: Text(log.userName, style: AppTextStyles.bodyMedium(textColor))),
                if (log.userRole != null) ...[
                  const SizedBox(width: 6),
                  Text('· ${log.userRole}', style: AppTextStyles.bodySmall(bodyColor)),
                ],
              ],
            )),
            _DetailRow(label: 'When', child: Text(FormatUtils.dateTime(log.createdAt), style: AppTextStyles.bodyMedium(textColor))),
            if (log.targetTitle != null && log.targetTitle!.isNotEmpty)
              _DetailRow(label: 'Target', child: Text(log.targetTitle!, style: AppTextStyles.bodyMedium(textColor))),
            if (log.targetId.isNotEmpty)
              _DetailRow(
                label: 'Target ID',
                child: SelectableText(log.targetId, style: AppTextStyles.bodySmall(bodyColor)),
              ),
            if (log.platform != null) _DetailRow(label: 'Platform', child: Text(log.platform!, style: AppTextStyles.bodyMedium(textColor))),
            if (log.ipAddress != null) _DetailRow(label: 'IP address', child: Text(log.ipAddress!, style: AppTextStyles.bodyMedium(textColor))),
            if (log.previousValues != null && log.previousValues!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Previous values', style: AppTextStyles.bodySmall(bodyColor).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _ValuesTable(values: log.previousValues!),
            ],
            if (log.newValues != null && log.newValues!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('New values', style: AppTextStyles.bodySmall(bodyColor).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _ValuesTable(values: log.newValues!),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: AppTextStyles.bodySmall(bodyColor)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ValuesTable extends StatelessWidget {
  final Map<String, dynamic> values;
  const _ValuesTable({required this.values});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bodyColor.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: values.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySmall(bodyColor),
                    children: [
                      TextSpan(text: '${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: '${e.value}'),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
