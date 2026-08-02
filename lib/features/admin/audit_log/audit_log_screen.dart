import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/result.dart';
import '../../../models/audit_log_model.dart';
import '../../../repositories/audit_log_repository.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'widgets/audit_log_detail_sheet.dart';
import 'widgets/audit_log_filter_sheet.dart';
import 'widgets/audit_log_list_tile.dart';

/// Admin Dashboard → Audit Log (Stage 3.6.1). Cursor-paginated over
/// `AuditLogRepository.fetchPage` — unlike the "grow the limit" pattern
/// `AdminLearningMaterialsScreen` uses for the (bounded) materials
/// catalog, an audit trail grows forever, so this fetches server-side
/// pages via `startAfterDocument` instead of ever widening one query.
///
/// Search is client-side over the currently loaded page only (same
/// documented "Firestore has no partial-text search" limitation every
/// other admin list in this codebase already carries) — user/action/
/// module/target/date filters are the precise, indexed way to narrow
/// results; search is a quick scan on top of whatever's loaded.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AuditLogRepository _repository = AuditLogRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<AuditLogModel> _logs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  String? _error;
  String _searchText = '';
  AuditLogFilters _filters = const AuditLogFilters();

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoadingFirstPage = true;
      _error = null;
      _logs.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetch(reset: true);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final result = await _repository.fetchPage(
      pageSize: 30,
      startAfter: reset ? null : _lastDocument,
      userId: _filters.userId,
      actionType: _filters.actionType,
      module: _filters.module,
      targetId: (_filters.targetId != null && _filters.targetId!.isNotEmpty) ? _filters.targetId : null,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final page):
        setState(() {
          _logs.addAll(page.logs);
          _lastDocument = page.lastDocument;
          _hasMore = page.hasMore;
          _isLoadingFirstPage = false;
          _isLoadingMore = false;
        });
      case Failure(message: final message):
        setState(() {
          _error = message;
          _isLoadingFirstPage = false;
          _isLoadingMore = false;
        });
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showAuditLogFilterSheet(context, current: _filters);
    if (result == null) return;
    setState(() => _filters = result);
    await _loadFirstPage();
  }

  List<AuditLogModel> get _visibleLogs {
    if (_searchText.trim().isEmpty) return _logs;
    final query = _searchText.trim().toLowerCase();
    return _logs.where((log) {
      return log.summary.toLowerCase().contains(query) ||
          log.userName.toLowerCase().contains(query) ||
          (log.targetTitle ?? '').toLowerCase().contains(query) ||
          log.actionType.label.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    Widget body;
    if (_isLoadingFirstPage) {
      body = const LoadingView(message: 'Loading audit log...');
    } else if (_error != null) {
      body = ErrorView(message: 'Could not load the audit log: $_error', onRetry: _loadFirstPage);
    } else {
      final visible = _visibleLogs;
      body = RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              SearchField(
                controller: _searchController,
                hintText: 'Search this page (summary, user, target)...',
                onChanged: (value) => setState(() => _searchText = value),
                onFilterTap: _openFilterSheet,
              ),
              if (!_filters.isEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Text('${_filters.activeCount} filter(s) active', style: AppTextStyles.bodySmall(bodyColor)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _filters = const AuditLogFilters());
                        _loadFirstPage();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    message: _logs.isEmpty
                        ? (_filters.isEmpty
                            ? 'No admin activity has been logged yet.'
                            : 'No entries match these filters.')
                        : 'No entries on this page match your search.',
                    icon: Icons.receipt_long_outlined,
                  ),
                )
              else ...[
                ...visible.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AuditLogListTile(log: log, onTap: () => showAuditLogDetailSheet(context, log)),
                  ),
                ),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                else if (_hasMore && _searchText.trim().isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton(onPressed: _loadMore, child: const Text('Load more')),
                    ),
                  ),
              ],
            ],
          ),
        );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: body,
    );
  }
}
