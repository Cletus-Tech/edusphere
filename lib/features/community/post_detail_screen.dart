import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';
import '../../models/community_models.dart';
import '../../models/user_model.dart';
import '../../repositories/community_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      AppSnackbar.error(context, 'You need to be signed in to comment.');
      return;
    }
    if (text.isEmpty) return;

    setState(() => _sending = true);
    final result = await CommentRepository().createComment(
      postId: widget.post.postId,
      authorId: uid,
      text: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not post your comment.');
      return;
    }
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PostCard(post: widget.post, showCommentCount: false),
                const SizedBox(height: 8),
                const Divider(),
                StreamBuilder<List<CommentModel>>(
                  stream: CommentRepository().watchByPost(widget.post.postId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: LoadingView(),
                      );
                    }
                    final comments = snapshot.data!;
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: EmptyView(message: 'No comments yet. Be the first to reply.', icon: Icons.mode_comment_outlined),
                      );
                    }
                    return Column(
                      children: comments.map((c) => _CommentTile(comment: c)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : IconButton(
                          onPressed: _sendComment,
                          icon: const Icon(Icons.send_rounded),
                          color: AppColors.primaryBlue,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<UserModel?>(
            stream: UserRepository().watchUser(comment.authorId),
            builder: (context, snapshot) => AppAvatar(
              photoUrl: snapshot.data?.photoUrl,
              name: snapshot.data?.fullName,
              radius: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<UserModel?>(
                  stream: UserRepository().watchUser(comment.authorId),
                  builder: (context, snapshot) => Text(
                    snapshot.data?.fullName ?? 'Student',
                    style: AppTextStyles.titleMedium(textColor),
                  ),
                ),
                const SizedBox(height: 2),
                Text(comment.text, style: AppTextStyles.bodyMedium(textColor)),
                const SizedBox(height: 2),
                Text(FormatUtils.relative(comment.createdAt), style: AppTextStyles.bodySmall(bodyColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
