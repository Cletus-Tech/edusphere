import '../core/constants/app_constants.dart';
import '../core/utils/result.dart';
import '../models/upload_task_model.dart';
import 'base_repository.dart';

class UploadHistoryRepository extends BaseRepository<UploadTaskModel> {
  UploadHistoryRepository() : super(AppConstants.uploadHistoryCollection);

  @override
  UploadTaskModel fromMap(Map<String, dynamic> map, String id) => UploadTaskModel.fromMap(map, id);

  /// A user's past uploads, most recent first — what the Upload Engine's
  /// "history" view renders.
  Stream<List<UploadTaskModel>> watchForUser(String uid, {int limit = 50}) {
    return streamCollection(
      query: (q) => q.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true),
      limit: limit,
    );
  }

  /// Looks up a prior upload by content hash, for duplicate-detection
  /// against files the user already uploaded in a past session (the
  /// Upload Engine itself catches duplicates queued in the *current*
  /// session in memory — this covers the cross-session case).
  Future<UploadTaskModel?> findByHash(String uid, String fileHash) async {
    final result = await getWhere(
      query: (q) => q
          .where('uid', isEqualTo: uid)
          .where('fileHash', isEqualTo: fileHash)
          .where('status', isEqualTo: 'success'),
      limit: 1,
    );
    if (result case Success(data: final list)) {
      return list.isEmpty ? null : list.first;
    }
    return null;
  }
}
