import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/enums/audit_action_type.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/result.dart';
import '../models/audit_log_model.dart';
import '../models/firestore_model.dart';
import 'base_repository.dart';

/// One page of a cursor-paginated audit log query — the log entries
/// themselves plus what [AuditLogRepository.fetchPage] needs to fetch
/// the next page.
class AuditLogPage {
  final List<AuditLogModel> logs;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const AuditLogPage({required this.logs, required this.lastDocument, required this.hasMore});

  static const empty = AuditLogPage(logs: [], lastDocument: null, hasMore: false);
}

/// A distinct user who has an audit entry, for the filter sheet's
/// "User" picker.
class AuditActor {
  final String uid;
  final String name;
  const AuditActor({required this.uid, required this.name});
}

/// Repository for `audit_logs/{logId}` (Stage 3.6.1 — Admin Productivity
/// Pack & Data Integrity). Every admin-facing module writes here through
/// `AuditLogService`, never directly, so logging stays consistent app-wide
/// — this repository is the low-level Firestore boundary underneath it.
///
/// Deliberately does not expose `update`/`delete`: `BaseRepository`
/// technically has both, but nothing in this repository's own API calls
/// them, and `firestore.rules` denies them server-side too. An audit
/// trail that can be edited or deleted after the fact isn't one.
class AuditLogRepository extends BaseRepository<AuditLogModel> {
  AuditLogRepository() : super(AppConstants.auditLogsCollection);

  @override
  AuditLogModel fromMap(Map<String, dynamic> map, String id) => AuditLogModel.fromMap(map, id);

  /// Writes one entry. `log.logId` must already be set (via [newId]) —
  /// see `AuditLogService`, the only intended caller.
  Future<Result<void>> record(AuditLogModel log) => save(log);

  Query<Map<String, dynamic>> _filtered({
    String? userId,
    AuditActionType? actionType,
    String? module,
    String? targetId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(collection);
    if (userId != null && userId.isNotEmpty) q = q.where('userId', isEqualTo: userId);
    if (actionType != null) q = q.where('actionType', isEqualTo: actionType.id);
    if (module != null && module.isNotEmpty) q = q.where('module', isEqualTo: module);
    if (targetId != null && targetId.isNotEmpty) q = q.where('targetId', isEqualTo: targetId);
    if (dateFrom != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: FirestoreConvert.toTimestamp(dateFrom));
    }
    if (dateTo != null) {
      q = q.where('createdAt', isLessThanOrEqualTo: FirestoreConvert.toTimestamp(dateTo));
    }
    return q.orderBy('createdAt', descending: true);
  }

  /// Cursor-paginated fetch. Audit trails grow unbounded — unlike the
  /// moderate per-course catalogs elsewhere in this codebase (see
  /// `LearningMaterialRepository.watchAllForAdmin`'s "grow the limit"
  /// convention) — so this uses real `startAfterDocument` pagination
  /// instead, per the Stage 3.6.1 spec's explicit pagination requirement.
  ///
  /// Combining more than one filter with the `createdAt` ordering needs
  /// a composite index; Firestore surfaces a console link to create it
  /// the first time a given combination runs, same as every other
  /// multi-`.where()` query in this codebase — see `docs/ARCHITECTURE.md`.
  Future<Result<AuditLogPage>> fetchPage({
    int pageSize = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? userId,
    AuditActionType? actionType,
    String? module,
    String? targetId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _filtered(
        userId: userId,
        actionType: actionType,
        module: module,
        targetId: targetId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ).limit(pageSize);
      if (startAfter != null) query = query.startAfterDocument(startAfter);

      final snapshot = await query.get();
      final logs = snapshot.docs.map((d) => fromMap(d.data(), d.id)).toList();
      return Result.success(AuditLogPage(
        logs: logs,
        lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
      ));
    } catch (e) {
      return resultFailureFrom(e);
    }
  }

  /// The most recent distinct actors, for the filter sheet's "User"
  /// dropdown — cheap alternative to scanning the whole `users`
  /// collection for who has ever performed a logged action. Bounded by
  /// [scanLimit] rather than exhaustive; fine for a "recent activity"
  /// filter, not meant to be a full user directory.
  Future<Result<List<AuditActor>>> fetchRecentActors({int scanLimit = 200}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .limit(scanLimit)
          .get();
      final seen = <String>{};
      final actors = <AuditActor>[];
      for (final doc in snapshot.docs) {
        final uid = doc.data()['userId'] as String? ?? '';
        if (uid.isEmpty || !seen.add(uid)) continue;
        actors.add(AuditActor(uid: uid, name: doc.data()['userName'] as String? ?? uid));
      }
      return Result.success(actors);
    } catch (e) {
      return resultFailureFrom(e);
    }
  }
}
