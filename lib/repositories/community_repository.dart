import '../core/constants/app_constants.dart';
import '../core/utils/result.dart';
import '../models/community_models.dart';
import 'base_repository.dart';

class CommunityRepository extends BaseRepository<CommunityModel> {
  CommunityRepository() : super(AppConstants.communitiesCollection);

  @override
  CommunityModel fromMap(Map<String, dynamic> map, String id) => CommunityModel.fromMap(map, id);
}

class PostRepository extends BaseRepository<PostModel> {
  PostRepository() : super(AppConstants.postsCollection);

  @override
  PostModel fromMap(Map<String, dynamic> map, String id) => PostModel.fromMap(map, id);

  Stream<List<PostModel>> watchFeed({String? communityId, int limit = 30}) {
    return streamCollection(
      query: (q) {
        var ref = q.where('isFlagged', isEqualTo: false).orderBy('createdAt', descending: true);
        if (communityId != null) ref = ref.where('communityId', isEqualTo: communityId);
        return ref;
      },
      limit: limit,
    );
  }

  Future<Result<String>> createPost(PostModel post) async {
    final id = post.id.isNotEmpty ? post.id : newId();
    final withId = PostModel(
      postId: id,
      authorId: post.authorId,
      communityId: post.communityId,
      text: post.text,
      imageUrls: post.imageUrls,
      createdAt: post.createdAt,
    );
    final result = await save(withId);
    return switch (result) {
      Success() => Result.success(id),
      Failure(message: final m) => Result.failure(m),
    };
  }
}

class CommentRepository extends BaseRepository<CommentModel> {
  CommentRepository() : super(AppConstants.commentsCollection);

  @override
  CommentModel fromMap(Map<String, dynamic> map, String id) => CommentModel.fromMap(map, id);

  Stream<List<CommentModel>> watchByPost(String postId) {
    return streamCollection(
      query: (q) => q.where('postId', isEqualTo: postId).orderBy('createdAt'),
    );
  }
}

class ReactionRepository extends BaseRepository<ReactionModel> {
  ReactionRepository() : super(AppConstants.reactionsCollection);

  @override
  ReactionModel fromMap(Map<String, dynamic> map, String id) => ReactionModel.fromMap(map, id);

  /// One reaction per user per target — doc id is deterministic so a
  /// second "react" call overwrites rather than duplicating.
  Future<Result<void>> react({
    required String uid,
    required String targetId,
    required String targetType,
    String type = 'like',
  }) {
    final id = '${targetId}_$uid';
    return save(ReactionModel(
      reactionId: id,
      targetId: targetId,
      targetType: targetType,
      uid: uid,
      type: type,
    ));
  }

  Future<Result<void>> unreact({required String uid, required String targetId}) {
    return delete('${targetId}_$uid');
  }
}

class BookmarkRepository extends BaseRepository<BookmarkModel> {
  BookmarkRepository() : super(AppConstants.bookmarksCollection);

  @override
  BookmarkModel fromMap(Map<String, dynamic> map, String id) => BookmarkModel.fromMap(map, id);

  Stream<List<BookmarkModel>> watchByUser(String uid) {
    return streamCollection(query: (q) => q.where('uid', isEqualTo: uid));
  }

  Future<Result<void>> toggle({
    required String uid,
    required String targetId,
    required String targetType,
  }) {
    final id = '${uid}_$targetId';
    return save(BookmarkModel(
      bookmarkId: id,
      uid: uid,
      targetId: targetId,
      targetType: targetType,
      createdAt: DateTime.now(),
    ));
  }
}
