import '../core/constants/app_constants.dart';
import '../models/course_model.dart';
import 'base_repository.dart';

class CourseRepository extends BaseRepository<CourseModel> {
  CourseRepository() : super(AppConstants.coursesCollection);

  @override
  CourseModel fromMap(Map<String, dynamic> map, String id) => CourseModel.fromMap(map, id);

  Stream<List<CourseModel>> watchByDepartmentAndLevel({
    required String departmentId,
    required String levelId,
  }) {
    return streamCollection(
      query: (q) => q
          .where('departmentId', isEqualTo: departmentId)
          .where('levelId', isEqualTo: levelId)
          .where('isActive', isEqualTo: true),
    );
  }
}

/// `subjects/{subjectId}` — same shape as courses, used for
/// secondary-school/exam-board subjects. Kept as a distinct collection
/// (per the Stage 1.2 schema) but reuses [CourseModel] rather than a
/// near-duplicate class.
class SubjectRepository extends BaseRepository<CourseModel> {
  SubjectRepository() : super(AppConstants.subjectsCollection);

  @override
  CourseModel fromMap(Map<String, dynamic> map, String id) => CourseModel.fromMap(map, id);

  Stream<List<CourseModel>> watchByCategory(String categoryId) {
    return streamCollection(
      query: (q) => q.where('categoryId', isEqualTo: categoryId).where('isActive', isEqualTo: true),
    );
  }
}
