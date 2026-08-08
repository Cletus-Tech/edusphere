import 'package:flutter/material.dart';
import '../../core/enums/learning_material_type.dart';
import '../../models/course_model.dart';
import '../../models/learning_material_model.dart';
import '../../repositories/learning_material_repository.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../learn/learning_materials/learning_library_screen.dart';
import '../learn/learning_materials/material_detail_screen.dart';
import '../learn/learning_materials/widgets/material_card.dart';

/// Stage 4.4 Part 4 — the Course page. Deliberately does **not** stand
/// up a second content system: every material shown here comes from the
/// same [LearningMaterialRepository] and [LearningMaterialModel] Stage
/// 3.5 already built, scoped with the `courseId` filter
/// [LearningMaterialRepository.watchMaterials] already supported before
/// this stage. "See all in Learn" pushes the exact same
/// [LearningLibraryScreen] the Learn tab uses, just pre-scoped to this
/// course via its existing `courseId` constructor parameter.
///
/// The brief's section list — Notes, Videos, Assignments, Timetable,
/// Downloads, Past Questions, Practice Questions, Flashcards — doesn't
/// map cleanly onto [LearningMaterialType] alone (Notes/Videos/
/// Downloads do; Assignments/Timetable/Past Questions/Practice
/// Questions/Flashcards don't have their own file type). Rather than
/// inventing five new enum values or a second taxonomy, this reuses
/// [LearningMaterialModel.tags] — already a first-class field — so an
/// admin tags a material `assignment`, `timetable`, `past-questions`,
/// `practice-questions`, or `flashcards` from the existing Material
/// Editor and it surfaces under the matching section here. This is a
/// real limitation worth knowing about: those five sections stay empty
/// until materials are tagged accordingly — documented in this stage's
/// changelog rather than silently assumed to work.
class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  final CourseSection? initialSection;
  const CourseDetailScreen({super.key, required this.course, this.initialSection});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

/// Public (Stage 4.5) — was private to this file until the WAEC module
/// needed to deep-link a dashboard tile (e.g. "Video Lessons") straight
/// into one section via [CourseDetailScreen.initialSection], rather
/// than opening on "All" and asking the student to tap a chip. Renamed
/// rather than duplicated: [SubjectBrowseScreen] and the WAEC dashboard
/// reuse this exact enum instead of inventing a parallel one for
/// subjects, since a "Subject" *is* a [CourseModel] (see
/// `SubjectRepository`'s doc comment).
enum CourseSection {
  notes('Notes', tag: null, type: LearningMaterialType.pdf),
  videos('Videos', tag: null, type: LearningMaterialType.video),
  assignments('Assignments', tag: 'assignment'),
  timetable('Timetable', tag: 'timetable'),
  downloads('Downloads', tag: null, type: null, fileBasedOnly: true),
  pastQuestions('Past Questions', tag: 'past-questions'),
  practiceQuestions('Practice Questions', tag: 'practice-questions'),
  flashcards('Flashcards', tag: 'flashcards'),
  // Stage 4.5 — WAEC (and future NECO/JAMB) subjects need a Syllabus
  // section; University courses can use it too since it's just another
  // tag, not a University-vs-WAEC-specific field.
  syllabus('Syllabus', tag: 'syllabus'),
  // Stage 4.7 — JAMB's "Recommended Materials" tile. Same tag-based
  // approach as syllabus above: an admin tags a material 'recommended'
  // from the existing Material Editor. Not JAMB-specific — available to
  // University/WAEC/NECO too, same as every other section here.
  recommended('Recommended', tag: 'recommended');

  final String label;
  final String? tag;
  final LearningMaterialType? type;
  final bool fileBasedOnly;

  const CourseSection(this.label, {this.tag, this.type, this.fileBasedOnly = false});
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final LearningMaterialRepository _repository = LearningMaterialRepository();
  late final Stream<List<LearningMaterialModel>> _materialsStream;
  CourseSection? _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _materialsStream = _repository.watchMaterials(courseId: widget.course.courseId, limit: 100);
  }

  List<LearningMaterialModel> _filter(List<LearningMaterialModel> all, CourseSection? section) {
    if (section == null) return all;
    if (section.fileBasedOnly) return all.where((m) => m.type.isFileBased).toList();
    if (section.type != null) return all.where((m) => m.type == section.type).toList();
    if (section.tag != null) return all.where((m) => m.tags.contains(section.tag)).toList();
    return all;
  }

  void _openMaterial(LearningMaterialModel material) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: material)));
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course.code.isNotEmpty)
                    Text(course.code, style: AppTextStyles.bodySmall(AppColors.primaryBlue).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    style: AppTextStyles.headlineLarge(
                      Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary,
                    ),
                  ),
                  if (course.description != null && course.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        course.description!,
                        style: AppTextStyles.bodyMedium(
                          Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: 'All',
                      selected: _section == null,
                      onTap: () => setState(() => _section = null),
                    ),
                  ),
                  ...CourseSection.values.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppChip(
                        label: s.label,
                        selected: _section == s,
                        onTap: () => setState(() => _section = _section == s ? null : s),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LearningLibraryScreen(courseId: course.courseId)),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search all materials'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<LearningMaterialModel>>(
                stream: _materialsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snapshot.hasError) return const ErrorView(message: 'Could not load course materials right now.');
                  final materials = _filter(snapshot.data ?? const [], _section);
                  if (materials.isEmpty) {
                    return EmptyView(
                      message: _section == null
                          ? 'No materials have been added to this course yet.'
                          : 'Nothing tagged "${_section!.label}" for this course yet.',
                      icon: Icons.folder_open_rounded,
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: materials.length,
                    itemBuilder: (context, index) => MaterialCard(
                      material: materials[index],
                      onTap: () => _openMaterial(materials[index]),
                    ),
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
