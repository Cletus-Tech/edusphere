import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/result.dart';
import '../../../models/community_models.dart';
import '../../../models/system_models.dart';
import '../../../models/user_model.dart';
import '../../../repositories/community_repository.dart';
import '../../../repositories/moderation_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Admin → Moderation & Reports. Real queue over
/// [ReportRepository.watchPending], replacing the Stage 1
/// `FeaturePlaceholder`. Every report was filed by a real user via the
/// Community tab's "Report" action (Stage 2 item 2), so this screen has
/// live data to work with from day one.
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderation & Reports')),
      body: StreamBuilder<List<ReportModel>>(
        stream: ReportRepository().watchPending(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load reports: ${snapshot.error}');
          }
          if (!snapshot.hasData) return const LoadingView();

          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const EmptyView(
              message: 'No pending reports. Nice and quiet.',
              icon: Icons.verified_user_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ReportCard(report: reports[i]),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  const _ReportCard({required this.report});

  Future<void> _dismiss(BuildContext context) async {
    final result = await ReportRepository().dismiss(report);
    if (!context.mounted) return;
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not dismiss the report.');
    } else {
      AppSnackbar.success(context, 'Report dismissed.');
    }
  }

  Future<void> _removeContent(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Remove this ${report.targetType}?',
      message: 'This deletes the reported content and marks the report as actioned. This cannot be undone.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ReportRepository().removeContentAndResolve(report);
    if (!context.mounted) return;
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not remove the content — it may already be gone.');
    } else {
      AppSnackbar.success(context, 'Content removed and report actioned.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.highlightOrange, size: 18),
              const SizedBox(width: 6),
              Text(
                report.targetType == 'comment' ? 'Reported comment' : 'Reported post',
                style: AppTextStyles.titleMedium(textColor),
              ),
              const Spacer(),
              Text(FormatUtils.relative(report.createdAt), style: AppTextStyles.bodySmall(bodyColor)),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<UserModel?>(
            stream: UserRepository().watchUser(report.reportedBy),
            builder: (context, snapshot) => Text(
              'Reported by ${snapshot.data?.fullName ?? 'a user'}',
              style: AppTextStyles.bodySmall(bodyColor),
            ),
          ),
          const SizedBox(height: 8),
          Text('"${report.reason}"', style: AppTextStyles.bodyMedium(textColor)),
          const SizedBox(height: 10),
          _ContentPreview(report: report),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => _dismiss(context), child: const Text('Dismiss')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: () => _removeContent(context),
                  child: const Text('Remove content'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Best-effort preview of the reported content itself, so a moderator
/// doesn't have to act blind. Content may already be gone (deleted by
/// its author, or by an earlier moderation pass) — that's shown plainly
/// rather than as an error.
class _ContentPreview extends StatelessWidget {
  final ReportModel report;
  const _ContentPreview({required this.report});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bodyColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: report.targetType == 'comment'
          ? FutureBuilder<Result<CommentModel?>>(
              future: CommentRepository().getById(report.targetId),
              builder: (context, snapshot) {
                final comment = snapshot.data?.dataOrNull;
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
                }
                return Text(
                  comment?.text ?? 'This comment has already been removed.',
                  style: AppTextStyles.bodySmall(bodyColor),
                );
              },
            )
          : FutureBuilder<Result<PostModel?>>(
              future: PostRepository().getById(report.targetId),
              builder: (context, snapshot) {
                final post = snapshot.data?.dataOrNull;
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (post == null) {
                  return Text('This post has already been removed.', style: AppTextStyles.bodySmall(bodyColor));
                }
                return Text(
                  post.text.isEmpty ? '(image post, no caption)' : post.text,
                  style: AppTextStyles.bodySmall(bodyColor),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
    );
  }
}
