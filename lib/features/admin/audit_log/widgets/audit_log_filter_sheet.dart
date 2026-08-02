import 'package:flutter/material.dart';
import '../../../../core/enums/audit_action_type.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/result.dart';
import '../../../../repositories/audit_log_repository.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text_styles.dart';

/// The current set of Audit Log filters — a plain value object so the
/// sheet and the screen agree on shape without re-deriving it from
/// widget state each time. Mirrors `AdminMaterialFilters`' shape.
class AuditLogFilters {
  final String? userId;
  final String? userLabel;
  final AuditActionType? actionType;
  final String? module;
  final String? targetId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const AuditLogFilters({
    this.userId,
    this.userLabel,
    this.actionType,
    this.module,
    this.targetId,
    this.dateFrom,
    this.dateTo,
  });

  bool get isEmpty =>
      userId == null &&
      actionType == null &&
      module == null &&
      (targetId == null || targetId!.isEmpty) &&
      dateFrom == null &&
      dateTo == null;

  int get activeCount => [
        userId,
        actionType,
        module,
        (targetId != null && targetId!.isNotEmpty) ? targetId : null,
        dateFrom,
        dateTo,
      ].where((v) => v != null).length;

  AuditLogFilters copyWith({
    String? userId,
    String? userLabel,
    bool clearUser = false,
    AuditActionType? actionType,
    bool clearActionType = false,
    String? module,
    bool clearModule = false,
    String? targetId,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
  }) {
    return AuditLogFilters(
      userId: clearUser ? null : (userId ?? this.userId),
      userLabel: clearUser ? null : (userLabel ?? this.userLabel),
      actionType: clearActionType ? null : (actionType ?? this.actionType),
      module: clearModule ? null : (module ?? this.module),
      targetId: targetId ?? this.targetId,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

/// Modal filter sheet for the Audit Log screen: user, action type,
/// module, target id, and a date range.
Future<AuditLogFilters?> showAuditLogFilterSheet(
  BuildContext context, {
  required AuditLogFilters current,
}) {
  return showModalBottomSheet<AuditLogFilters>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _AuditLogFilterSheetBody(initial: current),
  );
}

class _AuditLogFilterSheetBody extends StatefulWidget {
  final AuditLogFilters initial;
  const _AuditLogFilterSheetBody({required this.initial});

  @override
  State<_AuditLogFilterSheetBody> createState() => _AuditLogFilterSheetBodyState();
}

class _AuditLogFilterSheetBodyState extends State<_AuditLogFilterSheetBody> {
  late AuditLogFilters _filters;
  final AuditLogRepository _repository = AuditLogRepository();
  final TextEditingController _targetIdController = TextEditingController();
  Future<List<AuditActor>>? _actorsFuture;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
    _targetIdController.text = widget.initial.targetId ?? '';
    _actorsFuture = _loadActors();
  }

  Future<List<AuditActor>> _loadActors() async {
    final result = await _repository.fetchRecentActors();
    return switch (result) {
      Success(data: final actors) => actors,
      Failure() => const <AuditActor>[],
    };
  }

  @override
  void dispose() {
    _targetIdController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = (_filters.dateFrom != null && _filters.dateTo != null)
        ? DateTimeRange(start: _filters.dateFrom!, end: _filters.dateTo!)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: initialRange,
    );
    if (picked == null) return;
    setState(() {
      _filters = _filters.copyWith(
        dateFrom: DateTime(picked.start.year, picked.start.month, picked.start.day),
        dateTo: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter audit log', style: AppTextStyles.titleMedium(textColor)),
                  TextButton(
                    onPressed: () => setState(() {
                      _filters = const AuditLogFilters();
                      _targetIdController.clear();
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('User', style: AppTextStyles.bodySmall(bodyColor)),
              const SizedBox(height: 6),
              FutureBuilder<List<AuditActor>>(
                future: _actorsFuture,
                builder: (context, snapshot) {
                  final actors = snapshot.data ?? const <AuditActor>[];
                  final validValue = actors.any((a) => a.uid == _filters.userId) ? _filters.userId : null;
                  return DropdownButtonFormField<String>(
                    value: validValue,
                    isExpanded: true,
                    hint: const Text('All users'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('All users')),
                      ...actors.map((a) => DropdownMenuItem(value: a.uid, child: Text(a.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() {
                      final actor = actors.where((a) => a.uid == v).toList();
                      _filters = _filters.copyWith(
                        userId: v,
                        userLabel: actor.isEmpty ? null : actor.first.name,
                        clearUser: v == null,
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text('Action', style: AppTextStyles.bodySmall(bodyColor)),
              const SizedBox(height: 6),
              DropdownButtonFormField<AuditActionType>(
                value: _filters.actionType,
                isExpanded: true,
                hint: const Text('All actions'),
                items: [
                  const DropdownMenuItem<AuditActionType>(value: null, child: Text('All actions')),
                  ...AuditActionType.values
                      .where((a) => a != AuditActionType.other)
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.label))),
                ],
                onChanged: (v) => setState(() => _filters = _filters.copyWith(actionType: v, clearActionType: v == null)),
              ),
              const SizedBox(height: 14),
              Text('Module', style: AppTextStyles.bodySmall(bodyColor)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _filters.module,
                isExpanded: true,
                hint: const Text('All modules'),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All modules')),
                  ...AuditModules.all.map((m) => DropdownMenuItem(value: m, child: Text(AuditModules.label(m)))),
                ],
                onChanged: (v) => setState(() => _filters = _filters.copyWith(module: v, clearModule: v == null)),
              ),
              const SizedBox(height: 14),
              Text('Target ID', style: AppTextStyles.bodySmall(bodyColor)),
              const SizedBox(height: 6),
              TextField(
                controller: _targetIdController,
                decoration: const InputDecoration(hintText: 'Paste a document ID'),
                onChanged: (v) => _filters = _filters.copyWith(targetId: v.trim()),
              ),
              const SizedBox(height: 14),
              Text('Date range', style: AppTextStyles.bodySmall(bodyColor)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.date_range_rounded, size: 20),
                  ),
                  child: Text(
                    (_filters.dateFrom != null && _filters.dateTo != null)
                        ? '${FormatUtils.date(_filters.dateFrom!)} — ${FormatUtils.date(_filters.dateTo!)}'
                        : 'Any time',
                  ),
                ),
              ),
              if (_filters.dateFrom != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(
                      () => _filters = _filters.copyWith(clearDateFrom: true, clearDateTo: true),
                    ),
                    child: const Text('Clear date range'),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: SecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Apply',
                      onPressed: () => Navigator.pop(context, _filters),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
