import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../repositories/course_repository.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../university/course_detail_screen.dart';

/// Stage 4.5 — deliberately generic, not `WaecSubjectBrowseScreen`.
/// [SubjectRepository.watchByCategory] already took a plain
/// `categoryId` string (Stage 1.2), so nothing about "subjects" is
/// WAEC-specific — this screen just needed to exist. The WAEC dashboard
/// is the first caller (`categoryId: 'waec'`); Stage 4.6 (NECO) and any
/// future JAMB stage should reuse this exact file with
/// `categoryId: 'neco'` / `'jamb'` rather than copying it.
///
/// Tapping a subject opens [CourseDetailScreen] directly — a subject
/// *is* a [CourseModel] under a different collection
/// (`SubjectRepository` reuses the same model, see its doc comment in
/// `course_repository.dart`), so its Notes/Videos/Practice
/// Questions/Past Questions/Downloads/Flashcards/Syllabus sections are
/// the exact same Learning Materials system University courses use —
/// no second content-delivery screen was built for subjects.
class SubjectBrowseScreen extends StatefulWidget {
  final String categoryId;
  final String categoryLabel;
  final CourseSection? initialSection;

  const SubjectBrowseScreen({
    super.key,
    required this.categoryId,
    required this.categoryLabel,
    this.initialSection,
  });

  @override
  State<SubjectBrowseScreen> createState() => _SubjectBrowseScreenState();
}

class _SubjectBrowseScreenState extends State<SubjectBrowseScreen> {
  final SubjectRepository _repository = SubjectRepository();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.categoryLabel} Subjects')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SearchField(
                controller: _searchController,
                hintText: 'Search ${widget.categoryLabel} subjects...',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CourseModel>>(
                stream: _repository.watchByCategory(widget.categoryId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snapshot.hasError) return const ErrorView(message: 'Could not load subjects right now.');
                  var subjects = snapshot.data ?? const <CourseModel>[];
                  if (_query.isNotEmpty) {
                    subjects = subjects
                        .where((s) => s.title.toLowerCase().contains(_query) || s.code.toLowerCase().contains(_query))
                        .toList();
                  }
                  if (subjects.isEmpty) {
                    return EmptyView(
                      message: _query.isEmpty
                          ? 'No ${widget.categoryLabel} subjects have been added yet.'
                          : 'No subjects match "$_query".',
                      icon: Icons.menu_book_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return Material(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseDetailScreen(
                                course: subject,
                                initialSection: widget.initialSection,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.menu_book_rounded, color: AppColors.accentGreen, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject.title,
                                        style: AppTextStyles.bodyLarge(
                                          Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (subject.code.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(subject.code, style: AppTextStyles.bodySmall(AppColors.textSecondary)),
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
          ],
        ),
      ),
    );
  }
}
