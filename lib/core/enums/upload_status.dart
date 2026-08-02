/// Lifecycle of one item in the Upload Engine's queue.
enum UploadStatus {
  queued,
  uploading,
  paused,
  success,
  failed,
  cancelled;

  String get id => name;

  static UploadStatus fromId(String id) => UploadStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => UploadStatus.failed,
      );

  bool get isTerminal => this == success || this == failed || this == cancelled;
  bool get isActive => this == queued || this == uploading || this == paused;
}
