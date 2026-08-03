import 'package:flutter/material.dart';
import '../../models/community_models.dart';
import '../../repositories/community_repository.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'widgets/post_card.dart';

/// The Community tab. Stage 2 replaces the "coming soon" placeholder
/// with a real feed backed by `posts/{id}` — [PostRepository.watchFeed]
/// (already excludes flagged posts per its own query), a FAB to compose,
/// and [PostCard] handling live like/comment/bookmark state per post.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community'), centerTitle: false),
      body: StreamBuilder<List<PostModel>>(
        stream: PostRepository().watchFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load the feed: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const EmptyView(
              message: 'No posts yet. Be the first to share something with your classmates.',
              icon: Icons.groups_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final post = posts[i];
              return PostCard(
                post: post,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondaryIndigo,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Post'),
        onPressed: () async {
          final published = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          if (published == true && context.mounted) {
            AppSnackbar.success(context, 'Post published successfully.');
          }
        },
      ),
    );
  }
}
