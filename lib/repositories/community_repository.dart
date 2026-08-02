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

  /// Live comment count for a post. Derived from the `comments`
  /// collection rather than a denormalized counter on the `posts` doc,
  /// because `firestore.rules` only lets a post's *author* (or a
  /// moderator) update that document — a commenter who isn't the
  /// author could never legally bump a `posts/{id}.commentCount` field,
  /// so that field is display-only/legacy and this is the real count.
  Stream<int> watchCountByPost(String postId) => watchByPost(postId).map((list) => list.length);

  Future<Result<String>> createComment({
    required String postId,
    required String authorId,
    required String text,
    String? parentCommentId,
  }) async {
    final id = newId();
    final result = await save(CommentModel(
      commentId: id,
      postId: postId,
      authorId: authorId,
      parentCommentId: parentCommentId,
      text: text,
      createdAt: DateTime.now(),
    ));
    return switch (result) {
      Success() => Result.success(id),
      Failure(message: final m) => Result.failure(m),
    };
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

  /// This user's reaction to [targetId], if any — lets the UI show a
  /// filled/outline heart without a separate query per render.
  Stream<ReactionModel?> watchUserReaction({required String uid, required String targetId}) {
    return streamById('${targetId}_$uid');
  }

  /// Live like count for a post/comment. Derived from the `reactions`
  /// collection itself rather than a denormalized counter on the target
  /// document, for the same `firestore.rules` reason documented on
  /// [CommentRepository.watchCountByPost] — a like from anyone other
  /// than the post's author can never legally write to that post's own
  /// document.
  Stream<int> watchCountForTarget({required String targetId, required String targetType}) {
    return streamCollection(
      query: (q) => q.where('targetId', isEqualTo: targetId).where('targetType', isEqualTo: targetType),
    ).map((list) => list.length);
  }

  /// Toggles the current user's like on/off in one call so call sites
  /// don't have to re-check [watchUserReaction] themselves first.
  Future<Result<void>> toggleLike({
    required String uid,
    required String targetId,
    required String targetType,
  }) async {
    final existing = await getById('${targetId}_$uid');
    final alreadyLiked = switch (existing) {
      Success(data: final data) => data != null,
      Failure() => false,
    };
    return alreadyLiked
        ? unreact(uid: uid, targetId: targetId)
        : react(uid: uid, targetId: targetId, targetType: targetType);
  }
}

class BookmarkRepository extends BaseRepository<BookmarkModel> {
  BookmarkRepository() : super(AppConstants.bookmarksCollection);

  @override
  BookmarkModel fromMap(Map<String, dynamic> map, String id) => BookmarkModel.fromMap(map, id);

  Stream<List<BookmarkModel>> watchByUser(String uid) {
    return streamCollection(query: (q) => q.where('uid', isEqualTo: uid));
  }

  /// Whether [uid] has bookmarked [targetId] — for a per-item bookmark
  /// icon without loading the user's whole bookmark list.
  Stream<bool> watchIsBookmarked({required String uid, required String targetId}) {
    return streamById('${uid}_$targetId').map((b) => b != null);
  }

  /// Actually toggles: the previous version of this method only ever
  /// called [save], so a second tap could never remove the bookmark —
  /// fixed here to check first, matching what "toggle" already implied.
  Future<Result<void>> toggle({
    required String uid,
    required String targetId,
    required String targetType,
  }) async {
    final id = '${uid}_$targetId';
    final existing = await getById(id);
    final alreadyBookmarked = switch (existing) {
      Success(data: final data) => data != null,
      Failure() => false,
    };
    if (alreadyBookmarked) return delete(id);
    return save(BookmarkModel(
      bookmarkId: id,
      uid: uid,
      targetId: targetId,
      targetType: targetType,
      createdAt: DateTime.now(),
    ));
  }
}
