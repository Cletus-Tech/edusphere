import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import '../../core/enums/upload_status.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/file_validator.dart';
import '../../core/utils/result.dart';
import '../../models/app_settings_models.dart';
import '../../models/upload_task_model.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/upload_history_repository.dart';

/// The single reusable upload pipeline for EduSphere.
///
/// Every feature that lets a user attach a file — course notes,
/// assignments, community media, avatars, certificates — should queue
/// through [UploadEngine.instance] rather than calling
/// `FirebaseStorage`/`StorageService` directly. That gives every one of
/// those features, for free: live progress, pause/resume/cancel,
/// automatic retry-by-request, size/type validation against remote
/// [UploadSettingsModel] limits, duplicate detection, and a persisted
/// history — instead of each screen reimplementing a subset of this.
///
/// `StorageRepository`/`StorageService` still exist underneath and are
/// used by this engine to do the actual `putFile` call — no second copy
/// of upload logic, just a queue/control layer on top.
class UploadEngine {
  UploadEngine._();
  static final UploadEngine instance = UploadEngine._();

  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UploadHistoryRepository _historyRepository = UploadHistoryRepository();
  final fb_storage.FirebaseStorage _storage = fb_storage.FirebaseStorage.instance;

  UploadSettingsModel _settings = const UploadSettingsModel();
  StreamSubscription<UploadSettingsModel>? _settingsSub;

  final Map<String, UploadTaskModel> _tasks = {};
  final List<String> _order = [];
  final Map<String, fb_storage.UploadTask> _activeStorageTasks = {};
  final Map<String, String> _sessionHashKeys = {}; // "storagePath:hash" -> taskId

  final _controller = StreamController<List<UploadTaskModel>>.broadcast();

  /// Starts listening for remote upload-limit changes. Call once at
  /// app startup, after Firebase initializes.
  void start() {
    _settingsSub ??= _settingsRepository.watchUploadSettings().listen((s) => _settings = s);
  }

  void dispose() {
    _settingsSub?.cancel();
    _settingsSub = null;
  }

  Stream<List<UploadTaskModel>> watchTasks() => _controller.stream;

  List<UploadTaskModel> get tasks => _order.map((id) => _tasks[id]!).toList();

  /// Queues [file] for upload to [storagePath]. Validates size/type
  /// against the current [UploadSettingsModel], checks for a duplicate
  /// already queued this session (or already uploaded, unless
  /// [allowDuplicate] is true), then adds it to the queue and kicks off
  /// processing (respecting `maxConcurrentUploads`).
  Future<Result<UploadTaskModel>> enqueue({
    required File file,
    required String storagePath,
    required String uid,
    bool allowDuplicate = false,
  }) async {
    if (!await file.exists()) {
      return const Result.failure("That file couldn't be found on this device.");
    }

    final sizeBytes = await file.length();
    final validation = FileValidator.validate(file, sizeBytes, _settings);
    if (validation case Failure(message: final msg)) {
      return Result.failure(msg);
    }

    final hash = await FileValidator.hashOf(file);
    final dedupKey = '$storagePath:$hash';

    if (!allowDuplicate) {
      final existingId = _sessionHashKeys[dedupKey];
      if (existingId != null && _tasks[existingId] != null) {
        AppLogger.info('Duplicate upload skipped for $storagePath', tag: 'upload_engine');
        return Result.success(_tasks[existingId]!);
      }
      final priorUpload = await _historyRepository.findByHash(uid, hash);
      if (priorUpload != null) {
        return const Result.failure('You already uploaded this file.');
      }
    }

    final taskId = _historyRepository.newId();
    final task = UploadTaskModel(
      taskId: taskId,
      uid: uid,
      localPath: file.path,
      storagePath: storagePath,
      fileName: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : taskId,
      fileSizeBytes: sizeBytes,
      mimeType: FileValidator.mimeTypeOf(file.path),
      fileHash: hash,
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    _order.add(taskId);
    _sessionHashKeys[dedupKey] = taskId;
    _emit();

    unawaited(_processQueue());
    return Result.success(task);
  }

  void pause(String taskId) {
    _activeStorageTasks[taskId]?.pause();
    _update(taskId, (t) => t.copyWith(status: UploadStatus.paused));
  }

  void resume(String taskId) {
    final storageTask = _activeStorageTasks[taskId];
    if (storageTask != null) {
      storageTask.resume();
      _update(taskId, (t) => t.copyWith(status: UploadStatus.uploading));
    } else {
      // Was paused before it ever started (still in queue) — just let
      // the queue pick it back up.
      _update(taskId, (t) => t.copyWith(status: UploadStatus.queued));
      unawaited(_processQueue());
    }
  }

  Future<void> cancel(String taskId) async {
    final storageTask = _activeStorageTasks[taskId];
    if (storageTask != null) {
      await storageTask.cancel();
      _activeStorageTasks.remove(taskId);
    } else {
      _update(taskId, (t) => t.copyWith(status: UploadStatus.cancelled));
    }
    unawaited(_processQueue());
  }

  /// Re-queues a failed or cancelled upload. Does not re-read the file
  /// from disk — the original [UploadTaskModel.localPath] is reused.
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    _update(
      taskId,
      (t) => t.copyWith(
        status: UploadStatus.queued,
        progress: 0,
        retryCount: t.retryCount + 1,
      ),
    );
    unawaited(_processQueue());
  }

  void clearCompleted() {
    _order.removeWhere((id) => _tasks[id]?.status.isTerminal ?? true);
    _tasks.removeWhere((_, t) => t.status.isTerminal);
    _emit();
  }

  Future<void> _processQueue() async {
    final activeCount = _tasks.values.where((t) => t.status == UploadStatus.uploading).length;
    var slotsAvailable = _settings.maxConcurrentUploads - activeCount;
    if (slotsAvailable <= 0) return;

    for (final id in List<String>.from(_order)) {
      if (slotsAvailable <= 0) break;
      final task = _tasks[id];
      if (task == null || task.status != UploadStatus.queued) continue;
      slotsAvailable--;
      unawaited(_upload(task));
    }
  }

  Future<void> _upload(UploadTaskModel task) async {
    _update(task.taskId, (t) => t.copyWith(status: UploadStatus.uploading));

    try {
      final ref = _storage.ref().child(task.storagePath);
      final storageTask = ref.putFile(File(task.localPath));
      _activeStorageTasks[task.taskId] = storageTask;

      storageTask.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final progress = total > 0 ? snapshot.bytesTransferred / total : 0.0;
        final isPaused = snapshot.state == fb_storage.TaskState.paused;
        _update(
          task.taskId,
          (t) => t.copyWith(
            progress: progress,
            status: isPaused ? UploadStatus.paused : UploadStatus.uploading,
          ),
        );
      }, onError: (_) {});

      final snapshot = await storageTask;
      final url = await snapshot.ref.getDownloadURL();

      _update(
        task.taskId,
        (t) => t.copyWith(
          status: UploadStatus.success,
          progress: 1.0,
          downloadUrl: url,
          completedAt: DateTime.now(),
        ),
      );
      AppLogger.info('Upload succeeded: ${task.storagePath}', tag: 'upload_engine');
    } catch (e) {
      final wasCancelled = e is fb_storage.FirebaseException && e.code == 'canceled';
      _update(
        task.taskId,
        (t) => t.copyWith(
          status: wasCancelled ? UploadStatus.cancelled : UploadStatus.failed,
          errorMessage: wasCancelled ? null : "Upload failed. You can retry when you're ready.",
        ),
      );
      AppLogger.error('Upload failed: ${task.storagePath}', tag: 'upload_engine', error: e);
    } finally {
      _activeStorageTasks.remove(task.taskId);
      final finalTask = _tasks[task.taskId];
      if (finalTask != null && finalTask.status.isTerminal) {
        unawaited(_historyRepository.save(finalTask));
      }
      unawaited(_processQueue());
    }
  }

  void _update(String taskId, UploadTaskModel Function(UploadTaskModel) transform) {
    final current = _tasks[taskId];
    if (current == null) return;
    _tasks[taskId] = transform(current);
    _emit();
  }

  void _emit() {
    if (_controller.hasListener) _controller.add(tasks);
  }
}
