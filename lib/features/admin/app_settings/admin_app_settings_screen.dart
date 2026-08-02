import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/storage_paths.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/utils/result.dart';
import '../../../models/app_settings_models.dart';
import '../../../models/user_model.dart';
import '../../../repositories/settings_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/config/feature_flag_service.dart';
import '../../../services/firebase/auth_service.dart';
import '../../../services/firebase/storage_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Admin → App Settings. Replaces the Stage 1 `FeaturePlaceholder` with
/// three real tabs over [AppSettingsRepository] / [FeatureFlagService].
///
/// `firestore.rules` requires `isSuperAdmin()` to write `settings/*` and
/// `feature_flags/*`, but only `isAdmin()` for `banners/*` — so Feature
/// Flags and Upload/App Config are gated to super admins here (matching
/// the rule, not looser than it), while Banners is open to any admin who
/// reached this screen.
class AdminAppSettingsScreen extends StatelessWidget {
  const AdminAppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App Settings'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Feature Flags'),
            Tab(text: 'Banners'),
            Tab(text: 'Uploads & App'),
          ]),
        ),
        body: StreamBuilder<UserModel?>(
          stream: uid == null ? const Stream.empty() : UserRepository().watchUser(uid),
          builder: (context, snapshot) {
            final isSuperAdmin = snapshot.data?.roles.contains(UserRole.superAdmin) ?? false;
            return TabBarView(
              children: [
                isSuperAdmin
                    ? const _FeatureFlagsTab()
                    : const _SuperAdminRequired(section: 'Feature Flags'),
                const _BannersTab(),
                isSuperAdmin
                    ? const _UploadsAndAppTab()
                    : const _SuperAdminRequired(section: 'Uploads & App Config'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SuperAdminRequired extends StatelessWidget {
  final String section;
  const _SuperAdminRequired({required this.section});

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      message: '$section requires Super Admin access.',
      icon: Icons.lock_outline_rounded,
    );
  }
}

// ---------------------------------------------------------------------
// Feature Flags
// ---------------------------------------------------------------------

class _FeatureFlagsTab extends StatelessWidget {
  const _FeatureFlagsTab();

  static const _labels = {
    FeatureKeys.aiTutor: 'AI Tutor',
    FeatureKeys.community: 'Community',
    FeatureKeys.marketplace: 'Marketplace',
    FeatureKeys.scholarships: 'Scholarships',
    FeatureKeys.jamb: 'JAMB Prep',
    FeatureKeys.waec: 'WAEC Prep',
    FeatureKeys.neco: 'NECO Prep',
    FeatureKeys.cbt: 'CBT / Exams',
    FeatureKeys.parentsPortal: 'Parents Portal',
    FeatureKeys.professionalExams: 'Professional Exams',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, FeatureFlagModel>>(
      stream: FeatureFlagService.instance.watchAll(),
      builder: (context, snapshot) {
        final flags = snapshot.data ?? {};
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _labels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final key = _labels.keys.elementAt(i);
            final label = _labels[key]!;
            final existing = flags[key];
            final isEnabled = existing?.isEnabled ?? true; // fail-open, matches FeatureFlagService default

            return CustomCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.titleMedium(
                            Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary)),
                        if (existing == null)
                          Text('No flag document yet — defaults to enabled',
                              style: AppTextStyles.bodySmall(
                                  Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (value) => FeatureFlagService.instance.updateFlag(FeatureFlagModel(
                      featureKey: key,
                      label: label,
                      isEnabled: value,
                      enabledForInstitutionIds: existing?.enabledForInstitutionIds ?? const {},
                      minAppVersion: existing?.minAppVersion,
                      description: existing?.description,
                    )),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------

class _BannersTab extends StatelessWidget {
  const _BannersTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<BannerModel>>(
        stream: BannerRepository().watchAllForAdmin(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load banners: ${snapshot.error}');
          }
          if (!snapshot.hasData) return const LoadingView();
          final banners = snapshot.data!;
          if (banners.isEmpty) {
            return const EmptyView(message: 'No banners yet.', icon: Icons.view_carousel_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: banners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BannerTile(banner: banners[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add banner'),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _BannerEditorSheet(),
        ),
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final BannerModel banner;
  const _BannerTile({required this.banner});

  Future<void> _delete(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete banner?',
      message: 'This removes it from the home screen immediately.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true) await BannerRepository().removeBanner(banner);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;

    return CustomCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: banner.imageUrl.isEmpty
                ? Container(width: 56, height: 56, color: AppColors.primaryBlue.withOpacity(0.1))
                : Image.network(banner.imageUrl, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(banner.title ?? '(untitled)', style: AppTextStyles.titleMedium(textColor)),
          ),
          Switch(
            value: banner.isActive,
            onChanged: (value) => BannerRepository().saveBanner(
              BannerModel(
                bannerId: banner.bannerId,
                imageUrl: banner.imageUrl,
                title: banner.title,
                deepLink: banner.deepLink,
                order: banner.order,
                isActive: value,
                startsAt: banner.startsAt,
                endsAt: banner.endsAt,
              ),
              previous: banner,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }
}

class _BannerEditorSheet extends StatefulWidget {
  const _BannerEditorSheet();

  @override
  State<_BannerEditorSheet> createState() => _BannerEditorSheetState();
}

class _BannerEditorSheetState extends State<_BannerEditorSheet> {
  final _titleController = TextEditingController();
  final _deepLinkController = TextEditingController();
  File? _image;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked?.files.single.path == null) return;
    setState(() => _image = File(picked!.files.single.path!));
  }

  Future<void> _save() async {
    if (_image == null) {
      AppSnackbar.error(context, 'Choose an image for the banner first.');
      return;
    }
    setState(() => _saving = true);

    final bannerId = BannerRepository().newId();
    final fileName = _image!.path.split('/').last;
    final uploadResult = await StorageService().uploadFile(
      path: StoragePaths.appBanner(bannerId, fileName),
      file: _image!,
    );
    if (!mounted) return;
    if (uploadResult.isFailure) {
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Could not upload the banner image.');
      return;
    }
    final imageUrl = (uploadResult as Success<String>).data;

    await BannerRepository().saveBanner(BannerModel(
      bannerId: bannerId,
      imageUrl: imageUrl,
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      deepLink: _deepLinkController.text.trim().isEmpty ? null : _deepLinkController.text.trim(),
    ));

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Banner', style: AppTextStyles.headlineLarge(
              Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_image!, height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(_image == null ? 'Choose image' : 'Change image'),
          ),
          const SizedBox(height: 8),
          AppTextField(controller: _titleController, hintText: 'Title (optional)'),
          const SizedBox(height: 12),
          AppTextField(controller: _deepLinkController, hintText: 'Deep link / route (optional)'),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save banner', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Uploads & App Config
// ---------------------------------------------------------------------

class _UploadsAndAppTab extends StatelessWidget {
  const _UploadsAndAppTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _UploadSettingsCard(),
        SizedBox(height: 16),
        _AppConfigCard(),
      ],
    );
  }
}

class _UploadSettingsCard extends StatefulWidget {
  const _UploadSettingsCard();

  @override
  State<_UploadSettingsCard> createState() => _UploadSettingsCardState();
}

class _UploadSettingsCardState extends State<_UploadSettingsCard> {
  final _maxSizeController = TextEditingController();
  final _extensionsController = TextEditingController();
  final _concurrentController = TextEditingController();
  bool _backgroundEnabled = false;
  bool _saving = false;
  UploadSettingsModel? _loaded;

  void _hydrate(UploadSettingsModel model) {
    if (_loaded != null) return; // only seed controllers once per live doc
    _loaded = model;
    _maxSizeController.text = model.maxFileSizeMb.toString();
    _extensionsController.text = model.allowedExtensions.join(', ');
    _concurrentController.text = model.maxConcurrentUploads.toString();
    _backgroundEnabled = model.backgroundUploadsEnabled;
  }

  Future<void> _save() async {
    if (_loaded == null) return;
    setState(() => _saving = true);
    final updated = UploadSettingsModel(
      maxFileSizeMb: int.tryParse(_maxSizeController.text.trim()) ?? _loaded!.maxFileSizeMb,
      allowedExtensions: _extensionsController.text
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList(),
      maxConcurrentUploads: int.tryParse(_concurrentController.text.trim()) ?? _loaded!.maxConcurrentUploads,
      backgroundUploadsEnabled: _backgroundEnabled,
    );
    await AppSettingsRepository().saveUploadSettings(updated, previous: _loaded);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _loaded = updated;
    });
    AppSnackbar.success(context, 'Upload settings saved.');
  }

  @override
  void dispose() {
    _maxSizeController.dispose();
    _extensionsController.dispose();
    _concurrentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;

    return StreamBuilder<UploadSettingsModel>(
      stream: AppSettingsRepository().watchUploadSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CustomCard(child: LoadingView());
        }
        _hydrate(snapshot.data!);

        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload Limits', style: AppTextStyles.titleMedium(textColor)),
              const SizedBox(height: 12),
              AppTextField(
                controller: _maxSizeController,
                hintText: 'Max file size (MB)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              AppTextField(controller: _extensionsController, hintText: 'Allowed extensions (comma-separated)'),
              const SizedBox(height: 10),
              AppTextField(
                controller: _concurrentController,
                hintText: 'Max concurrent uploads',
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Background uploads'),
                value: _backgroundEnabled,
                onChanged: (v) => setState(() => _backgroundEnabled = v),
              ),
              const SizedBox(height: 8),
              PrimaryButton(label: 'Save upload settings', isLoading: _saving, onPressed: _save),
            ],
          ),
        );
      },
    );
  }
}

class _AppConfigCard extends StatefulWidget {
  const _AppConfigCard();

  @override
  State<_AppConfigCard> createState() => _AppConfigCardState();
}

class _AppConfigCardState extends State<_AppConfigCard> {
  final _messageController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _latestVersionController = TextEditingController();
  bool _maintenanceMode = false;
  bool _saving = false;
  AppConfigModel? _loaded;

  void _hydrate(AppConfigModel model) {
    if (_loaded != null) return;
    _loaded = model;
    _messageController.text = model.maintenanceMessage ?? '';
    _minVersionController.text = model.minSupportedVersion ?? '';
    _latestVersionController.text = model.latestVersion ?? '';
    _maintenanceMode = model.maintenanceMode;
  }

  Future<void> _save() async {
    if (_loaded == null) return;
    setState(() => _saving = true);
    final updated = AppConfigModel(
      maintenanceMode: _maintenanceMode,
      maintenanceMessage: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      minSupportedVersion: _minVersionController.text.trim().isEmpty ? null : _minVersionController.text.trim(),
      latestVersion: _latestVersionController.text.trim().isEmpty ? null : _latestVersionController.text.trim(),
    );
    await AppSettingsRepository().saveAppConfig(updated, previous: _loaded);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _loaded = updated;
    });
    AppSnackbar.success(context, 'App settings saved.');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _minVersionController.dispose();
    _latestVersionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;

    return StreamBuilder<AppConfigModel>(
      stream: AppSettingsRepository().watchAppConfig(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CustomCard(child: LoadingView());
        }
        _hydrate(snapshot.data!);

        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App Config', style: AppTextStyles.titleMedium(textColor)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Maintenance mode'),
                value: _maintenanceMode,
                onChanged: (v) => setState(() => _maintenanceMode = v),
              ),
              AppTextField(controller: _messageController, hintText: 'Maintenance message (optional)'),
              const SizedBox(height: 10),
              AppTextField(controller: _minVersionController, hintText: 'Minimum supported version (optional)'),
              const SizedBox(height: 10),
              AppTextField(controller: _latestVersionController, hintText: 'Latest version (optional)'),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Save app settings', isLoading: _saving, onPressed: _save),
            ],
          ),
        );
      },
    );
  }
}
