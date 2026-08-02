import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// `courses/{courseId}` — a tertiary-level course, or `subjects/{id}` —
/// a secondary-level/exam-board subject. Kept as one shape (subjects use
/// the same fields with `departmentId`/`levelId` left null) so the Learn
/// module doesn't need two parallel query paths.
class CourseModel extends Equatable implements FirestoreModel {
  final String courseId;
  final String title;
  final String code;
  final String? institutionId;
  final String? departmentId;
  final String? levelId;
  final String? semesterId;
  final String? categoryId;
  final String? description;
  final String? iconUrl;
  final int contentCount;
  final bool isActive;

  const CourseModel({
    required this.courseId,
    required this.title,
    this.code = '',
    this.institutionId,
    this.departmentId,
    this.levelId,
    this.semesterId,
    this.categoryId,
    this.description,
    this.iconUrl,
    this.contentCount = 0,
    this.isActive = true,
  });

  factory CourseModel.fromMap(Map<String, dynamic> map, String courseId) {
    return CourseModel(
      courseId: courseId,
      title: map['title'] as String? ?? '',
      code: map['code'] as String? ?? '',
      institutionId: map['institutionId'] as String?,
      departmentId: map['departmentId'] as String?,
      levelId: map['levelId'] as String?,
      semesterId: map['semesterId'] as String?,
      categoryId: map['categoryId'] as String?,
      description: map['description'] as String?,
      iconUrl: map['iconUrl'] as String?,
      contentCount: map['contentCount'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'code': code,
        'institutionId': institutionId,
        'departmentId': departmentId,
        'levelId': levelId,
        'semesterId': semesterId,
        'categoryId': categoryId,
        'description': description,
        'iconUrl': iconUrl,
        'contentCount': contentCount,
        'isActive': isActive,
      };

  @override
  String get id => courseId;

  @override
  List<Object?> get props => [courseId, title, code, isActive];
}
