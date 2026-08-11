import 'dart:convert';
import 'csv_utils.dart';

/// Stage 6.2.2 — JSON import support, added to the Stage 6.2.1 CSV
/// framework. Expects the file's top-level JSON value to be an array
/// of objects (one object per record, keys are column names — order
/// doesn't matter in the JSON itself). Each object is converted into a
/// [CsvRow] by reading [columnOrder]'s keys out of it in order, so a
/// [CsvImportSpec.parseRow] implementation never has to branch on
/// whether a row came from CSV or JSON — both arrive as the same
/// positional field list.
///
/// [rowNumber] starts at 2 (not 1) to match CSV's numbering, where row
/// 1 is a header a person would see if they opened the file — keeps
/// error messages ("Row 3: ...") meaning the same thing regardless of
/// which format was used, since a JSON array's first *record* is
/// conceptually "the row after the header" even though JSON has no
/// literal header row.
///
/// Throws [FormatException] on invalid JSON or a non-array top level —
/// callers should catch this and show a whole-file error, the same way
/// a malformed CSV with zero readable rows would be handled.
List<CsvRow> readJsonRows(String content, List<String> columnOrder) {
  final decoded = jsonDecode(content);
  if (decoded is! List) {
    throw const FormatException('Expected a JSON array of objects — e.g. [{"name": "..."}, {"name": "..."}].');
  }

  final rows = <CsvRow>[];
  for (var i = 0; i < decoded.length; i++) {
    final entry = decoded[i];
    if (entry is! Map) {
      throw FormatException('Entry ${i + 1} isn\'t an object — expected {"name": "...", ...}.');
    }
    final fields = columnOrder.map((key) {
      final value = entry[key];
      return value == null ? '' : value.toString();
    }).toList();
    rows.add(CsvRow(rowNumber: i + 2, fields: fields));
  }
  return rows;
}
