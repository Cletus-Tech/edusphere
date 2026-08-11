import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/utils/result.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'csv_import_spec.dart';
import 'csv_utils.dart';
import 'import_types.dart';
import 'json_utils.dart';

/// Stage 6.2.1 — Shared CSV Import Framework: the reusable screen.
///
/// Drives steps 1-9 from Stage 6.2.1's brief (file selection, parsing,
/// data conversion, preview, row validation, error reporting, import
/// confirmation, progress tracking, success/failure summary) against
/// whatever [CsvImportSpec] a module provides — step 10 (audit
/// logging) happens through the spec's [CsvImportSpec.logImport],
/// which itself goes through the existing `AuditLogService`.
///
/// This is a direct extraction of `BulkQuestionUploadScreen`'s state
/// machine and UI — same file-pick → parse → preview → confirm →
/// upload-with-progress → summary flow, same widget structure — with
/// every `QuestionModel`-specific piece (parsing rules, save call,
/// preview text, audit call) pulled out into the spec instead.
/// Behavior for the question-import path is unchanged; see
/// `bulk_question_upload_screen.dart`, now a thin wrapper around this.
class CsvImportScreen<T> extends StatefulWidget {
  final CsvImportSpec<T> spec;
  const CsvImportScreen({super.key, required this.spec});

  @override
  State<CsvImportScreen<T>> createState() => _CsvImportScreenState<T>();
}

class _CsvImportScreenState<T> extends State<CsvImportScreen<T>> {
  String? _fileName;
  List<ImportRowResult<T>> _rows = [];
  bool _uploading = false;
  bool _preparing = false;
  int _uploadedCount = 0;

  int get _validCount => _rows.where((r) => r.isValid).length;
  int get _invalidCount => _rows.length - _validCount;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.spec.allowedExtensions,
    );
    if (picked == null || picked.files.single.path == null) return;

    final file = File(picked.files.single.path!);
    final fileName = picked.files.single.name;
    final extension = fileName.split('.').last.toLowerCase();
    final content = await file.readAsString();

    // Stage 6.2.3 — give a spec a chance to pre-fetch lookups (e.g.
    // institution/faculty/department/level name→id maps) before any
    // row is parsed. Without this, a spec like
    // `_AcademicNodeImportSpec` that resolves parents by name inside
    // `parseRow` would have nothing to resolve against.
    final spec = widget.spec;
    if (spec is PreparableImportSpec) {
      setState(() => _preparing = true);
      try {
        await spec.prepare();
      } catch (e) {
        if (!mounted) return;
        setState(() => _preparing = false);
        AppSnackbar.error(context, 'Could not load lookup data: $e');
        return;
      }
      if (!mounted) return;
      setState(() => _preparing = false);
    }

    List<CsvRow> csvRows;
    try {
      csvRows = extension == 'json' ? readJsonRows(content, widget.spec.columnOrder) : readCsvRows(content);
    } on FormatException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not read $fileName: ${e.message}');
      return;
    }

    final parsed = csvRows.map(widget.spec.parseRow).toList();

    setState(() {
      _fileName = fileName;
      _rows = parsed;
    });
  }

  Future<void> _upload() async {
    final toUpload = _rows.where((r) => r.isValid).toList();
    if (toUpload.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadedCount = 0;
    });

    var failed = 0;
    for (final row in toUpload) {
      final result = await widget.spec.save(row.data as T);
      if (!mounted) return;
      switch (result) {
        case Success():
          setState(() => _uploadedCount++);
        case Failure():
          failed++;
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    widget.spec.logImport(_uploadedCount);

    if (!mounted) return;
    if (failed == 0) {
      AppSnackbar.success(context, 'Uploaded $_uploadedCount item${_uploadedCount == 1 ? '' : 's'}.');
      Navigator.pop(context, ImportRunSummary(uploaded: _uploadedCount, failed: failed));
    } else {
      AppSnackbar.error(
        context,
        'Uploaded $_uploadedCount, but $failed failed. Check your connection and try re-uploading the rest.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final headlineColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(widget.spec.screenTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.spec.formatHelpTitle,
                      style: AppTextStyles.bodyLarge(headlineColor).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.spec.formatHelpBody, style: AppTextStyles.bodyMedium(bodyColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _fileName == null ? 'Choose File' : 'Choose a different file',
              onPressed: (_uploading || _preparing) ? null : _pickFile,
            ),
            if (_preparing) ...[
              const SizedBox(height: 12),
              const Center(child: LoadingView()),
            ],
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text(_fileName!, style: AppTextStyles.bodyMedium(bodyColor)),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Preview ($_validCount valid, $_invalidCount with errors)'),
              const SizedBox(height: 8),
              ..._rows.map((row) => _RowPreview<T>(row: row, spec: widget.spec)),
              const SizedBox(height: 20),
              if (_uploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadedCount / _validCount),
                    const SizedBox(height: 8),
                    Text('Uploading $_uploadedCount of $_validCount…', style: AppTextStyles.bodyMedium(bodyColor)),
                  ],
                )
              else
                PrimaryButton(
                  label: _validCount == 0 ? 'No valid items to upload' : 'Upload $_validCount item${_validCount == 1 ? '' : 's'}',
                  onPressed: _validCount == 0 ? null : _upload,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowPreview<T> extends StatelessWidget {
  final ImportRowResult<T> row;
  final CsvImportSpec<T> spec;
  const _RowPreview({required this.row, required this.spec});

  @override
  Widget build(BuildContext context) {
    final ok = row.isValid;
    final textColor = ok
        ? Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary
        : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18,
            color: ok ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok ? spec.describeValid(row.data as T) : 'Row ${row.rowNumber}: ${row.error}',
              style: AppTextStyles.bodyMedium(textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
