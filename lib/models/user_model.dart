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

  // --- Stage 4.3: rest of the academic hierarchy on the profile ----------
  // `institutionType` is stored alongside `institutionId` (rather than
  // looked up from the institution doc on every read) so profile UI and
  // any future institution-type-scoped queries don't need an extra fetch
  // just to know "is this a university/polytechnic/college/secondary
  // school student". `programme` is free-form (ND/HND/B.Sc/B.Eng/etc.) —
  // deliberately not a new collection; see Stage 4.3 changelog.
  final String? institutionType;
  final String? semesterId;
  final String? programme;

  // --- Stage 1.2: preferences, notifications, verification ---------------
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> notificationSettings;
  final bool isVerified;
  final bool isSuspended;
  final DateTime? updatedAt;

  // --- Stage 4.8C: premium subscription -----------------------------------
  // Admin-controlled per the CBT Engine Core spec ("Premium logic must
  // never be hardcoded") — an admin (or a future payment webhook) sets
  // these, features just read [isPremiumActive]. `premiumExpiresAt: null`
  // with `isPremium: true` means an admin-granted permanent premium
  // (e.g. staff/scholarship), not an oversight — [isPremiumActive] treats
  // a null expiry as "doesn't expire" rather than "already expired".
  final bool isPremium;
  final DateTime? premiumExpiresAt;

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
    this.institutionType,
    this.semesterId,
    this.programme,
    this.preferences = const {},
    this.notificationSettings = const {},
    this.isVerified = false,
    this.isSuspended = false,
    this.updatedAt,
    this.isPremium = false,
    this.premiumExpiresAt,
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
      institutionType: map['institutionType'] as String?,
      semesterId: map['semesterId'] as String?,
      programme: map['programme'] as String?,
      preferences: FirestoreConvert.map(map['preferences']),
      notificationSettings: FirestoreConvert.map(map['notificationSettings']),
      isVerified: map['isVerified'] as bool? ?? false,
      isSuspended: map['isSuspended'] as bool? ?? false,
      updatedAt: FirestoreConvert.dateTimeOrNull(map['updatedAt']),
      isPremium: map['isPremium'] as bool? ?? false,
      premiumExpiresAt: FirestoreConvert.dateTimeOrNull(map['premiumExpiresAt']),
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
      'institutionType': institutionType,
      'semesterId': semesterId,
      'programme': programme,
      'preferences': preferences,
      'notificationSettings': notificationSettings,
      'isVerified': isVerified,
      'isSuspended': isSuspended,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
      'isPremium': isPremium,
      if (premiumExpiresAt != null) 'premiumExpiresAt': Timestamp.fromDate(premiumExpiresAt!),
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
    String? institutionType,
    String? semesterId,
    String? programme,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? notificationSettings,
    bool? isVerified,
    bool? isSuspended,
    bool? isPremium,
    DateTime? premiumExpiresAt,
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
      institutionType: institutionType ?? this.institutionType,
      semesterId: semesterId ?? this.semesterId,
      programme: programme ?? this.programme,
      preferences: preferences ?? this.preferences,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      isVerified: isVerified ?? this.isVerified,
      isSuspended: isSuspended ?? this.isSuspended,
      updatedAt: DateTime.now(),
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
    );
  }

  bool hasRole(UserRole role) => roles.contains(role);

  /// Whether premium access is usable right now — true if granted and
  /// either permanent (`premiumExpiresAt == null`) or not yet expired.
  bool get isPremiumActive => isPremium && (premiumExpiresAt == null || DateTime.now().isBefore(premiumExpiresAt!));

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
        institutionType,
        semesterId,
        programme,
        isVerified,
        isSuspended,
        isPremium,
        premiumExpiresAt,
      ];
}
