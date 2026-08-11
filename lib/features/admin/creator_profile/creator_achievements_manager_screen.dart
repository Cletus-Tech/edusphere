import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/result.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Achievements Management (§4) — same add/edit/delete/reorder/enable-
/// disable pattern as [CreatorSkillsManagerScreen], with the extra
/// title/description/category/date fields [CreatorAchievementModel]
/// already defines (Part 1) — no model changes needed here.
class CreatorAchievementsManagerScreen extends StatefulWidget {
  const CreatorAchievementsManagerScreen({super.key});

  @override
  State<CreatorAchievementsManagerScreen> createState() => _CreatorAchievementsManagerScreenState();
}

class _CreatorAchievementsManagerScreenState extends State<CreatorAchievementsManagerScreen> {
  final CreatorAchievementRepository _repository = CreatorAchievementRepository();

  Future<void> _addOrEdit({CreatorAchievementModel? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? '');
    DateTime? date = existing?.date;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
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
              Text(existing == null ? 'Add Achievement' : 'Edit Achievement', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
              const SizedBox(height: 16),
              AppTextField(controller: titleController, hintText: 'Title'),
              const SizedBox(height: 12),
              AppTextField(controller: descriptionController, hintText: 'Description', maxLines: 3),
              const SizedBox(height: 12),
              AppTextField(controller: categoryController, hintText: 'Category (e.g. Certification, Award)'),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(date == null ? 'Pick a date (optional)' : FormatUtils.dateTime(date!)),
              ),
              const SizedBox(height: 12),
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
      ),
    );

    if (saved != true || !mounted) return;
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final category = categoryController.text.trim();

    final result = existing == null
        ? await _repository.createAchievement(CreatorAchievementModel(
            achievementId: _repository.newId(),
            title: title,
            description: description,
            category: category.isEmpty ? null : category,
            date: date,
          ))
        : await _repository.updateAchievement(
            existing,
            existing.copyWith(
              title: title,
              description: description,
              category: category.isEmpty ? null : category,
              clearCategory: category.isEmpty,
              date: date,
              clearDate: date == null,
            ),
          );
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
    } else {
      AppSnackbar.success(context, existing == null ? 'Achievement added.' : 'Achievement updated.');
    }
  }

  Future<void> _delete(CreatorAchievementModel achievement) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete "${achievement.title}"?',
      message: 'This will remove it from the public profile.',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final result = await _repository.deleteAchievement(achievement);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  Future<void> _togglePublished(CreatorAchievementModel achievement) async {
    final result = await _repository.setPublished(achievement, !achievement.isPublished);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Achievement'),
      ),
      body: StreamBuilder<List<CreatorAchievementModel>>(
        stream: _repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return const EmptyView(message: 'No achievements yet. Tap "Add Achievement" to add one.');

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              final reordered = List<CreatorAchievementModel>.from(items);
              if (newIndex > oldIndex) newIndex -= 1;
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              _repository.reorder(reordered);
            },
            itemBuilder: (context, index) {
              final achievement = items[index];
              final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
              final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
              return Opacity(
                key: ValueKey(achievement.achievementId),
                opacity: achievement.isPublished ? 1 : 0.5,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events_outlined, color: AppColors.highlightOrange),
                    title: Text(achievement.title, style: AppTextStyles.bodyLarge(textColor)),
                    subtitle: Text(
                      [
                        if (achievement.category != null && achievement.category!.isNotEmpty) achievement.category!,
                        if (achievement.date != null) FormatUtils.dateTime(achievement.date!),
                      ].join(' • '),
                      style: AppTextStyles.bodySmall(bodyColor),
                    ),
                    onTap: () => _addOrEdit(existing: achievement),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: achievement.isPublished, onChanged: (_) => _togglePublished(achievement)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _delete(achievement),
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
