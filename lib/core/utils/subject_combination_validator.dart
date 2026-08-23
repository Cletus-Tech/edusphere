import '../../models/combination_rule_model.dart';

/// Stage CBT-Refactor Phase 5. Result of checking a student's selected
/// subject set against a [CombinationRuleModel] — deliberately three
/// states, not a bool, per the phase brief: "Do not merely count
/// subjects... capable of determining valid / invalid / incomplete."
enum SubjectCombinationStatus {
  /// Fewer than [CombinationRuleModel.requiredSubjectCount] selected.
  incomplete,

  /// Exactly the required count, and the compulsory subject (if the
  /// rule has one) is included.
  valid,

  /// More than the required count selected, or a rule with a
  /// compulsory subject that isn't present in the selection. In normal
  /// use the UI should never let either happen (the compulsory
  /// subject is locked-selected and further taps are disabled once
  /// full) — this exists as an independent check the UI's own count
  /// logic can't silently drift out of sync with, not as the primary
  /// way invalid states are prevented.
  invalid,
}

/// Pure, stateless, UI-independent — per the brief's explicit
/// instruction not to embed this logic directly inside a screen.
/// Generic over any category's [CombinationRuleModel], not
/// JAMB-specific, since nothing about the check itself is JAMB-only.
class SubjectCombinationValidator {
  const SubjectCombinationValidator._();

  static SubjectCombinationStatus validate({
    required Set<String> selectedSubjectIds,
    required CombinationRuleModel rule,
  }) {
    if (rule.compulsorySubjectId != null && !selectedSubjectIds.contains(rule.compulsorySubjectId)) {
      return SubjectCombinationStatus.invalid;
    }
    if (selectedSubjectIds.length > rule.requiredSubjectCount) {
      return SubjectCombinationStatus.invalid;
    }
    if (selectedSubjectIds.length < rule.requiredSubjectCount) {
      return SubjectCombinationStatus.incomplete;
    }
    return SubjectCombinationStatus.valid;
  }
}
