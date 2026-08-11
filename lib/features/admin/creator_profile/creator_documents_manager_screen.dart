import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/result.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Document Management (§6) — CV, certificates, portfolio, awards, and
/// other files. Implements the exact flow the spec lays out: Select
/// File -> Upload -> Show Progress -> Save Metadata -> Publish.
class CreatorDocumentsManagerScreen extends StatefulWidget {
  const CreatorDocumentsManagerScreen({super.key});

  @override
  State<CreatorDocumentsManagerScreen> createState() => _CreatorDocumentsManagerScreenState();
}

class _CreatorDocumentsManagerScreenState extends State<CreatorDocumentsManagerScreen> {
  final CreatorDocumentRepository _repository = CreatorDocumentRepository();
  bool _uploading = false;
  double _uploadProgress = 0;

  Future<void> _uploadNew() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (picked?.files.single.path == null) return;
    final file = File(picked!.files.single.path!);
    final suggestedTitle = picked.files.single.name.split('.').first;

    final titleController = TextEditingController(text: suggestedTitle);
    final descriptionController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Document', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
            const SizedBox(height: 16),
            AppTextField(controller: titleController, hintText: 'Title (e.g. CV, Certificate)'),
            const SizedBox(height: 12),
            AppTextField(controller: descriptionController, hintText: 'Description (optional)', maxLines: 2),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Upload',
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(sheetContext, true);
              },
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    final result = await _repository.uploadDocument(
      file: file,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      onProgress: (progress) {
        if (mounted) setState(() => _uploadProgress = progress);
      },
    );

    if (!mounted) return;
    setState(() => _uploading = false);
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m.isEmpty ? 'Upload failed. Please try again.' : m);
      return;
    }
    AppSnackbar.success(context, 'Document uploaded.');
  }

  Future<void> _replaceFile(CreatorDocumentModel document) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (picked?.files.single.path == null) return;
    final file = File(picked!.files.single.path!);

    setState(() => _uploading = true);
    final result = await _repository.replaceFile(document, file);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AppSnackbar.success(context, 'File replaced.');
  }

  Future<void> _editMetadata(CreatorDocumentModel document) async {
    final titleController = TextEditingController(text: document.title);
    final descriptionController = TextEditingController(text: document.description);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Document', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
            const SizedBox(height: 16),
            AppTextField(controller: titleController, hintText: 'Title'),
            const SizedBox(height: 12),
            AppTextField(controller: descriptionController, hintText: 'Description', maxLines: 2),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext, false);
                      _replaceFile(document);
                    },
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Replace File'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(sheetContext, true);
              },
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final result = await _repository.updateMetadata(
      document,
      document.copyWith(title: titleController.text.trim(), description: descriptionController.text.trim()),
    );
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  Future<void> _delete(CreatorDocumentModel document) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete "${document.title}"?',
      message: 'This permanently removes the file and its listing from the public profile.',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final result = await _repository.deleteDocument(document);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  Future<void> _togglePublished(CreatorDocumentModel document) async {
    final result = await _repository.setPublished(document, !document.isPublished);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  IconData _iconFor(String title, String path) {
    final ext = path.isNotEmpty ? path.split('.').last.toLowerCase() : '';
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _uploadNew,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload'),
      ),
      body: Column(
        children: [
          if (_uploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress > 0 ? _uploadProgress : null),
                  const SizedBox(height: 6),
                  Text('Uploading...', style: AppTextStyles.bodySmall(AppColors.textSecondary)),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<CreatorDocumentModel>>(
              stream: _repository.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const EmptyView(message: 'No documents yet. Tap "Upload" to add a CV, certificate, or other file.');
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    final reordered = List<CreatorDocumentModel>.from(items);
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    _repository.reorder(reordered);
                  },
                  itemBuilder: (context, index) {
                    final document = items[index];
                    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
                    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
                    return Opacity(
                      key: ValueKey(document.documentId),
                      opacity: document.isPublished ? 1 : 0.5,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(_iconFor(document.title, document.storagePath), color: AppColors.primaryBlue),
                          title: Text(document.title, style: AppTextStyles.bodyLarge(textColor)),
                          subtitle: Text(
                            document.description.isEmpty ? 'No description' : document.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall(bodyColor),
                          ),
                          onTap: () => _editMetadata(document),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(value: document.isPublished, onChanged: (_) => _togglePublished(document)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => _delete(document),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
