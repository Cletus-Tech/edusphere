import 'package:flutter/material.dart';
import '../../../core/utils/result.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'creator_project_editor_screen.dart';

/// Project Management (§5) — list view; the actual add/edit form
/// (title, description, image, technologies, links) lives in
/// [CreatorProjectEditorScreen] since it has an image upload and needs
/// more room than a bottom sheet, matching [MaterialEditorScreen]'s
/// full-screen-editor pattern rather than the compact sheet used for
/// skills/achievements.
class CreatorProjectsManagerScreen extends StatefulWidget {
  const CreatorProjectsManagerScreen({super.key});

  @override
  State<CreatorProjectsManagerScreen> createState() => _CreatorProjectsManagerScreenState();
}

class _CreatorProjectsManagerScreenState extends State<CreatorProjectsManagerScreen> {
  final CreatorProjectRepository _repository = CreatorProjectRepository();

  Future<void> _delete(CreatorProjectModel project) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete "${project.title}"?',
      message: 'This will remove it from the public profile.',
      isDestructive: true,
    );
    if (confirmed != true) return;
    final result = await _repository.deleteProject(project);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  Future<void> _togglePublished(CreatorProjectModel project) async {
    final result = await _repository.setPublished(project, !project.isPublished);
    if (!mounted) return;
    if (result case Failure(message: final m)) AppSnackbar.error(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatorProjectEditorScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Project'),
      ),
      body: StreamBuilder<List<CreatorProjectModel>>(
        stream: _repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return const EmptyView(message: 'No projects yet. Tap "Add Project" to add one.');

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              final reordered = List<CreatorProjectModel>.from(items);
              if (newIndex > oldIndex) newIndex -= 1;
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              _repository.reorder(reordered);
            },
            itemBuilder: (context, index) {
              final project = items[index];
              final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
              final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
              return Opacity(
                key: ValueKey(project.projectId),
                opacity: project.isPublished ? 1 : 0.5,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: project.imageUrl.isEmpty
                        ? const CircleAvatar(child: Icon(Icons.work_outline_rounded))
                        : CircleAvatar(backgroundImage: NetworkImage(project.imageUrl)),
                    title: Text(project.title, style: AppTextStyles.bodyLarge(textColor)),
                    subtitle: Text(
                      project.technologies.isEmpty ? 'No technologies listed' : project.technologies.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall(bodyColor),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreatorProjectEditorScreen(existing: project)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(value: project.isPublished, onChanged: (_) => _togglePublished(project)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _delete(project),
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
