import 'package:flutter/material.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/course_model.dart';
import '../../../models/institution_model.dart';
import '../../../repositories/course_repository.dart';
import '../../../repositories/institution_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/import/csv_import_screen.dart';
import '../../../shared/import/csv_import_spec.dart';
import '../../../shared/import/csv_utils.dart';
import '../../../shared/import/import_types.dart';

/// Stage 6.2.4 — Bulk Course Import.
///
/// Reuses [CsvImportScreen] exactly as [BulkAcademicNodeImportScreen]
/// does (see that stage's changelog), against the existing
/// [CourseModel]/[CourseRepository] — no new model, repository, or
/// Firestore collection.
///
/// **Placement decision:** the brief's flow diagram shows this
/// entry point under "Course Management," which in this codebase is
/// `CourseManagerScreen` — but that screen is permanently scoped to
/// one institution+department+level+semester (all four are required
/// constructor params), while the brief's own validation list asks
/// for a full Institution→Faculty→Department→Level→Semester check
/// **per row**, implying an import file can span multiple
/// semesters/departments in one go. A screen fixed to one semester
/// can't honor that. So this follows the same placement
/// `BulkAcademicNodeImportScreen` uses instead: a standalone entry
/// point from `AcademicStructureScreen`'s AppBar, where every row is
/// fully self-contained (its own institution/faculty/department/
/// level/semester names) rather than inheriting a fixed screen
/// context. `CourseManagerScreen`'s existing Add/Edit/Delete are
/// unchanged either way.
///
/// **Faculty validation:** [CourseModel] has no `facultyId` field —
/// a course's chain is `institutionId`/`departmentId`/`levelId`/
/// `semesterId` only, matching [CourseModel] exactly (no field added,
/// per the brief's "Do not add fields unless required"). Faculty is
/// still one of the five things validated per the brief's own list —
/// used here to confirm the named Department is actually *under* the
/// named Faculty (`parentId` match), not merely that a
/// same-institution department with that name exists somewhere.
/// That's what produces the brief's own example error verbatim:
/// `Department "Computer Science" not found under selected Faculty.`
class BulkCourseImportScreen extends StatelessWidget {
  const BulkCourseImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CsvImportScreen<CourseModel>(spec: _CourseImportSpec());
  }
}

String _key(String a, String b) => '${a.trim().toLowerCase()}|${b.trim().toLowerCase()}';
String _norm(String s) => s.trim().toLowerCase();

class _CourseImportSpec implements CsvImportSpec<CourseModel>, PreparableImportSpec {
  final _repository = CourseRepository();

  final Map<String, String> _institutionsByName = {}; // name -> institutionId
  final Map<String, String> _facultiesByKey = {}; // "institutionId|name" -> facultyId
  // Keyed by facultyId (not institutionId, unlike the academic-node
  // importer's own department cache) — this is what lets `parseRow`
  // confirm a department sits under the *specific* faculty a row
  // names, not just under the same institution somewhere.
  final Map<String, String> _departmentsByKey = {}; // "facultyId|name" -> departmentId
  final Map<String, String> _levelsByKey = {}; // "departmentId|name" -> levelId
  final Map<String, String> _semestersByKey = {}; // "levelId|name" -> semesterId

  @override
  Future<void> prepare() async {
    final institutions = await InstitutionRepository().getWhere(query: (q) => q);
    _institutionsByName
      ..clear()
      ..addEntries(switch (institutions) {
        Success(data: final list) => list.map((i) => MapEntry(_norm(i.name), i.institutionId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    final faculties = await FacultyRepository().getWhere(query: (q) => q);
    _facultiesByKey
      ..clear()
      ..addEntries(switch (faculties) {
        Success(data: final list) => list.map((f) => MapEntry(_key(f.institutionId, f.name), f.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    final departments = await DepartmentRepository().getWhere(query: (q) => q);
    _departmentsByKey
      ..clear()
      ..addEntries(switch (departments) {
        Success(data: final list) => list.map((d) => MapEntry(_key(d.parentId ?? '', d.name), d.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    final levels = await LevelRepository().getWhere(query: (q) => q);
    _levelsByKey
      ..clear()
      ..addEntries(switch (levels) {
        Success(data: final list) => list.map((l) => MapEntry(_key(l.parentId ?? '', l.name), l.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    final semesters = await SemesterRepository().getWhere(query: (q) => q);
    _semestersByKey
      ..clear()
      ..addEntries(switch (semesters) {
        Success(data: final list) => list.map((s) => MapEntry(_key(s.parentId ?? '', s.name), s.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });
  }

  @override
  String get screenTitle => 'Bulk Import Courses';

  @override
  List<String> get allowedExtensions => const ['csv', 'json'];

  @override
  List<String> get columnOrder => const [
        'institutionName',
        'facultyName',
        'departmentName',
        'levelName',
        'semesterName',
        'code',
        'title',
        'description',
        'isActive',
      ];

  @override
  String get formatHelpTitle => 'CSV or JSON format';

  @override
  String get formatHelpBody => 'CSV: one header row (skipped), then one course per row. '
      'JSON: an array of objects. Either way, these fields:\n\n'
      '${columnOrder.join(', ')}\n\n'
      '• institutionName/facultyName/departmentName/levelName/semesterName: required — '
      'must already exist, and each must actually be nested under the one named before it\n'
      '• code, title: required\n'
      '• description: optional\n'
      '• isActive: optional — true/false, defaults to true if blank\n\n'
      'This links courses to existing Institutions/Faculties/Departments/Levels/Semesters '
      'by name — it doesn\'t create any of them.';

  @override
  ImportRowResult<CourseModel> parseRow(CsvRow row) {
    final f = row.fields;
    final rowNumber = row.rowNumber;

    if (f.length < columnOrder.length - 2) {
      return ImportRowResult.invalid(rowNumber, 'Not enough columns — expected ${columnOrder.join(', ')}.');
    }

    final institutionName = f[0].trim();
    if (institutionName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Institution name is empty.');
    final institutionId = _institutionsByName[_norm(institutionName)];
    if (institutionId == null) {
      return ImportRowResult.invalid(rowNumber, 'Institution "$institutionName" doesn\'t exist.');
    }

    final facultyName = f[1].trim();
    if (facultyName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Faculty name is empty.');
    final facultyId = _facultiesByKey[_key(institutionId, facultyName)];
    if (facultyId == null) {
      return ImportRowResult.invalid(
          rowNumber, 'Faculty "$facultyName" doesn\'t exist under institution "$institutionName".');
    }

    final departmentName = f[2].trim();
    if (departmentName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Department name is empty.');
    final departmentId = _departmentsByKey[_key(facultyId, departmentName)];
    if (departmentId == null) {
      return ImportRowResult.invalid(rowNumber, 'Department "$departmentName" not found under selected Faculty.');
    }

    final levelName = f[3].trim();
    if (levelName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Level name is empty.');
    final levelId = _levelsByKey[_key(departmentId, levelName)];
    if (levelId == null) {
      return ImportRowResult.invalid(rowNumber, 'Level "$levelName" not found under selected Department.');
    }

    final semesterName = f[4].trim();
    if (semesterName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Semester name is empty.');
    final semesterId = _semestersByKey[_key(levelId, semesterName)];
    if (semesterId == null) {
      return ImportRowResult.invalid(rowNumber, 'Semester "$semesterName" not found under selected Level.');
    }

    var i = 5;
    final code = i < f.length ? f[i++].trim() : '';
    if (code.isEmpty) return ImportRowResult.invalid(rowNumber, 'Course code is empty.');

    final title = i < f.length ? f[i++].trim() : '';
    if (title.isEmpty) return ImportRowResult.invalid(rowNumber, 'Course title is empty.');

    String? description;
    if (i < f.length) {
      final raw = f[i++].trim();
      description = raw.isEmpty ? null : raw;
    }

    final isActiveRaw = i < f.length ? f[i++].trim().toLowerCase() : '';
    bool isActive;
    if (isActiveRaw.isEmpty || isActiveRaw == 'true') {
      isActive = true;
    } else if (isActiveRaw == 'false') {
      isActive = false;
    } else {
      return ImportRowResult.invalid(rowNumber, 'isActive must be "true", "false", or blank — got "$isActiveRaw".');
    }

    return ImportRowResult.valid(
      rowNumber,
      CourseModel(
        courseId: _repository.newId(),
        title: title,
        code: code,
        institutionId: institutionId,
        departmentId: departmentId,
        levelId: levelId,
        semesterId: semesterId,
        description: description,
        isActive: isActive,
      ),
    );
  }

  @override
  Future<Result<void>> save(CourseModel item) => _repository.save(item);

  @override
  String describeValid(CourseModel item) => '${item.code} — ${item.title}';

  @override
  void logImport(int uploadedCount) {
    AuditLogService.instance.log(
      action: AuditActionType.create,
      module: AuditModules.academicStructure,
      targetCollection: _repository.collection,
      targetId: 'bulk-import',
      targetTitle: 'Bulk import ($uploadedCount course${uploadedCount == 1 ? '' : 's'})',
    );
  }
}
