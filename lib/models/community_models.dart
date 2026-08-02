import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// `communities/{communityId}` — a community space (e.g. a department's
/// or institution's community). `posts` reference this by `communityId`.
class CommunityModel extends Equatable implements FirestoreModel {
  final String communityId;
  final String name;
  final String? institutionId;
  final String? description;
  final String? iconUrl;
  final int memberCount;
  final bool isActive;

  const CommunityModel({
    required this.communityId,
    required this.name,
    this.institutionId,
    this.description,
    this.iconUrl,
    this.memberCount = 0,
    this.isActive = true,
  });

  factory CommunityModel.fromMap(Map<String, dynamic> map, String communityId) {
    return CommunityModel(
      communityId: communityId,
      name: map['name'] as String? ?? '',
      institutionId: map['institutionId'] as String?,
      description: map['description'] as String?,
      iconUrl: map['iconUrl'] as String?,
      memberCount: map['memberCount'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'institutionId': institutionId,
        'description': description,
        'iconUrl': iconUrl,
        'memberCount': memberCount,
        'isActive': isActive,
      };

  @override
  String get id => communityId;

  @override
  List<Object?> get props => [communityId, name, isActive];
}

/// `posts/{postId}`.
class PostModel extends Equatable implements FirestoreModel {
  final String postId;
  final String authorId;
  final String? communityId;
  final String text;
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final bool isFlagged;
  final DateTime createdAt;

  const PostModel({
    required this.postId,
    required this.authorId,
    this.communityId,
    required this.text,
    this.imageUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isFlagged = false,
    required this.createdAt,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String postId) {
    return PostModel(
      postId: postId,
      authorId: map['authorId'] as String? ?? '',
      communityId: map['communityId'] as String?,
      text: map['text'] as String? ?? '',
      imageUrls: FirestoreConvert.stringList(map['imageUrls']),
      likeCount: map['likeCount'] as int? ?? 0,
      commentCount: map['commentCount'] as int? ?? 0,
      isFlagged: map['isFlagged'] as bool? ?? false,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'communityId': communityId,
        'text': text,
        'imageUrls': imageUrls,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'isFlagged': isFlagged,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  @override
  String get id => postId;

  @override
  List<Object?> get props => [postId, authorId, text, createdAt];
}

/// `comments/{commentId}` — threaded via `parentCommentId`.
class CommentModel extends Equatable implements FirestoreModel {
  final String commentId;
  final String postId;
  final String authorId;
  final String? parentCommentId;
  final String text;
  final int likeCount;
  final DateTime createdAt;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.authorId,
    this.parentCommentId,
    required this.text,
    this.likeCount = 0,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String commentId) {
    return CommentModel(
      commentId: commentId,
      postId: map['postId'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      parentCommentId: map['parentCommentId'] as String?,
      text: map['text'] as String? ?? '',
      likeCount: map['likeCount'] as int? ?? 0,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'postId': postId,
        'authorId': authorId,
        'parentCommentId': parentCommentId,
        'text': text,
        'likeCount': likeCount,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  @override
  String get id => commentId;

  @override
  List<Object?> get props => [commentId, postId, authorId, text];
}

/// `reactions/{reactionId}` — one user's reaction to a post or comment.
/// Doc id is conventionally `${targetId}_${uid}` so a user can only react
/// once per target without an extra query (repository enforces this).
class ReactionModel extends Equatable implements FirestoreModel {
  final String reactionId;
  final String targetId;
  final String targetType; // 'post' | 'comment'
  final String uid;
  final String type; // 'like', 'love', etc. — kept as string for extensibility

  const ReactionModel({
    required this.reactionId,
    required this.targetId,
    required this.targetType,
    required this.uid,
    this.type = 'like',
  });

  factory ReactionModel.fromMap(Map<String, dynamic> map, String reactionId) {
    return ReactionModel(
      reactionId: reactionId,
      targetId: map['targetId'] as String? ?? '',
      targetType: map['targetType'] as String? ?? 'post',
      uid: map['uid'] as String? ?? '',
      type: map['type'] as String? ?? 'like',
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'targetId': targetId,
        'targetType': targetType,
        'uid': uid,
        'type': type,
      };

  @override
  String get id => reactionId;

  @override
  List<Object?> get props => [reactionId, targetId, uid, type];
}

/// `bookmarks/{bookmarkId}` — doc id conventionally `${uid}_${targetId}`.
class BookmarkModel extends Equatable implements FirestoreModel {
  final String bookmarkId;
  final String uid;
  final String targetId;
  final String targetType; // 'post' | 'learning_content' | 'exam'
  final DateTime createdAt;

  const BookmarkModel({
    required this.bookmarkId,
    required this.uid,
    required this.targetId,
    required this.targetType,
    required this.createdAt,
  });

  factory BookmarkModel.fromMap(Map<String, dynamic> map, String bookmarkId) {
    return BookmarkModel(
      bookmarkId: bookmarkId,
      uid: map['uid'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      targetType: map['targetType'] as String? ?? 'post',
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'targetId': targetId,
        'targetType': targetType,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  @override
  String get id => bookmarkId;

  @override
  List<Object?> get props => [bookmarkId, uid, targetId, targetType];
}
