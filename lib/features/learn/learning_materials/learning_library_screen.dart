import 'package:flutter/material.dart';
import '../../../core/enums/learning_material_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/learning_material_model.dart';
import '../../../repositories/learning_material_repository.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import 'material_detail_screen.dart';
import 'widgets/material_card.dart';

/// The Learn tab's home — Stage 3.5 Part 4's "central content library"
/// for University coursework, JAMB, WAEC, and NECO prep. Search and
/// type filters run client-side over a live [LearningMaterialRepository]
/// stream so results update the moment an admin publishes something new,
/// with no manual refresh needed.
class LearningLibraryScreen extends StatefulWidget {
  final String? courseId;
  const LearningLibraryScreen({super.key, this.courseId});

  @override
  State<LearningLibraryScreen> createState() => _LearningLibraryScreenState();
}

class _LearningLibraryScreenState extends State<LearningLibraryScreen> {
  final LearningMaterialRepository _repository = LearningMaterialRepository();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  LearningMaterialType? _typeFilter;

  // Cached rather than created inline in `_buildLibrary()` — see the
  // identical fix (and its doc comment) on `AdminLearningMaterialsScreen`.
  // Here specifically it also fixes `RefreshIndicator`: pulling to
  // refresh used to call a bare `setState(() {})`, which — before this
  // fix — would have handed StreamBuilder a brand new Stream and
  // flashed the whole grid back to a loading spinner for a gesture that
  // shouldn't need to touch the subscription at all (the stream is
  // already live).
  late Stream<List<LearningMaterialModel>> _libraryStream;

  @override
  void initState() {
    super.initState();
    // Best-effort — flips any scheduled item whose time has come; see
    // LearningMaterialRepository.publishDueScheduled's doc comment.
    _repository.publishDueScheduled();
    _refreshStream();
  }

  void _refreshStream() {
    _libraryStream = _repository.watchMaterials(
      courseId: widget.courseId,
      type: _typeFilter?.id,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SearchField(
                controller: _searchController,
                hintText: 'Search materials, notes, past questions...',
                onChanged: (v) => setState(() => _query = v.trim()),
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
                      selected: _typeFilter == null,
                      onTap: () => setState(() {
                        _typeFilter = null;
                        _refreshStream();
                      }),
                    ),
                  ),
                  ...LearningMaterialType.values.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppChip(
                        label: t.label,
                        accent: t.color,
                        selected: _typeFilter == t,
                        onTap: () => setState(() {
                          _typeFilter = _typeFilter == t ? null : t;
                          _refreshStream();
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _query.isEmpty ? _buildLibrary() : _buildSearchResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildLibrary() {
    return StreamBuilder<List<LearningMaterialModel>>(
      stream: _libraryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Could not load materials right now.',
            onRetry: () => setState(_refreshStream),
          );
        }
        final materials = snapshot.data ?? const [];
        if (materials.isEmpty) {
          return const EmptyView(
            message: 'No learning materials here yet — check back soon.',
            icon: Icons.folder_open_rounded,
          );
        }
        return RefreshIndicator(
          onRefresh: _repository.publishDueScheduled,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(title: 'Learning Materials (${materials.length})'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => MaterialCard(
                      material: materials[index],
                      onTap: () => _openMaterial(materials[index]),
                    ),
                    childCount: materials.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<Result<List<LearningMaterialModel>>>(
      future: _repository.searchMaterials(_query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
        final result = snapshot.data;
        final materials = switch (result) {
          Success(data: final data) => data,
          _ => const <LearningMaterialModel>[],
        };
        if (materials.isEmpty) {
          return EmptyView(message: 'No results for "$_query".', icon: Icons.search_off_rounded);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          itemCount: materials.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _SearchResultTile(
            material: materials[index],
            onTap: () => _openMaterial(materials[index]),
          ),
        );
      },
    );
  }

  void _openMaterial(LearningMaterialModel material) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: material)));
  }
}

class _SearchResultTile extends StatelessWidget {
  final LearningMaterialModel material;
  final VoidCallback onTap;
  const _SearchResultTile({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: material.type.color.withOpacity(0.12),
        child: Icon(material.type.icon, color: material.type.color, size: 20),
      ),
      title: Text(material.title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      subtitle: Text(material.type.label),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
