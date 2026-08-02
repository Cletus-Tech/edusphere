import 'package:equatable/equatable.dart';
import '../core/enums/audit_action_type.dart';
import 'firestore_model.dart';

/// One entry in the `audit_logs` collection (Stage 3.6.1 — Admin
/// Productivity Pack & Data Integrity).
///
/// Written once and never mutated afterwards — `firestore.rules` denies
/// `update`/`delete` on this collection outright, since an editable
/// "audit trail" isn't an audit trail. See [AuditLogService] for the
/// only supported way to create one.
class AuditLogModel extends Equatable implements FirestoreModel {
  final String logId;

  // Who
  final String userId;
  final String userName;
  final String? userRole;

  // What
  final AuditActionType actionType;
  final String module;

  // On what
  final String targetCollection;
  final String targetId;
  final String? targetTitle;

  // Detail
  final String summary;
  final Map<String, dynamic>? previousValues;
  final Map<String, dynamic>? newValues;

  // Context
  final String? platform;
  final String? ipAddress;
  final DateTime createdAt;

  // Stage 3.6.2 — Operation Tracking. All nullable/defaulted so entries
  // written before this stage (with none of these fields) still decode
  // cleanly — see [fromMap].
  final String? operationId;
  final String? sessionId;
  final String? appVersion;
  final String? deviceType;
  final String? deviceModel;
  final int? durationMs;

  const AuditLogModel({
    required this.logId,
    required this.userId,
    required this.userName,
    required this.actionType,
    required this.module,
    required this.createdAt,
    this.userRole,
    this.targetCollection = '',
    this.targetId = '',
    this.targetTitle,
    this.summary = '',
    this.previousValues,
    this.newValues,
    this.platform,
    this.ipAddress,
    this.operationId,
    this.sessionId,
    this.appVersion,
    this.deviceType,
    this.deviceModel,
    this.durationMs,
  });

  factory AuditLogModel.fromMap(Map<String, dynamic> map, String logId) {
    return AuditLogModel(
      logId: logId,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Unknown user',
      userRole: map['userRole'] as String?,
      actionType: AuditActionType.fromId(map['actionType'] as String? ?? 'other'),
      module: map['module'] as String? ?? '',
      targetCollection: map['targetCollection'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      targetTitle: map['targetTitle'] as String?,
      summary: map['summary'] as String? ?? '',
      previousValues: map['previousValues'] == null ? null : FirestoreConvert.map(map['previousValues']),
      newValues: map['newValues'] == null ? null : FirestoreConvert.map(map['newValues']),
      platform: map['platform'] as String?,
      ipAddress: map['ipAddress'] as String?,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
      operationId: map['operationId'] as String?,
      sessionId: map['sessionId'] as String?,
      appVersion: map['appVersion'] as String?,
      deviceType: map['deviceType'] as String?,
      deviceModel: map['deviceModel'] as String?,
      durationMs: map['durationMs'] as int?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'actionType': actionType.id,
        'module': module,
        'targetCollection': targetCollection,
        'targetId': targetId,
        'targetTitle': targetTitle,
        'summary': summary,
        'previousValues': previousValues,
        'newValues': newValues,
        'platform': platform,
        'ipAddress': ipAddress,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
        'operationId': operationId,
        'sessionId': sessionId,
        'appVersion': appVersion,
        'deviceType': deviceType,
        'deviceModel': deviceModel,
        'durationMs': durationMs,
      };

  @override
  String get id => logId;

  @override
  List<Object?> get props => [logId, userId, actionType, targetId, createdAt];
}
