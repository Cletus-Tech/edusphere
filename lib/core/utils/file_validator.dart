import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import '../../models/app_settings_models.dart';
import 'result.dart';

/// Validates a file against the remotely-configured [UploadSettingsModel]
/// before the Upload Engine ever queues it, and computes the content
/// hash used for duplicate detection. Kept as a stateless set of pure
/// functions so it's trivially testable without a Firebase/Storage
/// dependency.
class FileValidator {
  FileValidator._();

  static Result<void> validate(File file, int sizeBytes, UploadSettingsModel settings) {
    if (sizeBytes <= 0) {
      return const Result.failure('This file appears to be empty.');
    }
    if (sizeBytes > settings.maxFileSizeBytes) {
      return Result.failure(
        'This file is too large. The limit is ${settings.maxFileSizeMb}MB.',
      );
    }
    final extension = extensionOf(file.path);
    if (extension == null || !settings.allowedExtensions.contains(extension)) {
      return Result.failure(
        '.${extension ?? 'unknown'} files aren\'t supported. '
        'Allowed types: ${settings.allowedExtensions.join(', ')}.',
      );
    }
    return const Result.success(null);
  }

  static String? extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return null;
    return path.substring(dot + 1).toLowerCase();
  }

  static String? mimeTypeOf(String path) => lookupMimeType(path);

  /// SHA-256 of the file's bytes — used to detect the user re-selecting
  /// a file they've already uploaded (or already have queued).
  static Future<String> hashOf(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
