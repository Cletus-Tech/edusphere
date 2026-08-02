import '../core/constants/app_constants.dart';
import '../core/utils/result.dart';
import '../models/system_models.dart';
import '../services/audit/audit_log_service.dart';
import 'base_repository.dart';
import 'community_repository.dart';

class ReportRepository extends BaseRepository<ReportModel> {
  ReportRepository() : super(AppConstants.reportsCollection);

  @override
  ReportModel fromMap(Map<String, dynamic> map, String id) => ReportModel.fromMap(map, id);

  Stream<List<ReportModel>> watchPending() {
    return streamCollection(
      query: (q) => q.where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true),
    );
  }

  Future<Result<void>> updateStatus(ReportModel report, String status) {
    return save(report.copyWith(status: status));
  }

  Future<Result<void>> dismiss(ReportModel report) => updateStatus(report, 'dismissed');

  /// Deletes the reported post/comment (moderators may delete either,
  /// per `firestore.rules`' `isModerator()` clause) then marks the
  /// report actioned. Logs through [AuditLogService] either way the
  /// content resolves.
  Future<Result<void>> removeContentAndResolve(ReportModel report) async {
    final deleteResult = report.targetType == 'comment'
        ? await CommentRepository().delete(report.targetId)
        : await PostRepository().delete(report.targetId);
    if (deleteResult.isFailure) return deleteResult;

    if (report.targetType == 'comment') {
      AuditLogService.instance.logCommentDeleted(commentId: report.targetId);
    } else {
      AuditLogService.instance.logPostDeleted(postId: report.targetId);
    }
    return updateStatus(report, 'actioned');
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
