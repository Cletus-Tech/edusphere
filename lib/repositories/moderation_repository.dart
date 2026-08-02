import '../core/constants/app_constants.dart';
import '../models/system_models.dart';
import 'base_repository.dart';

class ReportRepository extends BaseRepository<ReportModel> {
  ReportRepository() : super(AppConstants.reportsCollection);

  @override
  ReportModel fromMap(Map<String, dynamic> map, String id) => ReportModel.fromMap(map, id);

  Stream<List<ReportModel>> watchPending() {
    return streamCollection(
      query: (q) => q.where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true),
    );
  }

  Future<void> file({
    required String reportedBy,
    required String targetId,
    required String targetType,
    required String reason,
  }) async {
    await save(ReportModel(
      reportId: newId(),
      reportedBy: reportedBy,
      targetId: targetId,
      targetType: targetType,
      reason: reason,
      createdAt: DateTime.now(),
    ));
  }
}

/// Read-only from the app's perspective — analytics snapshots are
/// written by backend jobs (Cloud Functions), not client code.
class AnalyticsRepository extends BaseRepository<AnalyticsSnapshotModel> {
  AnalyticsRepository() : super(AppConstants.analyticsCollection);

  @override
  AnalyticsSnapshotModel fromMap(Map<String, dynamic> map, String id) =>
      AnalyticsSnapshotModel.fromMap(map, id);

  Stream<List<AnalyticsSnapshotModel>> watchByMetric(String metric, {int limit = 30}) {
    return streamCollection(
      query: (q) => q.where('metric', isEqualTo: metric).orderBy('date', descending: true),
      limit: limit,
    );
  }
}
