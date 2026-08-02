import '../core/constants/app_constants.dart';
import '../core/enums/user_role.dart';
import '../core/utils/result.dart';
import '../models/user_model.dart';
import '../services/audit/audit_log_service.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository<UserModel> {
  UserRepository() : super(AppConstants.usersCollection);

  @override
  UserModel fromMap(Map<String, dynamic> map, String id) => UserModel.fromMap(map, id);

  Stream<UserModel?> watchUser(String uid) => streamById(uid);

  /// All users, for the admin Users & Roles screen. `firestore.rules`
  /// lets any signed-in user read `users/*`, so this is safe to call
  /// from anywhere — the screen itself is what's gated to staff.
  /// Search is client-side (no `fullNameLower`/search-index field
  /// exists on [UserModel] yet), so this pulls a bounded page rather
  /// than the whole collection.
  Stream<List<UserModel>> watchAllUsers({int limit = 200}) {
    return streamCollection(
      query: (q) => q.orderBy('fullName'),
      limit: limit,
    );
  }

  /// Replaces a user's whole role set in one write + one audit entry,
  /// rather than logging once per checkbox toggled in the Users & Roles
  /// sheet. `firestore.rules` requires `isAdmin()` for this write to
  /// succeed for anyone other than the user themself.
  Future<Result<void>> replaceRoles(UserModel user, Set<UserRole> newRoles) async {
    final result = await save(user.copyWith(roles: newRoles));
    if (result.isSuccess) {
      AuditLogService.instance.logRoleChanged(
        targetUid: user.uid,
        targetName: user.fullName,
        previousRoles: user.roles.map((r) => r.id).toList(),
        newRoles: newRoles.map((r) => r.id).toList(),
      );
    }
    return result;
  }

  Future<Result<void>> setSuspended(UserModel user, bool suspended, {String? reason}) async {
    final result = await save(user.copyWith(isSuspended: suspended));
    if (result.isSuccess) {
      if (suspended) {
        AuditLogService.instance.logUserSuspended(targetUid: user.uid, targetName: user.fullName, reason: reason);
      } else {
        AuditLogService.instance.logUserRestored(targetUid: user.uid, targetName: user.fullName);
      }
    }
    return result;
  }
}
