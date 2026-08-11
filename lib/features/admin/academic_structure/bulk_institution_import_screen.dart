import 'package:flutter/widgets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/institution_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/institution_model.dart';
import '../../../repositories/institution_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/import/csv_import_screen.dart';
import '../../../shared/import/csv_import_spec.dart';
import '../../../shared/import/csv_utils.dart';
import '../../../shared/import/import_types.dart';

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// Stage 6.2.2 — Bulk Institution Import.
///
/// Companion to [AcademicStructureScreen]'s manual "Add Institution"
/// dialog, same relationship [BulkQuestionUploadScreen] has to
/// [QuestionManagerScreen]'s manual form. Built entirely on the Stage
/// 6.2.1 shared framework (`CsvImportScreen`/`CsvImportSpec`) — this
/// file is nothing but the institution-specific parsing/save/audit
/// rules; file selection, preview, progress, and summary are all
/// inherited unchanged.
///
/// Column format (CSV, header row required) or JSON (array of objects
/// with these keys — order doesn't matter in JSON):
/// name, shortName, type, state, country, isActive
///
/// - name: required
/// - shortName: required (short code, e.g. "FUTA")
/// - type: required — one of: university, polytechnic,
///   collegeOfEducation, secondarySchool, trainingCenter
/// - state: optional
/// - country: optional, defaults to "Nigeria" (matches
///   `InstitutionModel`'s own default)
/// - isActive: optional — "true"/"false", defaults to true if blank
///   (matches `InstitutionModel`'s own default)
///
/// Note on required fields: the manual "Add Institution" dialog in
/// `AcademicStructureScreen` only hard-requires `name` — `shortName`
/// and `type` are optional there (type falls back to `university`).
/// This bulk import is intentionally slightly stricter on `shortName`
/// and `type`, per this stage's brief listing them as required —
/// there's no interactive moment to notice and fix a missing type on
/// row 47 of a 200-row file the way there is with one dialog, so
/// catching it at preview time is more useful here than defaulting
/// silently. `state`/`isActive` keep the model's own defaulting
/// behavior since the brief only lists Location as required "if
/// supported" and doesn't ask for isActive to reject blanks.
class BulkInstitutionImportScreen extends StatelessWidget {
  const BulkInstitutionImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CsvImportScreen<InstitutionModel>(spec: _InstitutionImportSpec());
  }
}

class _InstitutionImportSpec implements CsvImportSpec<InstitutionModel> {
  final InstitutionRepository repository = InstitutionRepository();

  @override
  String get screenTitle => 'Bulk Import Institutions';

  @override
  List<String> get allowedExtensions => const ['csv', 'json'];

  @override
  List<String> get columnOrder => const ['name', 'shortName', 'type', 'state', 'country', 'isActive'];

  @override
  String get formatHelpTitle => 'CSV or JSON format';

  @override
  String get formatHelpBody =>
      'CSV: one header row (skipped), then one institution per row. '
      'JSON: an array of objects. Either way, these fields:\n\n'
      'name, shortName, type, state, country, isActive\n\n'
      '• name: required\n'
      '• shortName: required — short code, e.g. FUTA\n'
      '• type: required — one of: university, polytechnic, '
      'collegeOfEducation, secondarySchool, trainingCenter\n'
      '• state: optional\n'
      '• country: optional, defaults to Nigeria\n'
      '• isActive: optional — true/false, defaults to true if blank';

  @override
  ImportRowResult<InstitutionModel> parseRow(CsvRow row) {
    final fields = row.fields;
    final rowNumber = row.rowNumber;

    if (fields.length < 3) {
      return ImportRowResult.invalid(
        rowNumber,
        'Expected at least name, shortName, type — found ${fields.length} column(s).',
      );
    }

    final name = fields[0].trim();
    if (name.isEmpty) {
      return ImportRowResult.invalid(rowNumber, 'Institution name is empty.');
    }

    final shortName = fields[1].trim();
    if (shortName.isEmpty) {
      return ImportRowResult.invalid(rowNumber, 'Short name/code is empty.');
    }

    final typeStr = fields[2].trim();
    final type = _firstWhereOrNull(InstitutionType.values, (t) => t.id.toLowerCase() == typeStr.toLowerCase());
    if (type == null) {
      return ImportRowResult.invalid(
        rowNumber,
        '"$typeStr" isn\'t a supported type. Use one of: ${InstitutionType.values.map((t) => t.id).join(', ')}.',
      );
    }

    final state = fields.length > 3 ? fields[3].trim() : '';
    final country = fields.length > 4 && fields[4].trim().isNotEmpty ? fields[4].trim() : 'Nigeria';

    final isActiveRaw = fields.length > 5 ? fields[5].trim().toLowerCase() : '';
    bool isActive;
    if (isActiveRaw.isEmpty) {
      isActive = true;
    } else if (isActiveRaw == 'true') {
      isActive = true;
    } else if (isActiveRaw == 'false') {
      isActive = false;
    } else {
      return ImportRowResult.invalid(rowNumber, 'isActive must be "true", "false", or blank — got "$isActiveRaw".');
    }

    return ImportRowResult.valid(
      rowNumber,
      InstitutionModel(
        institutionId: repository.newId(),
        name: name,
        shortName: shortName,
        type: type,
        state: state.isEmpty ? null : state,
        country: country,
        isActive: isActive,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<void>> save(InstitutionModel item) => repository.save(item);

  @override
  String describeValid(InstitutionModel item) => '${item.name} (${item.shortName})';

  @override
  void logImport(int uploadedCount) {
    AuditLogService.instance.log(
      action: AuditActionType.create,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.institutionsCollection,
      targetId: 'bulk-import',
      targetTitle: 'Bulk import ($uploadedCount institution${uploadedCount == 1 ? '' : 's'})',
    );
  }
}
