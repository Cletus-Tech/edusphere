import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/utils/result.dart';
import '../../models/community_models.dart';
import '../../repositories/community_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// New-post composer.
///
/// A single image is supported today, uploaded immediately via
/// [StorageService] once the post has an id (the same small-immediate-
/// upload pattern `MaterialEditorScreen` uses for thumbnails/banners — a
/// post image doesn't need the full [UploadEngine] queue a large course
/// file does). [imageUrls] on the model is already a list, so extending
/// this screen to multi-select later is additive: swap [_pickedImage]
/// for a `List<File>` and loop the same upload call.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // In-memory only — survives navigating away and back within the same
  // app session (e.g. backgrounding to check something), not a restart.
  // Persisting drafts across restarts would need local storage (Hive/
  // SharedPreferences), which is a bigger addition than this fix covers.
  static String? _draftText;
  static File? _draftImage;

  final _textController = TextEditingController();
  File? _pickedImage;
  bool _posting = false;
  double? _uploadProgress; // 0.0-1.0 while an image upload is in flight.

  bool get _hasContent => _textController.text.trim().isNotEmpty || _pickedImage != null;

  @override
  void initState() {
    super.initState();
    if (_draftText != null || _draftImage != null) {
      _textController.text = _draftText ?? '';
      _pickedImage = _draftImage;
    }
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || picked.files.single.path == null) return;
    setState(() => _pickedImage = File(picked.files.single.path!));
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasContent || _posting) return true;

    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Discard this post?'),
        content: const Text("You'll lose what you've written if you leave now."),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _LeaveChoice.keepEditing),
            child: const Text('Continue editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _LeaveChoice.saveDraft),
            child: const Text('Save draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _LeaveChoice.discard),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    switch (choice) {
      case _LeaveChoice.saveDraft:
        _draftText = _textController.text.trim().isEmpty ? null : _textController.text;
        _draftImage = _pickedImage;
        return true;
      case _LeaveChoice.discard:
        _draftText = null;
        _draftImage = null;
        return true;
      case _LeaveChoice.keepEditing:
      case null:
        return false;
    }
  }

  Future<void> _submit() async {
    if (!_hasContent || _posting) return;
    final text = _textController.text.trim();
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      AppSnackbar.error(context, 'You need to be signed in to post.');
      return;
    }

    setState(() {
      _posting = true;
      _uploadProgress = _pickedImage != null ? 0.0 : null;
    });

    final postRepository = PostRepository();
    final postId = postRepository.newId();
    var imageUrls = <String>[];

    if (_pickedImage != null) {
      final fileName = _pickedImage!.path.split('/').last;
      final uploadResult = await StorageService().uploadFile(
        path: StoragePaths.communityPostMedia(postId, fileName),
        file: _pickedImage!,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (uploadResult.isFailure) {
        if (mounted) {
          setState(() {
            _posting = false;
            _uploadProgress = null;
          });
          AppSnackbar.error(context, 'Could not upload image. Please try again.');
        }
        return;
      }
      imageUrls = [(uploadResult as Success<String>).data];
    }

    final result = await postRepository.createPost(PostModel(
      postId: postId,
      authorId: uid,
      text: text,
      imageUrls: imageUrls,
      createdAt: DateTime.now(),
    ));

    if (!mounted) return;
    setState(() {
      _posting = false;
      _uploadProgress = null;
    });

    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not publish your post. Please try again.');
      return;
    }

    // Clear any saved draft now that it's been published.
    _draftText = null;
    _draftImage = null;
    // The success snackbar is shown by CommunityScreen once we're back on
    // the feed — a SnackBar tied to this screen's context would vanish
    // the instant we pop.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final canPost = _hasContent && !_posting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Post'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _posting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : TextButton(
                        onPressed: canPost ? _submit : null,
                        child: Text(
                          'Post',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: canPost ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_uploadProgress != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress == 0 ? null : _uploadProgress,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Uploading image… ${((_uploadProgress ?? 0) * 100).round()}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _textController,
                maxLines: 6,
                minLines: 3,
                enabled: !_posting,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 12),
                _ImagePreview(
                  file: _pickedImage!,
                  onRemove: _posting ? null : () => setState(() => _pickedImage = null),
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _posting ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_pickedImage == null ? 'Add photo' : 'Replace photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LeaveChoice { keepEditing, saveDraft, discard }

/// Shows the picked image at its own aspect ratio instead of forcing a
/// fixed height + BoxFit.cover (which stretched/cropped it awkwardly).
/// Clamped to a sane range so an extreme panorama or a very tall
/// screenshot still reads as a normal-looking preview card, matching how
/// Twitter/Instagram-style composers constrain image previews.
class _ImagePreview extends StatelessWidget {
  final File file;
  final VoidCallback? onRemove;
  const _ImagePreview({required this.file, this.onRemove});

  Future<double> _aspectRatioOf(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    return ratio.clamp(0.55, 1.91);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _aspectRatioOf(file),
      builder: (context, snapshot) {
        final ratio = snapshot.data ?? 16 / 10;
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.black.withOpacity(0.04),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
