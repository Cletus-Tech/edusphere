import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../core/enums/user_role.dart';
import 'firestore_model.dart';

/// Canonical user profile stored in Firestore under `users/{uid}`.
///
/// Stage 1 fields (uid, fullName, email, photoUrl, school, course,
/// createdAt) are untouched for backward compatibility with the existing
/// auth flow. Stage 1.2 adds the fields needed for RBAC, multi-institution
/// support, and personalization — all optional/defaulted so nothing that
/// already constructs a UserModel needs to change.
class UserModel extends Equatable implements FirestoreModel {
  final String uid;
  final String fullName;
  final String email;
  final String? photoUrl;
  final String? school;
  final String? course;
  final DateTime createdAt;

  // --- Stage 1.2: roles & academic affiliation ---------------------------
  final Set<UserRole> roles;
  final String? institutionId;
  final String? facultyId;
  final String? departmentId;
  final String? levelId;

  // --- Stage 1.2: preferences, notifications, verification ---------------
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> notificationSettings;
  final bool isVerified;
  final bool isSuspended;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.photoUrl,
    this.school,
    this.course,
    required this.createdAt,
    this.roles = const {UserRole.student},
    this.institutionId,
    this.facultyId,
    this.departmentId,
    this.levelId,
    this.preferences = const {},
    this.notificationSettings = const {},
    this.isVerified = false,
    this.isSuspended = false,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final rawRoles = map['roles'];
    final roleSet = rawRoles is List
        ? rawRoles.map((r) => UserRole.fromId(r.toString())).toSet()
        : <UserRole>{UserRole.student};

    return UserModel(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      school: map['school'] as String?,
      course: map['course'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roles: roleSet.isEmpty ? {UserRole.student} : roleSet,
      institutionId: map['institutionId'] as String?,
      facultyId: map['facultyId'] as String?,
      departmentId: map['departmentId'] as String?,
      levelId: map['levelId'] as String?,
      preferences: FirestoreConvert.map(map['preferences']),
      notificationSettings: FirestoreConvert.map(map['notificationSettings']),
      isVerified: map['isVerified'] as bool? ?? false,
      isSuspended: map['isSuspended'] as bool? ?? false,
      updatedAt: FirestoreConvert.dateTimeOrNull(map['updatedAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'photoUrl': photoUrl,
      'school': school,
      'course': course,
      'createdAt': Timestamp.fromDate(createdAt),
      'roles': roles.map((r) => r.id).toList(),
      'institutionId': institutionId,
      'facultyId': facultyId,
      'departmentId': departmentId,
      'levelId': levelId,
      'preferences': preferences,
      'notificationSettings': notificationSettings,
      'isVerified': isVerified,
      'isSuspended': isSuspended,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? photoUrl,
    String? school,
    String? course,
    Set<UserRole>? roles,
    String? institutionId,
    String? facultyId,
    String? departmentId,
    String? levelId,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? notificationSettings,
    bool? isVerified,
    bool? isSuspended,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      school: school ?? this.school,
      course: course ?? this.course,
      createdAt: createdAt,
      roles: roles ?? this.roles,
      institutionId: institutionId ?? this.institutionId,
      facultyId: facultyId ?? this.facultyId,
      departmentId: departmentId ?? this.departmentId,
      levelId: levelId ?? this.levelId,
      preferences: preferences ?? this.preferences,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      isVerified: isVerified ?? this.isVerified,
      isSuspended: isSuspended ?? this.isSuspended,
      updatedAt: DateTime.now(),
    );
  }

  bool hasRole(UserRole role) => roles.contains(role);

  @override
  String get id => uid;

  @override
  List<Object?> get props => [
        uid,
        fullName,
        email,
        photoUrl,
        school,
        course,
        roles,
        institutionId,
        facultyId,
        departmentId,
        levelId,
        isVerified,
        isSuspended,
      ];
}
