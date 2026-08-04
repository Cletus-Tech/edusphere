import 'package:flutter/material.dart';
import '../../core/enums/institution_type.dart';
import '../../core/enums/user_role.dart';
import '../../core/utils/result.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../repositories/institution_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Lets a signed-in user set/edit their place in the academic hierarchy
/// — Stage 4.3, Part 3 ("editable later from the profile"). Reuses the
/// same repositories the admin Academic Structure screens read from, so
/// a student only ever picks from institutions/faculties/departments/
/// levels/semesters an admin has actually created.
///
/// Selections cascade: changing a higher level clears everything below
/// it locally (and, on save, in Firestore too) so a student can never
/// end up with a Department that doesn't belong to their Institution.
class AcademicProfileScreen extends StatefulWidget {
  const AcademicProfileScreen({super.key});

  @override
  State<AcademicProfileScreen> createState() => _AcademicProfileScreenState();
}

class _AcademicProfileScreenState extends State<AcademicProfileScreen> {
  final UserRepository _userRepository = UserRepository();
  final InstitutionRepository _institutionRepository = InstitutionRepository();
  final FacultyRepository _facultyRepository = FacultyRepository();
  final DepartmentRepository _departmentRepository = DepartmentRepository();
  final LevelRepository _levelRepository = LevelRepository();
  final SemesterRepository _semesterRepository = SemesterRepository();

  UserModel? _user;
  bool _loading = true;
  bool _saving = false;

  InstitutionType? _institutionType;
  String? _institutionId;
  String? _facultyId;
  String? _departmentId;
  String? _levelId;
  String? _semesterId;
  final _programmeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final result = await _userRepository.getById(uid);
    if (!mounted) return;
    final user = switch (result) {
      Success(data: final data) => data,
      Failure() => null,
    };
    setState(() {
      _user = user;
      _institutionType =
          user?.institutionType != null ? InstitutionType.fromId(user!.institutionType!) : null;
      _institutionId = user?.institutionId;
      _facultyId = user?.facultyId;
      _departmentId = user?.departmentId;
      _levelId = user?.levelId;
      _semesterId = user?.semesterId;
      _programmeController.text = user?.programme ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _programmeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = _user;
    if (user == null) return;
    setState(() => _saving = true);

    final updated = UserModel(
      uid: user.uid,
      fullName: user.fullName,
      email: user.email,
      photoUrl: user.photoUrl,
      school: user.school,
      course: user.course,
      createdAt: user.createdAt,
      roles: user.roles.isEmpty ? const {UserRole.student} : user.roles,
      institutionId: _institutionId,
      facultyId: _facultyId,
      departmentId: _departmentId,
      levelId: _levelId,
      institutionType: _institutionType?.id,
      semesterId: _semesterId,
      programme: _programmeController.text.trim().isEmpty ? null : _programmeController.text.trim(),
      preferences: user.preferences,
      notificationSettings: user.notificationSettings,
      isVerified: user.isVerified,
      isSuspended: user.isSuspended,
      updatedAt: DateTime.now(),
    );

    final result = await _userRepository.save(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        AppSnackbar.success(context, 'Academic profile updated.');
        Navigator.pop(context);
      case Failure(message: final m):
        AppSnackbar.error(context, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Academic Profile')),
      body: _loading
          ? const LoadingView()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'This powers personalized content across EduSphere — Learning Materials, '
                    'exams, and community are all scoped to what you pick here.',
                    style: AppTextStyles.bodySmall(bodyColor),
                  ),
                  const SizedBox(height: 20),

                  Text('Institution Type', style: AppTextStyles.bodySmall(bodyColor)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<InstitutionType>(
                    value: _institutionType,
                    isExpanded: true,
                    hint: const Text('Select institution type'),
                    items: InstitutionType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _institutionType = v;
                      _institutionId = null;
                      _facultyId = null;
                      _departmentId = null;
                      _levelId = null;
                      _semesterId = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (_institutionType != null) ...[
                    Text('Institution', style: AppTextStyles.bodySmall(bodyColor)),
                    const SizedBox(height: 6),
                    StreamBuilder<List<InstitutionModel>>(
                      stream: _institutionRepository.watchActive(typeId: _institutionType!.id),
                      builder: (context, snapshot) {
                        final institutions = snapshot.data ?? const <InstitutionModel>[];
                        final validValue =
                            institutions.any((i) => i.institutionId == _institutionId) ? _institutionId : null;
                        return DropdownButtonFormField<String>(
                          value: validValue,
                          isExpanded: true,
                          hint: const Text('Select institution'),
                          items: institutions
                              .map((i) => DropdownMenuItem(value: i.institutionId, child: Text(i.name)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _institutionId = v;
                            _facultyId = null;
                            _departmentId = null;
                            _levelId = null;
                            _semesterId = null;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_institutionId != null) ...[
                    Text('Faculty / College', style: AppTextStyles.bodySmall(bodyColor)),
                    const SizedBox(height: 6),
                    StreamBuilder<List<AcademicNodeModel>>(
                      stream: _facultyRepository.watchByInstitution(_institutionId!),
                      builder: (context, snapshot) {
                        final faculties = snapshot.data ?? const <AcademicNodeModel>[];
                        final validValue = faculties.any((f) => f.nodeId == _facultyId) ? _facultyId : null;
                        return DropdownButtonFormField<String>(
                          value: validValue,
                          isExpanded: true,
                          hint: const Text('Select faculty/college'),
                          items: faculties
                              .map((f) => DropdownMenuItem(value: f.nodeId, child: Text(f.name)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _facultyId = v;
                            _departmentId = null;
                            _levelId = null;
                            _semesterId = null;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_facultyId != null) ...[
                    Text('Department', style: AppTextStyles.bodySmall(bodyColor)),
                    const SizedBox(height: 6),
                    StreamBuilder<List<AcademicNodeModel>>(
                      stream: _departmentRepository.watchByFaculty(_facultyId!),
                      builder: (context, snapshot) {
                        final departments = snapshot.data ?? const <AcademicNodeModel>[];
                        final validValue =
                            departments.any((d) => d.nodeId == _departmentId) ? _departmentId : null;
                        return DropdownButtonFormField<String>(
                          value: validValue,
                          isExpanded: true,
                          hint: const Text('Select department'),
                          items: departments
                              .map((d) => DropdownMenuItem(value: d.nodeId, child: Text(d.name)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _departmentId = v;
                            _levelId = null;
                            _semesterId = null;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_departmentId != null) ...[
                    Text('Level', style: AppTextStyles.bodySmall(bodyColor)),
                    const SizedBox(height: 6),
                    StreamBuilder<List<AcademicNodeModel>>(
                      stream: _levelRepository.watchByDepartment(_departmentId!),
                      builder: (context, snapshot) {
                        final levels = snapshot.data ?? const <AcademicNodeModel>[];
                        final validValue = levels.any((l) => l.nodeId == _levelId) ? _levelId : null;
                        return DropdownButtonFormField<String>(
                          value: validValue,
                          isExpanded: true,
                          hint: const Text('Select level'),
                          items:
                              levels.map((l) => DropdownMenuItem(value: l.nodeId, child: Text(l.name))).toList(),
                          onChanged: (v) => setState(() {
                            _levelId = v;
                            _semesterId = null;
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_levelId != null) ...[
                    Text('Semester', style: AppTextStyles.bodySmall(bodyColor)),
                    const SizedBox(height: 6),
                    StreamBuilder<List<AcademicNodeModel>>(
                      stream: _semesterRepository.watchByLevel(_levelId!),
                      builder: (context, snapshot) {
                        final semesters = snapshot.data ?? const <AcademicNodeModel>[];
                        final validValue =
                            semesters.any((s) => s.nodeId == _semesterId) ? _semesterId : null;
                        return DropdownButtonFormField<String>(
                          value: validValue,
                          isExpanded: true,
                          hint: const Text('Select semester'),
                          items: semesters
                              .map((s) => DropdownMenuItem(value: s.nodeId, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _semesterId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text('Programme (optional)', style: AppTextStyles.bodySmall(bodyColor)),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: _programmeController,
                    hintText: 'e.g. B.Eng, HND, ND',
                  ),
                  const SizedBox(height: 28),

                  PrimaryButton(
                    label: 'Save',
                    isLoading: _saving,
                    onPressed: _saving || _user == null ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}
