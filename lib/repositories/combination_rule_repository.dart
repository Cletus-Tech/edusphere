import '../core/constants/app_constants.dart';
import '../core/enums/audit_action_type.dart';
import '../core/utils/result.dart';
import '../models/combination_rule_model.dart';
import '../services/audit/audit_log_service.dart';
import 'base_repository.dart';

/// Stage CBT-Refactor Phase 5. A real [BaseRepository] (doc id =
/// categoryId) rather than a hand-rolled singleton class, since —
/// unlike `CreatorProfileRepository`'s genuinely fixed single doc —
/// this collection has one doc per category and every doc shares the
/// exact same CRUD shape [BaseRepository] already provides.
class CombinationRuleRepository extends BaseRepository<CombinationRuleModel> {
  CombinationRuleRepository() : super(AppConstants.combinationRulesCollection);

  @override
  CombinationRuleModel fromMap(Map<String, dynamic> map, String id) =>
      CombinationRuleModel.fromMap(map, id);

  /// Never null — a category with no configured rule yet gets the
  /// model's own default (`requiredSubjectCount: 4`,
  /// `compulsorySubjectId: null`), so callers never have to
  /// special-case "no rule configured" separately from "rule
  /// configured with default values."
  Stream<CombinationRuleModel> watchForCategory(String categoryId) {
    return streamById(categoryId).map((model) => model ?? CombinationRuleModel(categoryId: categoryId));
  }

  Future<Result<void>> setCompulsorySubject(
    String categoryId,
    String? subjectId, {
    required int requiredSubjectCount,
  }) async {
    final current = (await streamById(categoryId).first) ?? CombinationRuleModel(categoryId: categoryId);
    final updated = current.copyWith(
      compulsorySubjectId: subjectId,
      clearCompulsory: subjectId == null,
      requiredSubjectCount: requiredSubjectCount,
    );
    final result = await save(updated);
    if (result case Failure()) return result;
    AuditLogService.instance.log(
      action: AuditActionType.edit,
      module: AuditModules.examPrep,
      targetCollection: AppConstants.combinationRulesCollection,
      targetId: categoryId,
      targetTitle: '$categoryId combination rule',
      previousValues: current.toMap(),
      newValues: updated.toMap(),
    );
    return result;
  }
}
