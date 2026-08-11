import '../../core/utils/result.dart';
import 'csv_utils.dart';
import 'import_types.dart';

/// Stage 6.2.3 — optional companion to [CsvImportSpec] for modules that
/// need an async setup step before any row is parsed — e.g.
/// [BulkAcademicNodeImportScreen]'s `_AcademicNodeImportSpec` pre-fetching
/// institution/faculty/department/level name→id maps so [CsvImportSpec.parseRow]
/// can resolve parents synchronously per row.
///
/// Deliberately a separate interface a spec optionally also implements,
/// rather than a new member added to [CsvImportSpec] itself: adding a
/// required member there would force every existing implementer
/// (`BulkQuestionUploadScreen`'s spec, `BulkInstitutionImportScreen`'s
/// spec) to also implement it even though neither needs it. [CsvImportScreen]
/// checks `widget.spec is PreparableImportSpec` and calls this only when
/// present — every other module keeps working completely unchanged.
abstract class PreparableImportSpec {
  Future<void> prepare();
}

/// Stage 6.2.1 — Shared CSV Import Framework: the per-module contract.
///
/// A module (Bulk Questions today; Bulk Institutions/Faculties/
/// Departments/Levels/Semesters/Courses/Learning Materials per Stage
/// 6.1's audit, not built yet — see that stage's report) implements
/// this once and gets file selection, parsing, preview, validation
/// display, progress tracking, upload, and audit logging for free from
/// [CsvImportScreen]. Nothing module-specific lives in the framework;
/// nothing framework-level (file picking, progress UI) lives in a
/// module's spec — that split is the whole point of this stage.
abstract class CsvImportSpec<T> {
  /// AppBar title, e.g. `'Bulk Upload Questions'`.
  String get screenTitle;

  /// Heading for the format-help card, e.g. `'CSV format'`.
  String get formatHelpTitle;

  /// Body text for the format-help card — the column list, per-column
  /// rules, examples. Each module owns its own column format, so this
  /// is free text rather than a structured column spec; `Import
  /// History`/format-generation tooling (Stage 6.1's "future" items —
  /// Excel/JSON/Word-PDF, an Import Center hub) can revisit this if a
  /// later stage needs the columns machine-readable.
  String get formatHelpBody;

  /// File picker extension filter, e.g. `['csv']` or `['csv', 'json']`.
  List<String> get allowedExtensions;

  /// Logical column names, in the same order [parseRow] reads them
  /// positionally from a CSV row's fields. A JSON import (added
  /// Stage 6.2.2 — Bulk Institution Import) has no inherent column
  /// order of its own (JSON objects are key-value, not positional), so
  /// [readJsonRows] uses this to pull each object's fields into the
  /// exact same [CsvRow] shape a CSV row already produces — meaning
  /// [parseRow] never needs to know or care which format a row came
  /// from.
  List<String> get columnOrder;

  /// Parses one data row (header already stripped by [readCsvRows])
  /// into `T`, or returns an [ImportRowResult.invalid] with a
  /// human-readable reason. Called once per [CsvRow] by
  /// [CsvImportScreen] — a module never calls this itself.
  ImportRowResult<T> parseRow(CsvRow row);

  /// Persists one already-validated `T`. Framework calls this once
  /// per valid row during the upload phase and tracks
  /// success/failure counts itself — a module's [save] should do
  /// exactly one write (plus whatever that write's repository already
  /// does internally) and nothing else; audit logging for the *whole
  /// run* happens once via [logImport], not per row here.
  Future<Result<void>> save(T item);

  /// One-line preview text for a successfully parsed row, e.g. a
  /// question's `text`, a course's `courseName`. Kept to a single
  /// line/short by [CsvImportScreen]'s row-preview widget regardless
  /// of what's returned here.
  String describeValid(T item);

  /// Called once after the upload phase completes, with the final
  /// [uploadedCount] — a module logs through
  /// `AuditLogService.instance.log(...)` here with whatever
  /// module/target/title makes sense for its own entity type, mirroring
  /// exactly what `BulkQuestionUploadScreen` did inline before this
  /// stage extracted it.
  void logImport(int uploadedCount);
}

