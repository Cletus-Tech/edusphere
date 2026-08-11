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

/// Skills Management (§3) — add / edit / delete / reorder / enable-
/// disable. Drag-to-reorder via [ReorderableListView]; disabled skills
/// stay visible here (dimmed) but are filtered out of the public page
/// by [CreatorProfileScreen] — see that screen's comment.
class CreatorSkillsManagerScreen extends StatefulWidget {
  const CreatorSkillsManagerScreen({super.key});

  @override
  State<CreatorSkillsManagerScreen> createState() => _CreatorSkillsManagerScreenState();
}

class _CreatorSkillsManagerScreenState extends State<CreatorSkillsManagerScreen> {
  final CreatorSkillRepository _repository = CreatorSkillRepository();

  Future<void> _addOrEdit({CreatorSkillModel? existing}) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? '');

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
            Text(existing == null ? 'Add Skill' : 'Edit Skill', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
            const SizedBox(height: 16),
            AppTextField(controller: labelController, hintText: 'Skill (e.g. Flutter, UI/UX Design)'),
            const SizedBox(height: 12),
            AppTextField(controller: categoryController, hintText: 'Category (optional)'),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                if (labelController.text.trim().isEmpty) return;
                Navigator.pop(sheetContext, true);
              },
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final label = labelController.text.trim();
    final category = categoryController.text.trim();

    final result = existing == null
        ? await _repository.createSkill(CreatorSkillModel(skillId: _repository.newId(), label: label, category: category.isEmpty ? null : category))
        : await _repository.updateSkill(
            existing,
            existing.copyWith(label: label, category: category.isEmpty ? null : category, clearCategory: category.isEmpty),
          );
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
    } else {
      AppSnackbar.success(context, existing == null ? 'Skill added.' : 'Skill updated.');
    }
  }

  Future<void> _delete(CreatorSkillModel skill) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete "${skill.label}"?',
      message: 'This will remove it from the public profile.',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final result = await _repository.deleteSkill(skill);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  Future<void> _togglePublished(CreatorSkillModel skill) async {
    final result = await _repository.setPublished(skill, !skill.isPublished);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Skill'),
      ),
      body: StreamBuilder<List<CreatorSkillModel>>(
        stream: _repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
          final skills = snapshot.data ?? const [];
          if (skills.isEmpty) return const EmptyView(message: 'No skills yet. Tap "Add Skill" to add one.');

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: skills.length,
            onReorder: (oldIndex, newIndex) {
              final reordered = List<CreatorSkillModel>.from(skills);
              if (newIndex > oldIndex) newIndex -= 1;
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              _repository.reorder(reordered);
            },
            itemBuilder: (context, index) {
              final skill = skills[index];
              final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
              final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
              return Opacity(
                key: ValueKey(skill.skillId),
                opacity: skill.isPublished ? 1 : 0.5,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.drag_indicator_rounded),
                    title: Text(skill.label, style: AppTextStyles.bodyLarge(textColor)),
                    subtitle: skill.category != null && skill.category!.isNotEmpty
                        ? Text(skill.category!, style: AppTextStyles.bodySmall(bodyColor))
                        : null,
                    onTap: () => _addOrEdit(existing: skill),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: skill.isPublished, onChanged: (_) => _togglePublished(skill)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _delete(skill),
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
    );
  }
}
