import 'dart:io';
import '../core/constants/storage_paths.dart';
import '../core/utils/result.dart';
import '../services/firebase/storage_service.dart';

/// Thin façade over [StorageService] that forces every upload to go
/// through a named [StoragePaths] helper — no feature module builds a
/// storage path by hand.
class StorageRepository {
  final StorageService _storageService = StorageService();

  Future<Result<String>> uploadUserAvatar(String uid, File file, {void Function(double)? onProgress}) {
    return _storageService.uploadFile(path: StoragePaths.userAvatar(uid), file: file, onProgress: onProgress);
  }

  Future<Result<String>> uploadCourseNote(String courseId, String fileName, File file,
      {void Function(double)? onProgress}) {
    return _storageService.uploadFile(
      path: StoragePaths.courseNote(courseId, fileName),
      file: file,
      onProgress: onProgress,
    );
  }

  Future<Result<String>> uploadCourseVideo(String courseId, String fileName, File file,
      {void Function(double)? onProgress}) {
    return _storageService.uploadFile(
      path: StoragePaths.courseVideo(courseId, fileName),
      file: file,
      onProgress: onProgress,
    );
  }

  Future<Result<String>> uploadCommunityPostMedia(String postId, String fileName, File file,
      {void Function(double)? onProgress}) {
    return _storageService.uploadFile(
      path: StoragePaths.communityPostMedia(postId, fileName),
      file: file,
      onProgress: onProgress,
    );
  }

  Future<Result<String>> uploadInstitutionLogo(String institutionId, File file,
      {void Function(double)? onProgress}) {
    return _storageService.uploadFile(
      path: StoragePaths.institutionLogo(institutionId),
      file: file,
      onProgress: onProgress,
    );
  }

  Future<Result<String>> uploadAppBanner(String bannerId, String fileName, File file,
      {void Function(double)? onProgress}) {
    return _storageService.uploadFile(
      path: StoragePaths.appBanner(bannerId, fileName),
      file: file,
      onProgress: onProgress,
    );
  }

  Future<Result<void>> deleteAt(String path) => _storageService.deleteFile(path);
}
