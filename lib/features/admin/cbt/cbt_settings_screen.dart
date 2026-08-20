import 'package:flutter/material.dart';
import '../../../models/app_settings_models.dart';
import '../../../repositories/settings_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Stage CBT-3 — "CBT Settings" tile, covering both the brief's
/// "Access Rules" section and the global parts of "Practice Controls"/
/// "Mock Exam Controls" (their enable/disable and premium-requirement
/// toggles). These three sections in the brief all edit the same one
/// [CbtSettingsModel] document — building three separate screens for
/// one settings doc would be exactly the "duplicate configuration
/// system" the brief repeatedly warns against, so they're one screen
/// here, grouped into clearly labeled sections instead. Documented in
/// the Stage CBT-3 completion report as a deliberate consolidation.
///
/// Per-exam settings (attempt limit, premium, availability, supported
/// modes) are NOT here — those already have a complete editor in
/// [ExamEditorScreen] and stay there; this screen only holds the
/// platform-wide defaults [CbtSettingsModel] documents.
class CbtSettingsScreen extends StatefulWidget {
  const CbtSettingsScreen({super.key});

  @override
  State<CbtSettingsScreen> createState() => _CbtSettingsScreenState();
}

class _CbtSettingsScreenState extends State<CbtSettingsScreen> {
  final AppSettingsRepository _repository = AppSettingsRepository();
  late final TextEditingController _freeAttemptController;
  late final TextEditingController _trialAttemptController;
  late final TextEditingController _premiumAttemptController;
  late final TextEditingController _freeQuestionLimitController;

  CbtSettingsModel? _loaded;
  bool _practiceEnabled = true;
  bool _mockEnabled = true;
  bool _requirePremiumForPractice = false;
  bool _requirePremiumForMock = false;
  bool _offlinePracticeEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _freeAttemptController = TextEditingController();
    _trialAttemptController = TextEditingController();
    _premiumAttemptController = TextEditingController();
    _freeQuestionLimitController = TextEditingController();
  }

  @override
  void dispose() {
    _freeAttemptController.dispose();
    _trialAttemptController.dispose();
    _premiumAttemptController.dispose();
    _freeQuestionLimitController.dispose();
    super.dispose();
  }

  void _applyLoaded(CbtSettingsModel settings) {
    if (_loaded != null) return; // only seed controllers once, on first load
    _loaded = settings;
    _freeAttemptController.text = settings.freeAttemptLimit?.toString() ?? '';
    _trialAttemptController.text = settings.trialAttemptLimit?.toString() ?? '';
    _premiumAttemptController.text = settings.premiumAttemptLimit?.toString() ?? '';
    _freeQuestionLimitController.text = settings.freeUserQuestionLimit?.toString() ?? '';
    _practiceEnabled = settings.practiceEnabled;
    _mockEnabled = settings.mockEnabled;
    _requirePremiumForPractice = settings.requirePremiumForPractice;
    _requirePremiumForMock = settings.requirePremiumForMock;
    _offlinePracticeEnabled = settings.offlinePracticeEnabled;
  }

  Future<void> _save() async {
    if (_loaded == null) return;
    setState(() => _saving = true);

    final updated = CbtSettingsModel(
      practiceEnabled: _practiceEnabled,
      mockEnabled: _mockEnabled,
      freeAttemptLimit: int.tryParse(_freeAttemptController.text.trim()),
      trialAttemptLimit: int.tryParse(_trialAttemptController.text.trim()),
      premiumAttemptLimit: int.tryParse(_premiumAttemptController.text.trim()),
      requirePremiumForPractice: _requirePremiumForPractice,
      requirePremiumForMock: _requirePremiumForMock,
      freeUserQuestionLimit: int.tryParse(_freeQuestionLimitController.text.trim()),
      offlinePracticeEnabled: _offlinePracticeEnabled,
    );

    try {
      await _repository.saveCbtSettings(updated, previous: _loaded);
      if (!mounted) return;
      setState(() {
        _loaded = updated;
        _saving = false;
      });
      AppSnackbar.success(context, 'CBT settings updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Could not save settings. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('CBT Settings')),
      body: StreamBuilder<CbtSettingsModel>(
        stream: _repository.watchCbtSettings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();
          _applyLoaded(snapshot.data!);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Text(
                'These are platform-wide defaults. A specific exam\'s own attempt limit, '
                'premium requirement, and availability window (set in that exam\'s editor) '
                'always take priority over these.',
                style: AppTextStyles.bodySmall(bodyColor),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Availability'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Practice enabled'),
                subtitle: const Text('Turn off to hide Practice across the whole CBT Center.'),
                value: _practiceEnabled,
                onChanged: (v) => setState(() => _practiceEnabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mock exams enabled'),
                subtitle: const Text('Turn off to hide Mock Exams across the whole CBT Center.'),
                value: _mockEnabled,
                onChanged: (v) => setState(() => _mockEnabled = v),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Access rules'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require premium for Practice'),
                subtitle: const Text(
                  'Configuration only — enforcement needs the future subscription/entitlement system.',
                ),
                value: _requirePremiumForPractice,
                onChanged: (v) => setState(() => _requirePremiumForPractice = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require premium for Mock Exams'),
                subtitle: const Text(
                  'Configuration only — enforcement needs the future subscription/entitlement system.',
                ),
                value: _requirePremiumForMock,
                onChanged: (v) => setState(() => _requirePremiumForMock = v),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _freeAttemptController,
                hintText: 'Free-user attempt limit (blank = unlimited)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _trialAttemptController,
                hintText: 'Trial-user attempt limit (blank = unlimited)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _premiumAttemptController,
                hintText: 'Premium-user attempt limit (blank = unlimited)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _freeQuestionLimitController,
                hintText: 'Free-user practice question limit (blank = unlimited)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                'These are defaults an exam falls back to when it has no attempt limit of its own set.',
                style: AppTextStyles.bodySmall(bodyColor),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Offline'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Offline practice enabled'),
                subtitle: const Text(
                  'Reserved for the future offline sync/replay engine — no sessions are actually '
                  'stored or replayed offline yet, so this switch has no effect today.',
                ),
                value: _offlinePracticeEnabled,
                onChanged: (v) => setState(() => _offlinePracticeEnabled = v),
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Save Settings', isLoading: _saving, onPressed: _saving ? null : _save),
            ],
          );
        },
      ),
    );
  }
}
