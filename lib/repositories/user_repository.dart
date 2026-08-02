import '../core/constants/app_constants.dart';
import '../core/enums/user_role.dart';
import '../models/user_model.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository<UserModel> {
  UserRepository() : super(AppConstants.usersCollection);

  @override
  UserModel fromMap(Map<String, dynamic> map, String id) => UserModel.fromMap(map, id);

  Stream<UserModel?> watchUser(String uid) => streamById(uid);

  Future<void> assignRole(UserModel user, UserRole role) async {
    final updated = user.copyWith(roles: {...user.roles, role});
    await save(updated);
  }

  Future<void> revokeRole(UserModel user, UserRole role) async {
    final updated = user.copyWith(roles: {...user.roles}..remove(role));
    await save(updated);
  }
}
