import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/utils/result.dart';

/// Handles all Cloud Storage uploads — profile photos today; course
/// materials, community media, and certificates in future modules.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Result<String>> uploadFile({
    required String path,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final task = ref.putFile(file);

      if (onProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      return Result.success(url);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  Future<Result<void>> deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(e.toString());
    }
  }
}
