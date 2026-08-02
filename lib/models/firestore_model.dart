import 'package:cloud_firestore/cloud_firestore.dart';

/// Every backend model implements this so repositories can persist and
/// rehydrate documents generically (see `BaseRepository`).
abstract class FirestoreModel {
  String get id;
  Map<String, dynamic> toMap();
}

/// Small helpers so every model converts Firestore Timestamps the same
/// way instead of each file reinventing null-handling.
class FirestoreConvert {
  FirestoreConvert._();

  static DateTime dateTime(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return fallback ?? DateTime.now();
  }

  static DateTime? dateTimeOrNull(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String> stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  static Timestamp toTimestamp(DateTime value) => Timestamp.fromDate(value);

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
