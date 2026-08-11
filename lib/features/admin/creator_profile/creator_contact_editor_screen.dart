import 'package:flutter/material.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Contact & Social Links (§7) — email, website, and an arbitrary set
/// of social links (label -> URL). `socialLinks` is already a
/// `Map<String, String>` on [CreatorProfileModel] (Part 1), so this
/// screen just needs a UI for adding/editing/removing entries — no
/// model or Firestore structure change.
class CreatorContactEditorScreen extends StatefulWidget {
  final CreatorProfileModel profile;
  const CreatorContactEditorScreen({super.key, required this.profile});

  @override
  State<CreatorContactEditorScreen> createState() => _CreatorContactEditorScreenState();
}

class _CreatorContactEditorScreenState extends State<CreatorContactEditorScreen> {
  final CreatorProfileRepository _repository = CreatorProfileRepository();
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late Map<String, String> _socialLinks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.profile.email);
    _websiteController = TextEditingController(text: widget.profile.website);
    _socialLinks = Map<String, String>.from(widget.profile.socialLinks);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditLink({String? existingKey}) async {
    final labelController = TextEditingController(text: existingKey ?? '');
    final urlController = TextEditingController(text: existingKey != null ? _socialLinks[existingKey] ?? '' : '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existingKey == null ? 'Add Social Link' : 'Edit Social Link',
                style: AppTextStyles.titleMedium(AppColors.textPrimary)),
            const SizedBox(height: 16),
            AppTextField(controller: labelController, hintText: 'Platform (e.g. Twitter, GitHub, LinkedIn)'),
            const SizedBox(height: 12),
            AppTextField(controller: urlController, hintText: 'https://...', keyboardType: TextInputType.url),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                if (labelController.text.trim().isEmpty || urlController.text.trim().isEmpty) return;
                Navigator.pop(sheetContext, true);
              },
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        if (existingKey != null && existingKey != labelController.text.trim()) {
          _socialLinks.remove(existingKey);
        }
        _socialLinks[labelController.text.trim()] = urlController.text.trim();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.profile.copyWith(
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      socialLinks: _socialLinks,
    );
    try {
      await _repository.save(updated, previous: widget.profile);
      if (!mounted) return;
      AppSnackbar.success(context, 'Contact information updated.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Could not save changes. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact & Social Links')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Contact', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
          const SizedBox(height: 12),
          AppTextField(
            controller: _emailController,
            hintText: 'Email address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _websiteController,
            hintText: 'Website URL',
            prefixIcon: Icons.language_rounded,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Social Links', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
              TextButton.icon(
                onPressed: () => _addOrEditLink(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_socialLinks.isEmpty)
            EmptyView(message: 'No social links yet.', icon: Icons.link_off_rounded)
          else
            ..._socialLinks.entries.map(
              (e) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(e.key),
                  subtitle: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall(bodyColor)),
                  onTap: () => _addOrEditLink(existingKey: e.key),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () => setState(() => _socialLinks.remove(e.key)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save Changes', isLoading: _saving, onPressed: _save),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
