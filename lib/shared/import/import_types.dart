/// Stage 6.2.1 — Shared CSV Import Framework: generic result types.
///
/// Mirrors `BulkQuestionUploadScreen`'s private `_ParsedRow` exactly
/// (same valid/invalid shape, same 1-indexed row numbering), just
/// generic over the parsed type `T` so it isn't `QuestionModel`-only.
library;

/// The outcome of parsing one [CsvRow] into a domain object `T` — a
/// question, a course, an institution, whatever the module handles.
/// Exactly one of [data]/[error] is non-null; [ImportRowResult.valid]
/// and [ImportRowResult.invalid] enforce that at construction.
class ImportRowResult<T> {
  final int rowNumber;
  final T? data;
  final String? error;

  const ImportRowResult.valid(this.rowNumber, T value)
      : data = value,
        error = null;
  const ImportRowResult.invalid(this.rowNumber, String message)
      : data = null,
        error = message;

  bool get isValid => data != null;
}

/// Result of the upload phase, after preview/confirmation — how many
/// of the valid rows actually made it to Firestore. A row can be
/// "valid" (parsed cleanly) but still fail here (e.g. a transient
/// network error on `save()`), which is why this is tracked
/// separately from [ImportRowResult.isValid].
class ImportRunSummary {
  final int uploaded;
  final int failed;
  const ImportRunSummary({required this.uploaded, required this.failed});

  bool get hasFailures => failed > 0;
}
