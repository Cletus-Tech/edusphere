import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/result.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Create/edit screen for one [CreatorProjectModel]. Follows the same
/// create-then-attach ordering `MaterialEditorScreen` uses: a new
/// project is saved as soon as a title exists (`_ensureSaved`) so its
/// id is available for `StoragePaths.creatorProjectImage`, then the
/// image upload reuses that saved id.
class CreatorProjectEditorScreen extends StatefulWidget {
  final CreatorProjectModel? existing;
  const CreatorProjectEditorScreen({super.key, this.existing});

  @override
  State<CreatorProjectEditorScreen> createState() => _CreatorProjectEditorScreenState();
}

class _CreatorProjectEditorScreenState extends State<CreatorProjectEditorScreen> {
  final CreatorProjectRepository _repository = CreatorProjectRepository();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _technologiesController;
  late final TextEditingController _websiteLinkController;
  late final TextEditingController _repoLinkController;

  CreatorProjectModel? _saved;
  bool _saving = false;
  bool _uploadingImage = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _saved = e;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _technologiesController = TextEditingController(text: e?.technologies.join(', ') ?? '');
    _websiteLinkController = TextEditingController(text: e?.links['website'] ?? '');
    _repoLinkController = TextEditingController(text: e?.links['repository'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _technologiesController.dispose();
    _websiteLinkController.dispose();
    _repoLinkController.dispose();
    super.dispose();
  }

  List<String> get _technologies =>
      _technologiesController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  Map<String, String> get _links => {
        if (_websiteLinkController.text.trim().isNotEmpty) 'website': _websiteLinkController.text.trim(),
        if (_repoLinkController.text.trim().isNotEmpty) 'repository': _repoLinkController.text.trim(),
      };

  Future<CreatorProjectModel?> _ensureSaved() async {
    if (_titleController.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Give this project a title first.');
      return null;
    }
    final base = _saved ?? CreatorProjectModel(projectId: _repository.newId(), title: '');
    final updated = base.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      technologies: _technologies,
      links: _links,
    );
    final result = _saved != null ? await _repository.updateProject(base, updated) : await _repository.createProject(updated);
    if (result case Failure(message: final m)) {
      if (mounted) AppSnackbar.error(context, m);
      return null;
    }
    setState(() => _saved = updated);
    return updated;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await _ensureSaved();
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      AppSnackbar.success(context, _isEditing ? 'Project updated.' : 'Project saved.');
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final project = await _ensureSaved();
    if (project == null) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked?.files.single.path == null) return;
    final file = File(picked!.files.single.path!);

    setState(() => _uploadingImage = true);
    final result = await _repository.uploadProjectImage(project.projectId, file, previousUrl: project.imageUrl);
    if (!mounted) return;
    setState(() => _uploadingImage = false);
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    final url = (result as Success<String>).data;
    final updated = project.copyWith(imageUrl: url);
    await _repository.updateProject(project, updated);
    if (!mounted) return;
    setState(() => _saved = updated);
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Project' : 'New Project')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Project Image', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: AppColors.primaryBlue.withOpacity(0.08),
                child: _saved?.imageUrl.isNotEmpty == true
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(_saved!.imageUrl, fit: BoxFit.cover),
                          if (_uploadingImage)
                            Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(color: Colors.white),
                            ),
                        ],
                      )
                    : Center(
                        child: _uploadingImage
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.image_outlined, size: 40, color: AppColors.primaryBlue),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: _saved?.imageUrl.isNotEmpty == true ? 'Replace Image' : 'Add Image',
            icon: Icons.upload_rounded,
            onPressed: _uploadingImage ? null : _pickAndUploadImage,
          ),
          const SizedBox(height: 20),
          Text('Details', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _titleController, hintText: 'Project name'),
          const SizedBox(height: 12),
          AppTextField(controller: _descriptionController, hintText: 'Description', maxLines: 4),
          const SizedBox(height: 12),
          AppTextField(controller: _technologiesController, hintText: 'Technologies, comma separated'),
          const SizedBox(height: 20),
          Text('Links', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(
            controller: _websiteLinkController,
            hintText: 'Website link',
            prefixIcon: Icons.language_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _repoLinkController,
            hintText: 'Repository link',
            prefixIcon: Icons.code_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: _isEditing ? 'Save Changes' : 'Save Project', isLoading: _saving, onPressed: _save),
          const SizedBox(height: 8),
          Text(
            'Publishing is controlled from the Projects list.',
            style: AppTextStyles.bodySmall(bodyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
