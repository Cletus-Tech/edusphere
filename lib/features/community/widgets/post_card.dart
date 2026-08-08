import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../models/community_models.dart';
import '../../../models/user_model.dart';
import '../../../repositories/community_repository.dart';
import '../../../repositories/moderation_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_animations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_theme.dart';

/// One post in the feed or at the top of the post-detail screen.
/// [onOpen] is null on the detail screen itself (tapping the card there
/// would just re-open the same post).
class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onOpen;
  final bool showCommentCount;

  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.showCommentCount = true,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete post?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final result = await PostRepository().delete(post.postId);
    if (!context.mounted) return;
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not delete post.');
    } else {
      AppSnackbar.success(context, 'Post deleted.');
    }
  }

  Future<void> _report(BuildContext context, String uid) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report post'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Why are you reporting this post?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    await ReportRepository().file(
      reportedBy: uid,
      targetId: post.postId,
      targetType: 'post',
      reason: reason,
    );
    if (context.mounted) AppSnackbar.success(context, 'Report submitted. Our moderators will review it.');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final uid = AuthService().currentUser?.uid;
    final isAuthor = uid != null && uid == post.authorId;

    return CustomCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StreamBuilder<UserModel?>(
                  stream: UserRepository().watchUser(post.authorId),
                  builder: (context, snapshot) {
                    final author = snapshot.data;
                    return AppAvatar(photoUrl: author?.photoUrl, name: author?.fullName, radius: 18);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<UserModel?>(
                        stream: UserRepository().watchUser(post.authorId),
                        builder: (context, snapshot) => Text(
                          snapshot.data?.fullName ?? 'Student',
                          style: AppTextStyles.titleMedium(textColor),
                        ),
                      ),
                      Text(FormatUtils.relative(post.createdAt), style: AppTextStyles.bodySmall(bodyColor)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: bodyColor),
                  onSelected: (value) {
                    if (value == 'delete') _confirmDelete(context);
                    if (value == 'report' && uid != null) _report(context, uid);
                  },
                  itemBuilder: (context) => [
                    if (isAuthor)
                      const PopupMenuItem(value: 'delete', child: Text('Delete'))
                    else
                      const PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                ),
              ],
            ),
            if (post.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(post.text, style: AppTextStyles.bodyMedium(textColor)),
            ],
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(post.imageUrls.first, fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _LikeButton(post: post),
                const SizedBox(width: 20),
                if (showCommentCount) ...[
                  Icon(Icons.mode_comment_outlined, size: 20, color: bodyColor),
                  const SizedBox(width: 6),
                  StreamBuilder<int>(
                    stream: CommentRepository().watchCountByPost(post.postId),
                    builder: (context, snapshot) => Text(
                      '${snapshot.data ?? 0}',
                      style: AppTextStyles.bodySmall(bodyColor),
                    ),
                  ),
                ],
                const Spacer(),
                if (uid != null) _BookmarkButton(uid: uid, postId: post.postId),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final PostModel post;
  const _LikeButton({required this.post});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (uid == null) {
      return Row(
        children: [
          Icon(Icons.favorite_border_rounded, size: 20, color: bodyColor),
          const SizedBox(width: 6),
          StreamBuilder<int>(
            stream: ReactionRepository().watchCountForTarget(targetId: post.postId, targetType: 'post'),
            builder: (context, snapshot) =>
                Text('${snapshot.data ?? 0}', style: AppTextStyles.bodySmall(bodyColor)),
          ),
        ],
      );
    }

    return StreamBuilder<ReactionModel?>(
      stream: ReactionRepository().watchUserReaction(uid: uid, targetId: post.postId),
      builder: (context, reactionSnapshot) {
        final liked = reactionSnapshot.data != null;
        return InkWell(
          onTap: () => ReactionRepository().toggleLike(uid: uid, targetId: post.postId, targetType: 'post'),
          child: Row(
            children: [
              // Stage B6 — a short scale "pop" on state change (not on
              // every rebuild: AnimatedScale only animates when its
              // own `scale` input actually changes, so a StreamBuilder
              // tick that doesn't flip `liked` doesn't retrigger it).
              // Uses AppAnimations.fast — the exact constant B1
              // reserved for "button press, chip select, toggle" —
              // rather than a new magic duration.
              AnimatedScale(
                scale: liked ? 1.15 : 1.0,
                duration: AppAnimations.fast,
                curve: AppAnimations.emphasized,
                child: Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: liked ? AppColors.error : bodyColor,
                ),
              ),
              const SizedBox(width: 6),
              StreamBuilder<int>(
                stream: ReactionRepository().watchCountForTarget(targetId: post.postId, targetType: 'post'),
                builder: (context, snapshot) =>
                    Text('${snapshot.data ?? 0}', style: AppTextStyles.bodySmall(bodyColor)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final String uid;
  final String postId;
  const _BookmarkButton({required this.uid, required this.postId});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return StreamBuilder<bool>(
      stream: BookmarkRepository().watchIsBookmarked(uid: uid, targetId: postId),
      builder: (context, snapshot) {
        final bookmarked = snapshot.data ?? false;
        return InkWell(
          onTap: () => BookmarkRepository().toggle(uid: uid, targetId: postId, targetType: 'post'),
          child: AnimatedScale(
            scale: bookmarked ? 1.15 : 1.0,
            duration: AppAnimations.fast,
            curve: AppAnimations.emphasized,
            child: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 20,
              color: bookmarked ? AppColors.accentPurple : bodyColor,
            ),
          ),
        );
      },
    );
  }
}
