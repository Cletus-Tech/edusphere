import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// `ai_history/{entryId}` — one AI Tutor exchange, kept for continuity
/// and future analytics on AI usage.
class AiHistoryModel extends Equatable implements FirestoreModel {
  final String entryId;
  final String uid;
  final String prompt;
  final String response;
  final String? courseId;
  final DateTime createdAt;

  const AiHistoryModel({
    required this.entryId,
    required this.uid,
    required this.prompt,
    required this.response,
    this.courseId,
    required this.createdAt,
  });

  factory AiHistoryModel.fromMap(Map<String, dynamic> map, String entryId) {
    return AiHistoryModel(
      entryId: entryId,
      uid: map['uid'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      response: map['response'] as String? ?? '',
      courseId: map['courseId'] as String?,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'prompt': prompt,
        'response': response,
        'courseId': courseId,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  @override
  String get id => entryId;

  @override
  List<Object?> get props => [entryId, uid, createdAt];
}

/// `reports/{reportId}` — a moderation report against a post, comment,
/// or user, routed to admins/moderators.
class ReportModel extends Equatable implements FirestoreModel {
  final String reportId;
  final String reportedBy;
  final String targetId;
  final String targetType; // 'post' | 'comment' | 'user'
  final String reason;
  final String status; // 'pending' | 'reviewed' | 'dismissed' | 'actioned'
  final DateTime createdAt;

  const ReportModel({
    required this.reportId,
    required this.reportedBy,
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String reportId) {
    return ReportModel(
      reportId: reportId,
      reportedBy: map['reportedBy'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      targetType: map['targetType'] as String? ?? 'post',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'reportedBy': reportedBy,
        'targetId': targetId,
        'targetType': targetType,
        'reason': reason,
        'status': status,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
      };

  @override
  String get id => reportId;

  @override
  List<Object?> get props => [reportId, targetId, status];
}

/// `analytics/{docId}` — pre-aggregated counters written by backend jobs
/// (Cloud Functions), never computed client-side. Doc id convention:
/// `${scope}_${yyyy-MM-dd}`, e.g. `daily_users_2026-07-31`.
class AnalyticsSnapshotModel extends Equatable implements FirestoreModel {
  final String docId;
  final String metric; // 'daily_users' | 'course_usage' | 'downloads' | ...
  final DateTime date;
  final Map<String, num> counters;

  const AnalyticsSnapshotModel({
    required this.docId,
    required this.metric,
    required this.date,
    this.counters = const {},
  });

  factory AnalyticsSnapshotModel.fromMap(Map<String, dynamic> map, String docId) {
    return AnalyticsSnapshotModel(
      docId: docId,
      metric: map['metric'] as String? ?? '',
      date: FirestoreConvert.dateTime(map['date']),
      counters: (map['counters'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v as num? ?? 0),
          ) ??
          const {},
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'metric': metric,
        'date': FirestoreConvert.toTimestamp(date),
        'counters': counters,
      };

  @override
  String get id => docId;

  @override
  List<Object?> get props => [docId, metric, date];
}
