import '../core/constants/app_constants.dart';
import '../models/institution_model.dart';
import 'base_repository.dart';

class InstitutionRepository extends BaseRepository<InstitutionModel> {
  InstitutionRepository() : super(AppConstants.institutionsCollection);

  @override
  InstitutionModel fromMap(Map<String, dynamic> map, String id) =>
      InstitutionModel.fromMap(map, id);

  Stream<List<InstitutionModel>> watchActive({String? typeId}) {
    return streamCollection(
      query: (q) {
        var ref = q.where('isActive', isEqualTo: true);
        if (typeId != null) ref = ref.where('type', isEqualTo: typeId);
        return ref;
      },
    );
  }
}

/// One repository per academic-tree level. They share
/// [AcademicNodeModel]'s shape but live in distinct collections so
/// security rules and indexes can differ per level.
class FacultyRepository extends BaseRepository<AcademicNodeModel> {
  FacultyRepository() : super(AppConstants.facultiesCollection);

  @override
  AcademicNodeModel fromMap(Map<String, dynamic> map, String id) =>
      AcademicNodeModel.fromMap(map, id);

  Stream<List<AcademicNodeModel>> watchByInstitution(String institutionId) {
    return streamCollection(
      query: (q) => q.where('institutionId', isEqualTo: institutionId).where('isActive', isEqualTo: true),
    );
  }
}

class DepartmentRepository extends BaseRepository<AcademicNodeModel> {
  DepartmentRepository() : super(AppConstants.departmentsCollection);

  @override
  AcademicNodeModel fromMap(Map<String, dynamic> map, String id) =>
      AcademicNodeModel.fromMap(map, id);

  Stream<List<AcademicNodeModel>> watchByFaculty(String facultyId) {
    return streamCollection(
      query: (q) => q.where('parentId', isEqualTo: facultyId).where('isActive', isEqualTo: true),
    );
  }
}

class LevelRepository extends BaseRepository<AcademicNodeModel> {
  LevelRepository() : super(AppConstants.levelsCollection);

  @override
  AcademicNodeModel fromMap(Map<String, dynamic> map, String id) =>
      AcademicNodeModel.fromMap(map, id);

  Stream<List<AcademicNodeModel>> watchByDepartment(String departmentId) {
    return streamCollection(
      query: (q) => q.where('parentId', isEqualTo: departmentId).where('isActive', isEqualTo: true),
    );
  }
}

class SemesterRepository extends BaseRepository<AcademicNodeModel> {
  SemesterRepository() : super(AppConstants.semestersCollection);

  @override
  AcademicNodeModel fromMap(Map<String, dynamic> map, String id) =>
      AcademicNodeModel.fromMap(map, id);

  Stream<List<AcademicNodeModel>> watchByLevel(String levelId) {
    return streamCollection(
      query: (q) => q.where('parentId', isEqualTo: levelId).where('isActive', isEqualTo: true),
    );
  }
}
