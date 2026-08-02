import 'package:flutter/material.dart';
import '../../../core/enums/learning_material_type.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/url_launcher_adapter.dart';
import '../../../models/learning_material_model.dart';
import '../../../repositories/learning_material_repository.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Full-screen view of one material — the destination [MaterialCard]
/// taps into. Records a view on open and a download/share on the
/// matching action, per the spec's Part 1 analytics fields.
class MaterialDetailScreen extends StatefulWidget {
  final LearningMaterialModel material;
  const MaterialDetailScreen({super.key, required this.material});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  final LearningMaterialRepository _repository = LearningMaterialRepository();
  final UrlLauncherAdapter _launcher = UrlLauncherAdapter();
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _repository.incrementView(widget.material.materialId);
  }

  Future<void> _open() async {
    final url = widget.material.type == LearningMaterialType.link
        ? widget.material.externalUrl
        : widget.material.fileUrl;
    if (url == null || url.isEmpty) {
      AppSnackbar.error(context, 'This material has no file or link attached yet.');
      return;
    }
    setState(() => _opening = true);
    final launched = await _launcher.launch(Uri.parse(url), preferNativeApp: false);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!launched) {
      AppSnackbar.error(context, "Couldn't open this material. Please try again.");
      return;
    }
    if (widget.material.type != LearningMaterialType.link) {
      _repository.incrementDownload(widget.material.materialId, title: widget.material.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: material.bannerUrl != null && material.bannerUrl!.isNotEmpty
                  ? Image.network(material.bannerUrl!, fit: BoxFit.cover)
                  : Container(
                      color: material.type.color.withOpacity(0.14),
                      alignment: Alignment.center,
                      child: Icon(material.type.icon, size: 64, color: material.type.color),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppChip(label: material.type.label, accent: material.type.color),
                      if (material.topic != null && material.topic!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        AppChip(label: material.topic!, accent: AppColors.textSecondary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(material.title, style: AppTextStyles.headlineLarge(textColor)),
                  if (material.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(material.description, style: AppTextStyles.bodyLarge(bodyColor)),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Stat(icon: Icons.visibility_outlined, label: '${material.viewCount} views'),
                      _Stat(icon: Icons.download_outlined, label: '${material.downloadCount} downloads'),
                      if (material.fileSizeBytes > 0)
                        _Stat(icon: Icons.sd_storage_outlined, label: FormatUtils.fileSize(material.fileSizeBytes)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: material.type == LearningMaterialType.link ? 'Open Link' : 'Download / Open',
                    icon: material.type == LearningMaterialType.link
                        ? Icons.open_in_new_rounded
                        : Icons.download_rounded,
                    isLoading: _opening,
                    onPressed: _open,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: bodyColor),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall(bodyColor)),
      ],
    );
  }
}
