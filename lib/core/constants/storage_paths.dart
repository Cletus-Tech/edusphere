/// Every Cloud Storage path EduSphere writes to is built here — nothing
/// in a repository, service, or screen should ever write a raw storage
/// path string. This keeps the bucket layout renameable/reorganizable
/// from one place as new modules (marketplace, certificates, etc.) go
/// from "future" to "live".
class StoragePaths {
  StoragePaths._();

  static String userAvatar(String uid) => 'users/$uid/avatar.jpg';
  static String userDocument(String uid, String fileName) =>
      'users/$uid/documents/$fileName';

  static String institutionLogo(String institutionId) =>
      'institutions/$institutionId/logo.png';
  static String institutionBanner(String institutionId, String fileName) =>
      'institutions/$institutionId/banners/$fileName';

  static String courseNote(String courseId, String fileName) =>
      'notes/$courseId/$fileName';
  static String courseVideo(String courseId, String fileName) =>
      'videos/$courseId/$fileName';
  static String courseDocument(String courseId, String fileName) =>
      'documents/$courseId/$fileName';
  static String assignment(String courseId, String fileName) =>
      'assignments/$courseId/$fileName';

  // Stage 3.6.2 — Learning Materials file/thumbnail uploads, kept
  // distinct from courseNote/courseVideo/courseDocument above (which key
  // by courseId) since a learning-content item can be replaced/re-
  // thumbnailed independently of its course.
  static String learningContentFile(String contentId, String fileName) =>
      'learning_content/$contentId/files/$fileName';
  static String learningContentThumbnail(String contentId, String fileName) =>
      'learning_content/$contentId/thumbnail/$fileName';

  // Stage 3.5 — Learning Materials Module. Distinct from
  // learningContentFile/learningContentThumbnail above (Stage 3.6.2's
  // legacy `learning_content` collection, kept read-only during
  // migration) — every new upload goes through these instead.
  static String learningMaterialFile(String materialId, String fileName) =>
      'learning_materials/$materialId/files/$fileName';
  static String learningMaterialThumbnail(String materialId, String fileName) =>
      'learning_materials/$materialId/thumbnail/$fileName';
  static String learningMaterialBanner(String materialId, String fileName) =>
      'learning_materials/$materialId/banner/$fileName';

  static String questionImage(String questionId, String fileName) =>
      'images/questions/$questionId/$fileName';
  static String generalImage(String fileName) => 'images/$fileName';

  static String communityPostMedia(String postId, String fileName) =>
      'community/posts/$postId/$fileName';
  static String communityAvatar(String uid) => 'avatars/$uid.jpg';

  static String appBanner(String bannerId, String fileName) =>
      'banners/$bannerId/$fileName';

  static String certificate(String uid, String certificateId) =>
      'certificates/$uid/$certificateId.pdf';

  static String userDownload(String uid, String fileName) =>
      'downloads/$uid/$fileName';

  static String marketplaceListing(String listingId, String fileName) =>
      'marketplace/$listingId/$fileName';

  // Stage 6.3 — Creator Profile module.
  static String creatorProfileImage(String fileName) => 'creator_profile/profile/$fileName';
  static String creatorCoverImage(String fileName) => 'creator_profile/cover/$fileName';
  static String creatorDocument(String documentId, String fileName) =>
      'creator_profile/documents/$documentId/$fileName';
  static String creatorProjectImage(String projectId, String fileName) =>
      'creator_profile/projects/$projectId/$fileName';

  /// Fallback for one-off/admin uploads that don't fit a helper above yet.
  /// Prefer adding a named helper instead of calling this directly.
  static String custom(String folder, String fileName) => '$folder/$fileName';
}
