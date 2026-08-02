import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// `notifications/{notificationId}`.
class NotificationModel extends Equatable implements FirestoreModel {
  final String notificationId;
  final String uid;
  final String title;
  final String body;
  final String type; // 'system' | 'community' | 'achievement' | 'exam' ...
  final String? deepLink;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.uid,
    required this.title,
    required this.body,
    this.type = 'system',
    this.deepLink,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String notificationId) {
    return NotificationModel(
      notificationId: notificationId,
      uid: map['uid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'system',
      deepLink: map['deepLink'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        'deepLink': deepLink,
        'isRead': isRead,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  @override
  String get id => notificationId;

  @override
  List<Object?> get props => [notificationId, uid, title, isRead];
}

/// `badges/{badgeId}` — a definable badge (icon + criteria description).
class BadgeModel extends Equatable implements FirestoreModel {
  final String badgeId;
  final String name;
  final String description;
  final String iconUrl;

  const BadgeModel({
    required this.badgeId,
    required this.name,
    this.description = '',
    this.iconUrl = '',
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map, String badgeId) {
    return BadgeModel(
      badgeId: badgeId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconUrl: map['iconUrl'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'iconUrl': iconUrl,
      };

  @override
  String get id => badgeId;

  @override
  List<Object?> get props => [badgeId, name];
}

/// `achievements/{achievementId}` — doc id conventionally `${uid}_${badgeId}`,
/// recording that a user earned a badge.
class AchievementModel extends Equatable implements FirestoreModel {
  final String achievementId;
  final String uid;
  final String badgeId;
  final DateTime earnedAt;

  const AchievementModel({
    required this.achievementId,
    required this.uid,
    required this.badgeId,
    required this.earnedAt,
  });

  factory AchievementModel.fromMap(Map<String, dynamic> map, String achievementId) {
    return AchievementModel(
      achievementId: achievementId,
      uid: map['uid'] as String? ?? '',
      badgeId: map['badgeId'] as String? ?? '',
      earnedAt: FirestoreConvert.dateTime(map['earnedAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'badgeId': badgeId,
        'earnedAt': FirestoreConvert.toTimestamp(earnedAt),
      };

  @override
  String get id => achievementId;

  @override
  List<Object?> get props => [achievementId, uid, badgeId];
}

/// `leaderboard/{uid}` — one aggregated ranking doc per user, updated by
/// backend logic rather than recomputed client-side.
class LeaderboardEntryModel extends Equatable implements FirestoreModel {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int points;
  final String? institutionId;
  final DateTime updatedAt;

  const LeaderboardEntryModel({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.points = 0,
    this.institutionId,
    required this.updatedAt,
  });

  factory LeaderboardEntryModel.fromMap(Map<String, dynamic> map, String uid) {
    return LeaderboardEntryModel(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      points: map['points'] as int? ?? 0,
      institutionId: map['institutionId'] as String?,
      updatedAt: FirestoreConvert.dateTime(map['updatedAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'points': points,
        'institutionId': institutionId,
        'updatedAt': FirestoreConvert.toTimestamp(updatedAt),
      };

  @override
  String get id => uid;

  @override
  List<Object?> get props => [uid, points];
}
