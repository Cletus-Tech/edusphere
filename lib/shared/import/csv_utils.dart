/// Stage 6.2.1 — Shared CSV Import Framework.
///
/// Extracted verbatim from `BulkQuestionUploadScreen`'s private
/// `_splitCsvLine`/row-splitting logic (Stage 6.1's audit target) —
/// behavior is unchanged, just no longer private to one screen, so
/// every future bulk-import module (Institutions, Faculties,
/// Departments, Levels, Semesters, Courses, Learning Materials) reads
/// CSVs the same way instead of each reimplementing this.
library;

/// One data row from a CSV file, already split into fields, with its
/// 1-indexed position in the *original file* (including the header)
/// preserved as [rowNumber] — this is what error messages and preview
/// rows should reference, since that's the row number a person would
/// actually see if they opened the CSV in a spreadsheet app.
class CsvRow {
  final int rowNumber;
  final List<String> fields;
  const CsvRow({required this.rowNumber, required this.fields});
}

/// Minimal CSV line splitter — handles double-quoted fields so a
/// cell's text can safely contain commas (e.g. "1,000|2,000|3,000" as
/// a pipe-separated option list would otherwise break on a naive
/// comma-split). Doesn't attempt full RFC 4180 (no multi-line quoted
/// fields) — matches what `BulkQuestionUploadScreen` already shipped
/// with, not expanded scope for this stage.
List<String> splitCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields.map((f) => f.trim()).toList();
}

/// Splits raw CSV file content into [CsvRow]s, skipping blank lines
/// and (when [skipHeader] is true, the default — every bulk-import
/// format in this codebase requires a header row) the first line.
List<CsvRow> readCsvRows(String content, {bool skipHeader = true}) {
  final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const [];

  final startIndex = skipHeader ? 1 : 0;
  final rows = <CsvRow>[];
  for (var i = startIndex; i < lines.length; i++) {
    rows.add(CsvRow(rowNumber: i + 1, fields: splitCsvLine(lines[i])));
  }
  return rows;
}
