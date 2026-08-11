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

/// Profile Information (§1) — name, title, introduction, and the
/// profile picture / cover image, each independently upload / replace /
/// remove. Image changes save immediately (so a slow text edit below
/// can't lose an upload); text fields save together via "Save Changes".
class CreatorProfileInfoEditorScreen extends StatefulWidget {
  final CreatorProfileModel profile;
  const CreatorProfileInfoEditorScreen({super.key, required this.profile});

  @override
  State<CreatorProfileInfoEditorScreen> createState() => _CreatorProfileInfoEditorScreenState();
}

class _CreatorProfileInfoEditorScreenState extends State<CreatorProfileInfoEditorScreen> {
  final CreatorProfileRepository _repository = CreatorProfileRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _introController;

  late CreatorProfileModel _current;
  bool _saving = false;
  bool _uploadingProfile = false;
  bool _uploadingCover = false;

  @override
  void initState() {
    super.initState();
    _current = widget.profile;
    _nameController = TextEditingController(text: _current.name);
    _titleController = TextEditingController(text: _current.title);
    _introController = TextEditingController(text: _current.introduction);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _saveText() async {
    setState(() => _saving = true);
    final updated = _current.copyWith(
      name: _nameController.text.trim(),
      title: _titleController.text.trim(),
      introduction: _introController.text.trim(),
    );
    try {
      await _repository.save(updated, previous: _current);
      if (!mounted) return;
      setState(() {
        _current = updated;
        _saving = false;
      });
      AppSnackbar.success(context, 'Profile information updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Could not save changes. Please try again.');
    }
  }

  Future<void> _pickAndUpload({required bool cover}) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked?.files.single.path == null) return;
    final file = File(picked!.files.single.path!);

    setState(() => cover ? _uploadingCover = true : _uploadingProfile = true);
    final result = cover
        ? await _repository.uploadCoverImage(file, current: _current)
        : await _repository.uploadProfileImage(file, current: _current);
    if (!mounted) return;
    setState(() => cover ? _uploadingCover = false : _uploadingProfile = false);

    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m.isEmpty ? 'Upload failed. Please check your connection and try again.' : m);
      return;
    }
    final url = (result as Success<String>).data;
    setState(() {
      _current = cover ? _current.copyWith(coverImageUrl: url) : _current.copyWith(profileImageUrl: url);
    });
    AppSnackbar.success(context, cover ? 'Cover image updated.' : 'Profile picture updated.');
  }

  Future<void> _remove({required bool cover}) async {
    setState(() => cover ? _uploadingCover = true : _uploadingProfile = true);
    final result = cover ? await _repository.removeCoverImage(_current) : await _repository.removeProfileImage(_current);
    if (!mounted) return;
    setState(() => cover ? _uploadingCover = false : _uploadingProfile = false);
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not remove the image.');
      return;
    }
    setState(() {
      _current = cover ? _current.copyWith(coverImageUrl: '') : _current.copyWith(profileImageUrl: '');
    });
    AppSnackbar.success(context, cover ? 'Cover image removed.' : 'Profile picture removed.');
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Information')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Cover Image', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          _ImagePickerCard(
            imageUrl: _current.coverImageUrl,
            uploading: _uploadingCover,
            aspectRatio: 16 / 6,
            emptyIcon: Icons.panorama_outlined,
            onPick: () => _pickAndUpload(cover: true),
            onRemove: _current.coverImageUrl.isEmpty ? null : () => _remove(cover: true),
          ),
          const SizedBox(height: 24),
          Text('Profile Picture', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          Center(
            child: _ImagePickerCard(
              imageUrl: _current.profileImageUrl,
              uploading: _uploadingProfile,
              circular: true,
              emptyIcon: Icons.person_outline_rounded,
              onPick: () => _pickAndUpload(cover: false),
              onRemove: _current.profileImageUrl.isEmpty ? null : () => _remove(cover: false),
            ),
          ),
          const SizedBox(height: 24),
          Text('Details', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _nameController, hintText: 'Full name', prefixIcon: Icons.badge_outlined),
          const SizedBox(height: 12),
          AppTextField(controller: _titleController, hintText: 'Professional title', prefixIcon: Icons.work_outline_rounded),
          const SizedBox(height: 12),
          AppTextField(controller: _introController, hintText: 'Short introduction', maxLines: 3),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save Changes', isLoading: _saving, onPressed: _saveText),
          const SizedBox(height: 8),
          Text(
            'Image changes save immediately. Text fields save when you tap "Save Changes".',
            style: AppTextStyles.bodySmall(bodyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final String imageUrl;
  final bool uploading;
  final bool circular;
  final double aspectRatio;
  final IconData emptyIcon;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const _ImagePickerCard({
    required this.imageUrl,
    required this.uploading,
    this.circular = false,
    this.aspectRatio = 1,
    required this.emptyIcon,
    required this.onPick,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.08),
        borderRadius: circular ? null : BorderRadius.circular(14),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
      ),
      alignment: Alignment.center,
      child: uploading
          ? const CircularProgressIndicator(strokeWidth: 2.4)
          : Icon(emptyIcon, size: 40, color: AppColors.primaryBlue),
    );

    final image = imageUrl.isEmpty
        ? placeholder
        : ClipRRect(
            borderRadius: circular ? BorderRadius.circular(999) : BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(imageUrl, fit: BoxFit.cover),
                if (uploading)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                  ),
              ],
            ),
          );

    final sized = circular ? SizedBox(width: 120, height: 120, child: image) : AspectRatio(aspectRatio: aspectRatio, child: image);

    return Column(
      children: [
        sized,
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SecondaryButton(
              label: imageUrl.isEmpty ? 'Upload' : 'Replace',
              icon: Icons.upload_rounded,
              onPressed: uploading ? null : onPick,
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 10),
              SecondaryButton(label: 'Remove', icon: Icons.delete_outline_rounded, onPressed: uploading ? null : onRemove),
            ],
          ],
        ),
      ],
    );
  }
}
