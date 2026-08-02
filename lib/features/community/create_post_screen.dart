import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants/storage_paths.dart';
import '../../core/utils/result.dart';
import '../../models/community_models.dart';
import '../../repositories/community_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// New-post composer. A single optional image, uploaded immediately via
/// [StorageService] once the post has an id — the same
/// small-immediate-upload pattern `MaterialEditorScreen` uses for
/// thumbnails/banners, since a post image doesn't need the full
/// [UploadEngine] queue (progress/pause/resume/retry) a large course
/// file does.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  File? _pickedImage;
  bool _posting = false;

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

  Future<void> _submit() async {
    final text = _textController.text.trim();
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      AppSnackbar.error(context, 'You need to be signed in to post.');
      return;
    }
    if (text.isEmpty && _pickedImage == null) {
      AppSnackbar.error(context, 'Write something or add an image first.');
      return;
    }

    setState(() => _posting = true);

    final postRepository = PostRepository();
    final postId = postRepository.newId();
    var imageUrls = <String>[];

    if (_pickedImage != null) {
      final fileName = _pickedImage!.path.split('/').last;
      final uploadResult = await StorageService().uploadFile(
        path: StoragePaths.communityPostMedia(postId, fileName),
        file: _pickedImage!,
      );
      if (uploadResult.isFailure) {
        if (mounted) {
          setState(() => _posting = false);
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
    setState(() => _posting = false);

    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not publish your post. Please try again.');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: PrimaryButton(label: 'Post', isLoading: _posting, onPressed: _submit),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              maxLines: 6,
              minLines: 3,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),
            if (_pickedImage != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(_pickedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _pickedImage = null),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_pickedImage == null ? 'Add photo' : 'Change photo'),
            ),
          ],
        ),
      ),
    );
  }
}
