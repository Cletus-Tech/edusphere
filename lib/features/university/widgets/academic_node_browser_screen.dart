import 'package:flutter/material.dart';
import '../../../models/institution_model.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Stage 4.4 — one generic, read-only list screen for browsing any
/// single level of the academic tree (Faculties, Departments, Levels,
/// or Semesters). [AcademicStructureScreen] (admin, Stage 4.3) already
/// proved the "one screen handles all four levels" pattern for CRUD;
/// this is the same idea for students, who only ever *view* a node and
/// tap into the next level down via [onNodeTap] — never edit.
///
/// Keeping this as one shared widget (rather than a Faculties screen, a
/// Departments screen, a Levels screen, and a Semesters screen) is what
/// keeps the drill-down chain in [InstitutionDetailScreen] from
/// duplicating four nearly-identical list views.
class AcademicNodeBrowserScreen extends StatelessWidget {
  final String title;
  final Stream<List<AcademicNodeModel>> nodesStream;
  final void Function(BuildContext context, AcademicNodeModel node) onNodeTap;
  final String emptyMessage;

  const AcademicNodeBrowserScreen({
    super.key,
    required this.title,
    required this.nodesStream,
    required this.onNodeTap,
    this.emptyMessage = 'Nothing here yet — check back soon.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: StreamBuilder<List<AcademicNodeModel>>(
          stream: nodesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(message: 'Could not load $title right now.');
            }
            final nodes = List<AcademicNodeModel>.from(snapshot.data ?? const [])
              ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
            if (nodes.isEmpty) {
              return EmptyView(message: emptyMessage, icon: Icons.account_tree_outlined);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: nodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final node = nodes[index];
                return Material(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onNodeTap(context, node),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.name,
                                  style: AppTextStyles.bodyLarge(
                                    Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (node.code != null && node.code!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(node.code!, style: AppTextStyles.bodySmall(AppColors.textSecondary)),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
    );
  }
}
