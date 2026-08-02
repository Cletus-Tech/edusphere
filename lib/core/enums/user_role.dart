/// Every role EduSphere's RBAC system supports. Users may hold more than
/// one (e.g. a student who is also a content creator), so [UserModel]
/// stores these as a `Set<UserRole>`, never a single value.
enum UserRole {
  superAdmin,
  admin,
  institutionAdmin,
  lecturer,
  teacher,
  student,
  parent,
  contentCreator,
  moderator,
  guest;

  String get id => name;

  static UserRole fromId(String id) => UserRole.values.firstWhere(
        (r) => r.id == id,
        orElse: () => UserRole.guest,
      );

  /// Coarse privilege check used by repositories before falling back to
  /// server-side Firestore security rules (which remain the source of
  /// truth — this is only for UI-level gating).
  bool get isElevated => switch (this) {
        UserRole.superAdmin ||
        UserRole.admin ||
        UserRole.institutionAdmin ||
        UserRole.moderator =>
          true,
        _ => false,
      };
}
