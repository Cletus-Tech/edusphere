import 'package:flutter/material.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Biography (§2) — about me / mission / vision / journey. Free-form
/// multiline text, not truncated to a fixed length, per the spec ("do
/// not limit the content to a tiny fixed string").
class CreatorBiographyEditorScreen extends StatefulWidget {
  final CreatorProfileModel profile;
  const CreatorBiographyEditorScreen({super.key, required this.profile});

  @override
  State<CreatorBiographyEditorScreen> createState() => _CreatorBiographyEditorScreenState();
}

class _CreatorBiographyEditorScreenState extends State<CreatorBiographyEditorScreen> {
  final CreatorProfileRepository _repository = CreatorProfileRepository();
  late final TextEditingController _biographyController;
  late final TextEditingController _missionController;
  late final TextEditingController _visionController;
  late final TextEditingController _journeyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _biographyController = TextEditingController(text: widget.profile.biography);
    _missionController = TextEditingController(text: widget.profile.mission);
    _visionController = TextEditingController(text: widget.profile.vision);
    _journeyController = TextEditingController(text: widget.profile.journey);
  }

  @override
  void dispose() {
    _biographyController.dispose();
    _missionController.dispose();
    _visionController.dispose();
    _journeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.profile.copyWith(
      biography: _biographyController.text.trim(),
      mission: _missionController.text.trim(),
      vision: _visionController.text.trim(),
      journey: _journeyController.text.trim(),
    );
    try {
      await _repository.save(updated, previous: widget.profile);
      if (!mounted) return;
      AppSnackbar.success(context, 'Biography updated.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Could not save changes. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biography')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('About Me', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _biographyController, hintText: 'Tell your story...', maxLines: 8),
          const SizedBox(height: 20),
          Text('Mission', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _missionController, hintText: 'What drives your work...', maxLines: 4),
          const SizedBox(height: 20),
          Text('Vision', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _visionController, hintText: 'Where you\'re headed...', maxLines: 4),
          const SizedBox(height: 20),
          Text('Journey', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _journeyController, hintText: 'How you got here...', maxLines: 6),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save Changes', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
