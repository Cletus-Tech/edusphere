import '../core/constants/app_constants.dart';
import '../models/engagement_models.dart';
import 'base_repository.dart';

class NotificationRepository extends BaseRepository<NotificationModel> {
  NotificationRepository() : super(AppConstants.notificationsCollection);

  @override
  NotificationModel fromMap(Map<String, dynamic> map, String id) => NotificationModel.fromMap(map, id);

  Stream<List<NotificationModel>> watchByUser(String uid, {int limit = 50}) {
    return streamCollection(
      query: (q) => q.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true),
      limit: limit,
    );
  }
}

class BadgeRepository extends BaseRepository<BadgeModel> {
  BadgeRepository() : super(AppConstants.badgesCollection);

  @override
  BadgeModel fromMap(Map<String, dynamic> map, String id) => BadgeModel.fromMap(map, id);
}

class AchievementRepository extends BaseRepository<AchievementModel> {
  AchievementRepository() : super(AppConstants.achievementsCollection);

  @override
  AchievementModel fromMap(Map<String, dynamic> map, String id) => AchievementModel.fromMap(map, id);

  Stream<List<AchievementModel>> watchByUser(String uid) {
    return streamCollection(query: (q) => q.where('uid', isEqualTo: uid));
  }

  Future<void> award(String uid, String badgeId) async {
    await save(AchievementModel(
      achievementId: '${uid}_$badgeId',
      uid: uid,
      badgeId: badgeId,
      earnedAt: DateTime.now(),
    ));
  }
}

class LeaderboardRepository extends BaseRepository<LeaderboardEntryModel> {
  LeaderboardRepository() : super(AppConstants.leaderboardCollection);

  @override
  LeaderboardEntryModel fromMap(Map<String, dynamic> map, String id) =>
      LeaderboardEntryModel.fromMap(map, id);

  Stream<List<LeaderboardEntryModel>> watchTop({String? institutionId, int limit = 50}) {
    return streamCollection(
      query: (q) {
        var ref = q.orderBy('points', descending: true);
        if (institutionId != null) {
          ref = ref.where('institutionId', isEqualTo: institutionId);
        }
        return ref;
      },
      limit: limit,
    );
  }
}
