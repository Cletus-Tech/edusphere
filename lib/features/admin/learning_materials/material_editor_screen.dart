import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/enums/learning_material_type.dart';
import '../../../core/enums/material_publication_status.dart';
import '../../../core/enums/upload_status.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/result.dart';
import '../../../models/course_model.dart';
import '../../../models/learning_material_model.dart';
import '../../../models/upload_task_model.dart';
import '../../../repositories/course_repository.dart';
import '../../../repositories/learning_material_repository.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/upload/upload_engine.dart';
import '../../../shared/components/app_bottom_sheet.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Create/edit screen for one [LearningMaterialModel] — Stage 3.5 Part 5.
///
/// New materials are saved as a draft as soon as a title is entered
/// (`_ensureSaved`), *before* any file/thumbnail/banner can be
/// attached — Storage paths are keyed by `materialId`
/// (`StoragePaths.learningMaterialFile`), so a document has to exist
/// first. This mirrors how every other CMS-style screen in this
/// codebase (e.g. the legacy content editor) handles the
/// create-then-attach ordering.
class MaterialEditorScreen extends StatefulWidget {
  final LearningMaterialModel? existing;
  const MaterialEditorScreen({super.key, this.existing});

  @override
  State<MaterialEditorScreen> createState() => _MaterialEditorScreenState();
}

class _MaterialEditorScreenState extends State<MaterialEditorScreen> {
  final LearningMaterialRepository _repository = LearningMaterialRepository();
  final AuthService _authService = AuthService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _courseController; // shows course title/code, stores id separately
  late final TextEditingController _topicController;
  late final TextEditingController _weekController;
  late final TextEditingController _tagsController;
  late final TextEditingController _externalUrlController;
  late final TextEditingController _richTextController;

  LearningMaterialModel? _saved;
  LearningMaterialType _type = LearningMaterialType.pdf;
  MaterialPublicationStatus _status = MaterialPublicationStatus.draft;
  MaterialVisibility _visibility = MaterialVisibility.everyone;
  DateTime? _scheduledFor;
  String? _courseId;
  bool _saving = false;

  StreamSubscription<List<UploadTaskModel>>? _uploadSub;
  UploadTaskModel? _activeFileTask;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _saved = e;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _courseController = TextEditingController(text: e?.courseId ?? '');
    _topicController = TextEditingController(text: e?.topic ?? '');
    _weekController = TextEditingController(text: e?.week ?? '');
    _tagsController = TextEditingController(text: e?.tags.join(', ') ?? '');
    _externalUrlController = TextEditingController(text: e?.externalUrl ?? '');
    _richTextController = TextEditingController(text: e?.richTextContent ?? '');
    _type = e?.type ?? LearningMaterialType.pdf;
    _status = e?.status ?? MaterialPublicationStatus.draft;
    _visibility = e?.visibility ?? MaterialVisibility.everyone;
    _scheduledFor = e?.scheduledFor;
    _courseId = e?.courseId;
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    for (final c in [
      _titleController,
      _descriptionController,
      _courseController,
      _topicController,
      _weekController,
      _tagsController,
      _externalUrlController,
      _richTextController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _tags =>
      _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  /// Creates the draft document the first time it's needed (file/
  /// thumbnail/banner attach, or explicit Save), then reuses it on
  /// every subsequent save — see class doc comment.
  Future<LearningMaterialModel?> _ensureSaved() async {
    if (_titleController.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Give this material a title first.');
      return null;
    }
    final uid = _authService.currentUser?.uid ?? '';
    final now = DateTime.now();
    final base = _saved ??
        LearningMaterialModel(
          materialId: _repository.newId(),
          title: '',
          type: _type,
          authorId: uid,
          createdAt: now,
          updatedAt: now,
        );
    final updated = base.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _type,
      courseId: _courseId,
      topic: _topicController.text.trim().isEmpty ? null : _topicController.text.trim(),
      week: _weekController.text.trim().isEmpty ? null : _weekController.text.trim(),
      tags: _tags,
      externalUrl: _externalUrlController.text.trim().isEmpty ? null : _externalUrlController.text.trim(),
      richTextContent: _richTextController.text.trim().isEmpty ? null : _richTextController.text.trim(),
      status: _status,
      scheduledFor: _scheduledFor,
      clearScheduledFor: _status != MaterialPublicationStatus.scheduled,
      visibility: _visibility,
    );

    final result = _isEditing || _saved != null
        ? await _repository.updateMaterial(base, updated)
        : await _repository.createMaterial(updated);

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
      AppSnackbar.success(context, _isEditing ? 'Material updated.' : 'Material saved.');
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickCourse() async {
    // Stage 4.5: subjects (WAEC/NECO/JAMB) reuse CourseModel but live in
    // a separate `subjects` collection — merged in here so admins can
    // attach a material to a subject, not only a university course.
    final coursesResult = await CourseRepository().getWhere(query: (q) => q, limit: 50);
    final subjectsResult = await SubjectRepository().getWhere(query: (q) => q, limit: 50);
    if (!mounted) return;
    final courses = switch (coursesResult) {
      Success(data: final data) => data,
      Failure() => const <CourseModel>[],
    };
    final subjects = switch (subjectsResult) {
      Success(data: final data) => data,
      Failure() => const <CourseModel>[],
    };
    final list = [...courses, ...subjects];
    final picked = await AppBottomSheet.show<CourseModel>(
      context,
      child: SizedBox(
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select a Course or Subject', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView(message: 'No courses or subjects found yet.')
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(list[i].title),
                        subtitle: Text(
                          '${list[i].code.isEmpty ? "" : "${list[i].code} — "}'
                          '${i < courses.length ? "Course" : "Subject"}',
                        ),
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _courseId = picked.courseId;
        _courseController.text = '${picked.code} — ${picked.title}';
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    final material = await _ensureSaved();
    if (material == null) return;
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null) return;
    final file = File(picked.files.single.path!);
    final uid = _authService.currentUser?.uid ?? '';

    final result = await _repository.queueFileUpload(material: material, file: file, uid: uid);
    if (result case Failure(message: final m)) {
      if (mounted) AppSnackbar.error(context, m);
      return;
    }
    final task = (result as Success<UploadTaskModel>).data;
    setState(() => _activeFileTask = task);
    _attachedForTaskId = null;

    _uploadSub?.cancel();
    _uploadSub = UploadEngine.instance.watchTasks().listen((tasks) {
      final match = tasks.where((t) => t.taskId == task.taskId);
      if (match.isNotEmpty) _handleUploadUpdate(match.first, material);
    });

    // Race guard: `enqueue()` already returned, and a small/fast file
    // can finish uploading before the listener above attaches —
    // UploadEngine's task stream is `StreamController.broadcast()` with
    // no replay, so that completion event would otherwise be silently
    // dropped and the file would never get attached to the material.
    // `UploadEngine.instance.tasks` is a synchronous snapshot of
    // current state, so checking it right after subscribing closes
    // that window.
    final currentSnapshot = UploadEngine.instance.tasks.where((t) => t.taskId == task.taskId);
    if (currentSnapshot.isNotEmpty) _handleUploadUpdate(currentSnapshot.first, material);
  }

  // Guards against calling `attachFile` twice for the same completed
  // upload — both the stream listener and the immediate race-guard
  // check above can observe the same terminal `success` state.
  String? _attachedForTaskId;

  void _handleUploadUpdate(UploadTaskModel current, LearningMaterialModel material) {
    if (!mounted) return;
    setState(() => _activeFileTask = current);
    if (current.status == UploadStatus.success && _attachedForTaskId != current.taskId) {
      _attachedForTaskId = current.taskId;
      _repository.attachFile(material, current).then((_) {
        if (mounted) {
          setState(() => _saved = material.copyWith(fileUrl: current.downloadUrl, fileName: current.fileName));
        }
      });
    }
  }

  Future<void> _pickAndUploadThumbnail({required bool banner}) async {
    final material = await _ensureSaved();
    if (material == null) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || picked.files.single.path == null) return;
    final file = File(picked.files.single.path!);
    final result = banner ? await _repository.uploadBanner(material, file) : await _repository.uploadThumbnail(material, file);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    final url = (result as Success<String>).data;
    setState(() => _saved = banner ? material.copyWith(bannerUrl: url) : material.copyWith(thumbnailUrl: url));
  }

  Future<void> _pickScheduleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledFor ?? date));
    if (!mounted) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time?.hour ?? 9, time?.minute ?? 0);
      _status = MaterialPublicationStatus.scheduled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Material' : 'New Material')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Basic Information', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(controller: _titleController, hintText: 'Title'),
          const SizedBox(height: 12),
          AppTextField(controller: _descriptionController, hintText: 'Description'),
          const SizedBox(height: 20),
          Text('Content Type', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LearningMaterialType.values
                .map((t) => AppChip(
                      label: t.label,
                      accent: t.color,
                      selected: _type == t,
                      onTap: () => setState(() => _type = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('Academic Structure', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(
            controller: _courseController,
            hintText: 'Course or Subject (optional)',
            prefixIcon: Icons.menu_book_outlined,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _pickCourse,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Browse courses'),
            ),
          ),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _topicController, hintText: 'Topic (optional)')),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: _weekController, hintText: 'Week (optional)')),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _tagsController, hintText: 'Tags, comma separated'),
          const SizedBox(height: 20),
          Text('Content', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (_type == LearningMaterialType.link)
            AppTextField(controller: _externalUrlController, hintText: 'https://...', keyboardType: TextInputType.url)
          else if (_type == LearningMaterialType.richText)
            AppTextField(controller: _richTextController, hintText: 'Write the content here...')
          else
            _FileAttachSection(
              currentFileName: _saved?.fileName,
              currentFileUrl: _saved?.fileUrl,
              activeTask: _activeFileTask,
              onPick: _pickAndUploadFile,
            ),
          const SizedBox(height: 20),
          Text('Thumbnail & Banner', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: _saved?.thumbnailUrl == null ? 'Add Thumbnail' : 'Replace Thumbnail',
                  icon: Icons.image_outlined,
                  onPressed: () => _pickAndUploadThumbnail(banner: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: _saved?.bannerUrl == null ? 'Add Banner' : 'Replace Banner',
                  icon: Icons.panorama_outlined,
                  onPressed: () => _pickAndUploadThumbnail(banner: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Publishing', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MaterialPublicationStatus.values
                .where((s) => s != MaterialPublicationStatus.scheduled)
                .map((s) => AppChip(
                      label: s.label,
                      accent: s.color,
                      selected: _status == s,
                      onTap: () => setState(() {
                        _status = s;
                        _scheduledFor = null;
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickScheduleDate,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(
              _status == MaterialPublicationStatus.scheduled && _scheduledFor != null
                  ? 'Scheduled for ${FormatUtils.dateTime(_scheduledFor!)}'
                  : 'Schedule for later instead',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MaterialVisibility>(
            value: _visibility,
            decoration: const InputDecoration(labelText: 'Visibility'),
            items: MaterialVisibility.values
                .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                .toList(),
            onChanged: (v) => setState(() => _visibility = v ?? _visibility),
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: _isEditing ? 'Save Changes' : 'Save Material', isLoading: _saving, onPressed: _save),
          const SizedBox(height: 8),
          Text(
            'Tags and course help students find this in search and filters.',
            style: AppTextStyles.bodySmall(bodyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FileAttachSection extends StatelessWidget {
  final String? currentFileName;
  final String? currentFileUrl;
  final UploadTaskModel? activeTask;
  final VoidCallback onPick;

  const _FileAttachSection({
    required this.currentFileName,
    required this.currentFileUrl,
    required this.activeTask,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final uploading = activeTask != null && activeTask!.status.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentFileUrl != null && !uploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(currentFileName ?? 'File attached', style: TextStyle(color: bodyColor), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        if (uploading) ...[
          LinearProgressIndicator(value: activeTask!.progress),
          const SizedBox(height: 6),
          Text('Uploading — ${(activeTask!.progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: bodyColor)),
          const SizedBox(height: 10),
        ],
        SecondaryButton(
          label: currentFileUrl == null ? 'Attach File' : 'Replace File',
          icon: Icons.upload_file_rounded,
          onPressed: uploading ? null : onPick,
        ),
      ],
    );
  }
}
