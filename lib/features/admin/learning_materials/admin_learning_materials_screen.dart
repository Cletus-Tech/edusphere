import 'package:flutter/material.dart';
import '../../../core/enums/material_publication_status.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/result.dart';
import '../../../models/learning_material_model.dart';
import '../../../repositories/learning_material_repository.dart';
import '../../../services/migration/learning_content_migration_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'material_editor_screen.dart';

/// Admin Learning Materials Dashboard — Stage 3.5 Part 5. Search,
/// status filter, bulk selection, and per-item lifecycle actions
/// (edit/publish/unpublish/archive/restore/duplicate/delete), all
/// backed by [LearningMaterialRepository] and fully audit-logged.
class AdminLearningMaterialsScreen extends StatefulWidget {
  const AdminLearningMaterialsScreen({super.key});

  @override
  State<AdminLearningMaterialsScreen> createState() => _AdminLearningMaterialsScreenState();
}

class _AdminLearningMaterialsScreenState extends State<AdminLearningMaterialsScreen> {
  final LearningMaterialRepository _repository = LearningMaterialRepository();
  final TextEditingController _searchController = TextEditingController();

  MaterialPublicationStatus? _statusFilter;
  int _pageLimit = 30;
  String _query = '';
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  bool _migrating = false;

  // Cached rather than created inline in `build()` — StreamBuilder tears
  // down and resubscribes whenever it's handed a *new* Stream instance,
  // and `build()` reruns on every setState (bulk-select checkbox taps,
  // migration progress, etc). Without this, checking one box mid bulk-
  // select would flash the whole list back to a loading spinner. Only
  // recomputed by `_refreshStream()`, called when a filter that actually
  // changes the query fires.
  late Stream<List<LearningMaterialModel>> _materialsStream;

  @override
  void initState() {
    super.initState();
    _refreshStream();
  }

  void _refreshStream() {
    _materialsStream = _repository.watchAllForAdmin(limit: _pageLimit, status: _statusFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _runMigration() async {
    setState(() => _migrating = true);
    final report = await LearningContentMigrationService.instance.migrateAll();
    if (!mounted) return;
    setState(() => _migrating = false);
    AppSnackbar.success(context, report.summary);
  }

  Future<void> _bulkArchive() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Archive ${_selectedIds.length} materials?',
      message: 'They will be hidden from the Learning Library until restored.',
    );
    if (confirmed != true) return;
    final ids = List<String>.from(_selectedIds);
    final fetched = await Future.wait(ids.map(_repository.getMaterialById));
    final materials = fetched.whereType<LearningMaterialModel>().toList();
    final result = await _repository.archiveManyMaterials(materials);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    setState(() {
      _selectedIds.clear();
      _selectMode = false;
    });
    AppSnackbar.success(context, 'Archived ${materials.length} materials.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selectedIds.length} selected' : 'Learning Materials'),
        actions: [
          if (_selectMode) ...[
            IconButton(
              tooltip: 'Archive selected',
              icon: const Icon(Icons.archive_rounded),
              onPressed: _selectedIds.isEmpty ? null : _bulkArchive,
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _selectMode = false;
                _selectedIds.clear();
              }),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select multiple',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => setState(() => _selectMode = true),
            ),
            IconButton(
              tooltip: 'Migrate legacy content',
              icon: _migrating
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded),
              onPressed: _migrating ? null : _runMigration,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const MaterialEditorScreen()),
          );
          if (saved == true) setState(() {});
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Material'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: SearchField(
              controller: _searchController,
              hintText: 'Search all materials...',
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(
                    label: 'All',
                    selected: _statusFilter == null,
                    onTap: () => setState(() {
                      _statusFilter = null;
                      _refreshStream();
                    }),
                  ),
                ),
                ...MaterialPublicationStatus.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: s.label,
                      accent: s.color,
                      selected: _statusFilter == s,
                      onTap: () => setState(() {
                        _statusFilter = _statusFilter == s ? null : s;
                        _refreshStream();
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _query.isEmpty ? _buildList() : _buildSearch()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<LearningMaterialModel>>(
      stream: _materialsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
        if (snapshot.hasError) {
          return ErrorView(message: 'Could not load materials.', onRetry: () => setState(_refreshStream));
        }
        final materials = snapshot.data ?? const [];
        if (materials.isEmpty) return const EmptyView(message: 'No materials yet. Tap "New Material" to add one.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          itemCount: materials.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == materials.length) {
              return materials.length == _pageLimit
                  ? Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _pageLimit += 30;
                          _refreshStream();
                        }),
                        child: const Text('Load more'),
                      ),
                    )
                  : const SizedBox.shrink();
            }
            return _MaterialListTile(
              material: materials[index],
              selectMode: _selectMode,
              selected: _selectedIds.contains(materials[index].materialId),
              onSelect: () => _toggleSelect(materials[index].materialId),
              onTap: () => _openActions(materials[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildSearch() {
    return FutureBuilder<Result<List<LearningMaterialModel>>>(
      future: _repository.searchMaterials(_query, forAdmin: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
        final materials = switch (snapshot.data) {
          Success(data: final data) => data,
          _ => const <LearningMaterialModel>[],
        };
        if (materials.isEmpty) return EmptyView(message: 'No results for "$_query".');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          itemCount: materials.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _MaterialListTile(
            material: materials[index],
            selectMode: false,
            selected: false,
            onSelect: () {},
            onTap: () => _openActions(materials[index]),
          ),
        );
      },
    );
  }

  void _openActions(LearningMaterialModel material) {
    if (_selectMode) {
      _toggleSelect(material.materialId);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MaterialEditorScreen(existing: material)),
                );
              },
            ),
            if (material.status != MaterialPublicationStatus.published)
              ListTile(
                leading: const Icon(Icons.publish_rounded),
                title: const Text('Publish'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _repository.publishMaterial(material);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.unpublished_rounded),
                title: const Text('Unpublish'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _repository.unpublishMaterial(material);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(sheetContext);
                _repository.duplicateMaterial(material);
              },
            ),
            if (material.status == MaterialPublicationStatus.archived)
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _repository.restoreMaterial(material);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.archive_rounded),
                title: const Text('Archive'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _repository.archiveMaterial(material);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await AppDialog.confirm(
                  context,
                  title: 'Delete "${material.title}"?',
                  message: 'It will be removed from the Learning Library. This can be undone by an admin.',
                  isDestructive: true,
                );
                if (confirmed == true) _repository.softDeleteMaterial(material);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialListTile extends StatelessWidget {
  final LearningMaterialModel material;
  final bool selectMode;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onTap;

  const _MaterialListTile({
    required this.material,
    required this.selectMode,
    required this.selected,
    required this.onSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selectMode ? onSelect : onTap,
        onLongPress: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectMode) ...[
                Checkbox(value: selected, onChanged: (_) => onSelect()),
                const SizedBox(width: 4),
              ],
              CircleAvatar(
                backgroundColor: material.type.color.withOpacity(0.12),
                child: Icon(material.type.icon, color: material.type.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.title, style: AppTextStyles.titleMedium(textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${material.type.label} • ${FormatUtils.relative(material.updatedAt)}',
                      style: AppTextStyles.bodySmall(bodyColor),
                    ),
                  ],
                ),
              ),
              AppChip(label: material.status.label, accent: material.status.color),
              if (!selectMode) ...[
                const SizedBox(width: 4),
                Icon(Icons.more_vert_rounded, color: bodyColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
