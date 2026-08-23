import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// Stage CBT-Refactor Phase 5. Audit found no existing concept of a
/// "valid subject combination" anywhere in the app (no field on
/// [CourseModel], no config document) — this is the smallest new
/// abstraction that covers what JAMB needs without inventing fake
/// combination data: a compulsory subject (nullable — a board with no
/// compulsory subject just leaves it unset) plus a total required
/// subject count.
///
/// Deliberately generic over `categoryId` (doc id = the same
/// `categoryId` string `SubjectRepository.watchByCategory` already
/// uses, e.g. `'jamb'`), not a JAMB-only model — matches
/// `BoardExamSelectionScreen`'s own reasoning: if another board needs
/// a compulsory-subject combination rule later, this collection
/// already supports it with zero new code.
///
/// [requiredSubjectCount] is the **total** a student must select,
/// including the compulsory one — so a `SubjectCombinationSelectionScreen`
/// showing "Selected: 1 / 4" the moment the locked compulsory subject
/// is auto-selected reads naturally against this same number.
///
/// Defaults (`requiredSubjectCount = 4`, `compulsorySubjectId = null`)
/// describe the real-world standard UTME structure (English +
/// 3 others) as an admin-overridable starting point only — not
/// hardcoded logic baked into a screen. An admin can change this
/// per-category at any time via [CombinationRuleRepository].
class CombinationRuleModel extends Equatable implements FirestoreModel {
  final String categoryId;
  final String? compulsorySubjectId;
  final int requiredSubjectCount;

  const CombinationRuleModel({
    required this.categoryId,
    this.compulsorySubjectId,
    this.requiredSubjectCount = 4,
  });

  factory CombinationRuleModel.fromMap(Map<String, dynamic> map, String categoryId) {
    return CombinationRuleModel(
      categoryId: categoryId,
      compulsorySubjectId: map['compulsorySubjectId'] as String?,
      requiredSubjectCount: map['requiredSubjectCount'] as int? ?? 4,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'compulsorySubjectId': compulsorySubjectId,
        'requiredSubjectCount': requiredSubjectCount,
      };

  CombinationRuleModel copyWith({
    String? compulsorySubjectId,
    bool clearCompulsory = false,
    int? requiredSubjectCount,
  }) {
    return CombinationRuleModel(
      categoryId: categoryId,
      compulsorySubjectId: clearCompulsory ? null : (compulsorySubjectId ?? this.compulsorySubjectId),
      requiredSubjectCount: requiredSubjectCount ?? this.requiredSubjectCount,
    );
  }

  @override
  String get id => categoryId;

  @override
  List<Object?> get props => [categoryId, compulsorySubjectId, requiredSubjectCount];
}
