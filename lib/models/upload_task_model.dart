import 'package:equatable/equatable.dart';
import '../core/enums/upload_status.dart';
import 'firestore_model.dart';

/// One file moving through the Upload Engine — from queued, through
/// upload (with live progress), to success/failure/cancellation.
///
/// Immutable: the engine holds the current instance in memory and
/// replaces it (via [copyWith]) as state changes, broadcasting the new
/// value on its task stream. On [UploadStatus.success] or
/// [UploadStatus.failed] it's also persisted via
/// [UploadHistoryRepository] so the user can see past uploads even
/// after leaving the screen that started them.
class UploadTaskModel extends Equatable implements FirestoreModel {
  final String taskId;
  final String uid;
  final String localPath;
  final String storagePath;
  final String fileName;
  final int fileSizeBytes;
  final String? mimeType;
  final String? fileHash; // sha256, used for duplicate detection
  final UploadStatus status;
  final double progress; // 0.0–1.0
  final String? errorMessage;
  final String? downloadUrl;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int retryCount;

  const UploadTaskModel({
    required this.taskId,
    required this.uid,
    required this.localPath,
    required this.storagePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.createdAt,
    this.mimeType,
    this.fileHash,
    this.status = UploadStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.downloadUrl,
    this.completedAt,
    this.retryCount = 0,
  });

  factory UploadTaskModel.fromMap(Map<String, dynamic> map, String taskId) {
    return UploadTaskModel(
      taskId: taskId,
      uid: map['uid'] as String? ?? '',
      localPath: map['localPath'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      mimeType: map['mimeType'] as String?,
      fileHash: map['fileHash'] as String?,
      status: UploadStatus.fromId(map['status'] as String? ?? 'failed'),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: map['errorMessage'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
      completedAt: FirestoreConvert.dateTimeOrNull(map['completedAt']),
      retryCount: map['retryCount'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'localPath': localPath,
        'storagePath': storagePath,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'mimeType': mimeType,
        'fileHash': fileHash,
        'status': status.id,
        'progress': progress,
        'errorMessage': errorMessage,
        'downloadUrl': downloadUrl,
        'createdAt': FirestoreConvert.toTimestamp(createdAt),
        'completedAt': completedAt == null ? null : FirestoreConvert.toTimestamp(completedAt!),
        'retryCount': retryCount,
      };

  UploadTaskModel copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    String? downloadUrl,
    DateTime? completedAt,
    int? retryCount,
    String? fileHash,
  }) {
    return UploadTaskModel(
      taskId: taskId,
      uid: uid,
      localPath: localPath,
      storagePath: storagePath,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt,
      mimeType: mimeType,
      fileHash: fileHash ?? this.fileHash,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      // errorMessage intentionally clears unless explicitly passed, so
      // retrying doesn't keep a stale error visible.
      errorMessage: errorMessage,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      completedAt: completedAt ?? this.completedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  String get id => taskId;

  @override
  List<Object?> get props => [taskId, status, progress, errorMessage, downloadUrl];
}
