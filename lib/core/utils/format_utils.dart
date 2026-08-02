/// Pure-Dart display formatting shared across the Learning Content
/// System (and reusable by later stages — Downloads, Admin Upload,
/// Analytics — so nothing re-implements byte/duration math).
///
/// Deliberately dependency-free: the project trims the `intl` package
/// (see README changelog), so date formatting here is hand-rolled
/// rather than pulling it back in for one feature.
class FormatUtils {
  FormatUtils._();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `1.2 MB`, `340 KB`, `18 B` — 0 or negative renders as `--`.
  static String fileSize(int bytes) {
    if (bytes <= 0) return '--';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final precision = unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  /// `12:05` or `1:02:33` for durations under/over an hour.
  static String duration(int totalSeconds) {
    if (totalSeconds <= 0) return '--';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// `24 pages` / `1 page`.
  static String pageCount(int pages) => pages == 1 ? '1 page' : '$pages pages';

  /// `Jul 31, 2026`.
  static String date(DateTime value) => '${_months[value.month - 1]} ${value.day}, ${value.year}';

  /// `Jul 31, 2026, 3:45 PM` — [date] doesn't carry time-of-day, which
  /// the Stage 3.6.1 Audit Log needs for precise event ordering.
  static String dateTime(DateTime value) {
    final hour24 = value.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '${date(value)}, $hour12:$minute $period';
  }

  /// `Today`, `Yesterday`, `3 days ago`, or a short date beyond that —
  /// used for "Upload date" / "Last opened" so recent activity reads at
  /// a glance without pulling in a relative-time package.
  static String relative(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final days = today.difference(target).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < 7) return '$days days ago';
    return date(value);
  }
}
