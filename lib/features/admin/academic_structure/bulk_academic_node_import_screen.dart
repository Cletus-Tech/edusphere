import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/institution_model.dart';
import '../../../repositories/base_repository.dart';
import '../../../repositories/institution_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/import/csv_import_screen.dart';
import '../../../shared/import/csv_import_spec.dart';
import '../../../shared/import/csv_utils.dart';
import '../../../shared/import/import_types.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Stage 6.2.3 — Bulk Academic Structure Import.
///
/// One reusable import system for all four academic-tree levels
/// ([FacultyRepository]/[DepartmentRepository]/[LevelRepository]/
/// [SemesterRepository] — all just [AcademicNodeModel] in a different
/// collection, per [InstitutionRepository]'s own doc comment on that
/// pattern), not four separate ones — an admin picks the node type
/// first, then gets the same [CsvImportScreen] flow
/// [BulkInstitutionImportScreen] already established, via a spec that
/// switches its column set and parent-chain validation on the chosen
/// type. Manual Add/Edit/Delete for all four levels
/// ([AcademicNodeManagerScreen]) is untouched — this is an additional
/// entry point, not a replacement.
///
/// A row never carries Firestore ids — CSV/JSON can't know them — so
/// every parent (Institution, and for Department/Level/Semester,
/// Faculty/Department/Level respectively) is looked up **by name** at
/// import time. That lookup is inherently async (Firestore reads), so
/// this is what [CsvImportSpec.prepare] (added this stage) exists for:
/// [_AcademicNodeImportSpec.prepare] fetches every institution/
/// faculty/department/level once, builds name→id maps, and then
/// [_AcademicNodeImportSpec.parseRow] resolves each row synchronously
/// against those maps — same one-Firestore-round-trip-per-file
/// shape [BulkInstitutionImportScreen] achieves, just with a
/// pre-fetch step first.
class BulkAcademicNodeImportScreen extends StatefulWidget {
  const BulkAcademicNodeImportScreen({super.key});

  @override
  State<BulkAcademicNodeImportScreen> createState() => _BulkAcademicNodeImportScreenState();
}

enum _NodeType { faculty, department, level, semester }

extension on _NodeType {
  String get label => switch (this) {
        _NodeType.faculty => 'Faculty',
        _NodeType.department => 'Department',
        _NodeType.level => 'Level',
        _NodeType.semester => 'Semester',
      };

  String get description => switch (this) {
        _NodeType.faculty => 'Requires: Institution name, Faculty name.',
        _NodeType.department => 'Requires: Institution name, Faculty name, Department name.',
        _NodeType.level => 'Requires: Institution name, Department name, Level name.',
        _NodeType.semester => 'Requires: Institution name, Department name, Level name, Semester name.',
      };

  IconData get icon => switch (this) {
        _NodeType.faculty => Icons.account_balance_rounded,
        _NodeType.department => Icons.corporate_fare_rounded,
        _NodeType.level => Icons.stairs_rounded,
        _NodeType.semester => Icons.calendar_view_month_rounded,
      };
}

class _BulkAcademicNodeImportScreenState extends State<BulkAcademicNodeImportScreen> {
  _NodeType? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return CsvImportScreen<AcademicNodeModel>(spec: _AcademicNodeImportSpec(_selected!));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Academic Import')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(title: 'What are you importing?'),
            const SizedBox(height: 12),
            ..._NodeType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CustomCard(
                    onTap: () => setState(() => _selected = type),
                    child: Row(
                      children: [
                        Icon(type.icon, color: AppColors.primaryBlue),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(type.label, style: AppTextStyles.bodyLarge(AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(type.description, style: AppTextStyles.bodySmall(AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

String _key(String a, String b) => '${a.trim().toLowerCase()}|${b.trim().toLowerCase()}';
String _norm(String s) => s.trim().toLowerCase();

class _AcademicNodeImportSpec implements CsvImportSpec<AcademicNodeModel>, PreparableImportSpec {
  final _NodeType nodeType;
  _AcademicNodeImportSpec(this.nodeType);

  late final BaseRepository<AcademicNodeModel> _repository = switch (nodeType) {
    _NodeType.faculty => FacultyRepository(),
    _NodeType.department => DepartmentRepository(),
    _NodeType.level => LevelRepository(),
    _NodeType.semester => SemesterRepository(),
  };

  final Map<String, String> _institutionsByName = {}; // name -> institutionId
  final Map<String, String> _facultiesByKey = {}; // "institutionId|name" -> facultyId
  final Map<String, String> _departmentsByKey = {}; // "institutionId|name" -> departmentId
  final Map<String, String> _levelsByKey = {}; // "departmentId|name" -> levelId

  @override
  Future<void> prepare() async {
    final institutions = await InstitutionRepository().getWhere(query: (q) => q);
    _institutionsByName
      ..clear()
      ..addEntries(switch (institutions) {
        Success(data: final list) => list.map((i) => MapEntry(_norm(i.name), i.institutionId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    if (nodeType == _NodeType.faculty) return;

    final faculties = await FacultyRepository().getWhere(query: (q) => q);
    _facultiesByKey
      ..clear()
      ..addEntries(switch (faculties) {
        Success(data: final list) => list.map((f) => MapEntry(_key(f.institutionId, f.name), f.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    if (nodeType == _NodeType.department) return;

    final departments = await DepartmentRepository().getWhere(query: (q) => q);
    _departmentsByKey
      ..clear()
      ..addEntries(switch (departments) {
        Success(data: final list) => list.map((d) => MapEntry(_key(d.institutionId, d.name), d.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });

    if (nodeType == _NodeType.level) return;

    final levels = await LevelRepository().getWhere(query: (q) => q);
    _levelsByKey
      ..clear()
      ..addEntries(switch (levels) {
        // Level.parentId is the owning department's nodeId — scoping by
        // departmentId (not institutionId) here is deliberate: level
        // names like "100 Level" repeat across many departments in the
        // same institution, so institutionId alone wouldn't disambiguate.
        Success(data: final list) => list.map((l) => MapEntry(_key(l.parentId ?? '', l.name), l.nodeId)),
        Failure() => const <MapEntry<String, String>>[],
      });
  }

  @override
  String get screenTitle => 'Bulk Import ${nodeType.label}s';

  @override
  List<String> get allowedExtensions => const ['csv', 'json'];

  @override
  List<String> get columnOrder => switch (nodeType) {
        _NodeType.faculty => const ['institutionName', 'name', 'code', 'order', 'isActive'],
        _NodeType.department => const ['institutionName', 'facultyName', 'name', 'code', 'order', 'isActive'],
        _NodeType.level => const ['institutionName', 'departmentName', 'name', 'code', 'order', 'isActive'],
        _NodeType.semester => const [
            'institutionName',
            'departmentName',
            'levelName',
            'name',
            'code',
            'order',
            'isActive'
          ],
      };

  @override
  String get formatHelpTitle => 'CSV or JSON format';

  @override
  String get formatHelpBody =>
      'CSV: one header row (skipped), then one ${nodeType.label.toLowerCase()} per row. '
      'JSON: an array of objects. Either way, these fields:\n\n'
      '${columnOrder.join(', ')}\n\n'
      '${nodeType.description}\n'
      '• name: required\n'
      '• code, order: optional (order defaults to 0)\n'
      '• isActive: optional — true/false, defaults to true if blank\n\n'
      'Every parent above must already exist — this import links to '
      'existing Institutions/Faculties/Departments/Levels by name, it '
      'doesn\'t create them.';

  @override
  ImportRowResult<AcademicNodeModel> parseRow(CsvRow row) {
    final f = row.fields;
    final rowNumber = row.rowNumber;
    var i = 0;

    if (f.length < columnOrder.length - 3) {
      // Loosest possible floor: institutionName + every parent-name
      // column + name must be present; code/order/isActive may be
      // omitted entirely (same trailing-optional-columns allowance
      // BulkInstitutionImportScreen gives state/country/isActive).
      return ImportRowResult.invalid(rowNumber, 'Not enough columns — expected ${columnOrder.join(', ')}.');
    }

    final institutionName = f[i++].trim();
    if (institutionName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Institution name is empty.');
    final institutionId = _institutionsByName[_norm(institutionName)];
    if (institutionId == null) {
      return ImportRowResult.invalid(rowNumber, 'Institution "$institutionName" doesn\'t exist.');
    }

    String? parentId;

    if (nodeType == _NodeType.department || nodeType == _NodeType.level || nodeType == _NodeType.semester) {
      // department: this column IS the direct parent (Faculty).
      // level/semester: this column resolves the Department, which is
      // itself only an intermediate step for semester (see below).
      final parentColName = f[i++].trim();
      if (nodeType == _NodeType.department) {
        if (parentColName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Faculty name is empty.');
        final facultyId = _facultiesByKey[_key(institutionId, parentColName)];
        if (facultyId == null) {
          return ImportRowResult.invalid(
              rowNumber, 'Faculty "$parentColName" doesn\'t exist under institution "$institutionName".');
        }
        parentId = facultyId;
      } else {
        if (parentColName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Department name is empty.');
        final departmentId = _departmentsByKey[_key(institutionId, parentColName)];
        if (departmentId == null) {
          return ImportRowResult.invalid(
              rowNumber, 'Department "$parentColName" doesn\'t exist under institution "$institutionName".');
        }
        if (nodeType == _NodeType.level) {
          parentId = departmentId;
        } else {
          // semester — one more hop: resolve Level under this department.
          final levelName = f[i++].trim();
          if (levelName.isEmpty) return ImportRowResult.invalid(rowNumber, 'Level name is empty.');
          final levelId = _levelsByKey[_key(departmentId, levelName)];
          if (levelId == null) {
            return ImportRowResult.invalid(
                rowNumber, 'Level "$levelName" doesn\'t exist under department "$parentColName".');
          }
          parentId = levelId;
        }
      }
    }

    final name = i < f.length ? f[i++].trim() : '';
    if (name.isEmpty) return ImportRowResult.invalid(rowNumber, '${nodeType.label} name is empty.');

    String? code;
    if (i < f.length) {
      final raw = f[i++].trim();
      code = raw.isEmpty ? null : raw;
    }

    final orderRaw = i < f.length ? f[i++].trim() : '';
    final order = orderRaw.isEmpty ? 0 : int.tryParse(orderRaw);
    if (order == null) return ImportRowResult.invalid(rowNumber, 'order must be a whole number — got "$orderRaw".');

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
      AcademicNodeModel(
        nodeId: _repository.newId(),
        institutionId: institutionId,
        parentId: parentId,
        name: name,
        code: code,
        order: order,
        isActive: isActive,
      ),
    );
  }

  @override
  Future<Result<void>> save(AcademicNodeModel item) => _repository.save(item);

  @override
  String describeValid(AcademicNodeModel item) =>
      item.code == null || item.code!.isEmpty ? item.name : '${item.name} (${item.code})';

  @override
  void logImport(int uploadedCount) {
    AuditLogService.instance.log(
      action: AuditActionType.create,
      module: AuditModules.academicStructure,
      targetCollection: _repository.collection,
      targetId: 'bulk-import',
      targetTitle: 'Bulk import ($uploadedCount ${nodeType.label.toLowerCase()}${uploadedCount == 1 ? '' : 's'})',
    );
  }
}
