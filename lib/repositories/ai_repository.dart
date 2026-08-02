import '../core/constants/app_constants.dart';
import '../models/system_models.dart';
import 'base_repository.dart';

class AiHistoryRepository extends BaseRepository<AiHistoryModel> {
  AiHistoryRepository() : super(AppConstants.aiHistoryCollection);

  @override
  AiHistoryModel fromMap(Map<String, dynamic> map, String id) => AiHistoryModel.fromMap(map, id);

  Stream<List<AiHistoryModel>> watchByUser(String uid, {int limit = 50}) {
    return streamCollection(
      query: (q) => q.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true),
      limit: limit,
    );
  }

  Future<void> logExchange({
    required String uid,
    required String prompt,
    required String response,
    String? courseId,
  }) async {
    await save(AiHistoryModel(
      entryId: newId(),
      uid: uid,
      prompt: prompt,
      response: response,
      courseId: courseId,
      createdAt: DateTime.now(),
    ));
  }
}
