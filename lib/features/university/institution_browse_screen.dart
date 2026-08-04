import 'package:flutter/material.dart';
import '../../core/enums/institution_type.dart';
import '../../models/institution_model.dart';
import '../../repositories/institution_repository.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'institution_detail_screen.dart';

/// Stage 4.4 Part 3 — institution search/browse. Scoped to
/// [InstitutionType.university] by default because this stage is
/// explicitly "University comes first" per the brief, not a general
/// tertiary-institution browser — but the [institutionType] parameter
/// exists precisely so Stage 4.5+ (Polytechnic, College of Education)
/// can reuse this exact screen with a different type instead of
/// duplicating it, the same reuse discipline Stage 4.3 used for
/// [AcademicNodeManagerScreen].
///
/// Reuses [InstitutionRepository.watchActive] as-is — no new query,
/// no new repository method. Search is client-side over the live
/// stream (the same pattern [LearningLibraryScreen] already uses for
/// materials), since the institution count for one type is small
/// enough that a Firestore full-text search isn't warranted.
class InstitutionBrowseScreen extends StatefulWidget {
  final InstitutionType institutionType;
  const InstitutionBrowseScreen({super.key, this.institutionType = InstitutionType.university});

  @override
  State<InstitutionBrowseScreen> createState() => _InstitutionBrowseScreenState();
}

class _InstitutionBrowseScreenState extends State<InstitutionBrowseScreen> {
  final InstitutionRepository _repository = InstitutionRepository();
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
      appBar: AppBar(title: const Text('Universities')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SearchField(
                controller: _searchController,
                hintText: 'Search universities...',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<InstitutionModel>>(
                stream: _repository.watchActive(typeId: widget.institutionType.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snapshot.hasError) return const ErrorView(message: 'Could not load universities right now.');
                  var institutions = snapshot.data ?? const <InstitutionModel>[];
                  if (_query.isNotEmpty) {
                    institutions = institutions
                        .where((i) =>
                            i.name.toLowerCase().contains(_query) || i.shortName.toLowerCase().contains(_query))
                        .toList();
                  }
                  if (institutions.isEmpty) {
                    return EmptyView(
                      message: _query.isEmpty
                          ? 'No universities have been added yet.'
                          : 'No universities match "$_query".',
                      icon: Icons.account_balance_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: institutions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final institution = institutions[index];
                      return Material(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => InstitutionDetailScreen(institutionId: institution.institutionId),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: AppColors.primaryBlue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        institution.name,
                                        style: AppTextStyles.bodyLarge(
                                          Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (institution.state != null && institution.state!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            institution.state!,
                                            style: AppTextStyles.bodySmall(AppColors.textSecondary),
                                          ),
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
