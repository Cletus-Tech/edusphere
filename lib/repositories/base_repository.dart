import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/result.dart';
import '../models/firestore_model.dart';
import '../services/firebase/firestore_service.dart';

/// Generic CRUD over one Firestore collection for a given model type.
/// Feature repositories extend this instead of talking to
/// [FirestoreService] (or `FirebaseFirestore.instance`) directly, so
/// business logic never lives inside UI widgets — per the Stage 1.2
/// "Repository Pattern" requirement.
abstract class BaseRepository<T extends FirestoreModel> {
  BaseRepository(this.collection);

  final String collection;
  final FirestoreService _firestoreService = FirestoreService();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Rehydrates a model from a raw Firestore map. Implemented by each
  /// concrete repository since only it knows its model's `fromMap`.
  T fromMap(Map<String, dynamic> map, String id);

  Future<Result<void>> save(T model) => _firestoreService.set(
        collection: collection,
        docId: model.id,
        data: model.toMap(),
      );

  Future<Result<T?>> getById(String id) async {
    final result = await _firestoreService.getDoc(collection: collection, docId: id);
    return switch (result) {
      Success(data: final data) => Result.success(data == null ? null : fromMap(data, id)),
      Failure(message: final message) => Result.failure(message),
    };
  }

  Stream<T?> streamById(String id) {
    return _firestoreService.streamDoc(collection: collection, docId: id).map(
          (snap) => snap.exists ? fromMap(snap.data()!, snap.id) : null,
        );
  }

  Stream<List<T>> streamCollection({
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? query,
    int? limit,
  }) {
    return _firestoreService
        .streamCollection(collection: collection, query: query, limit: limit)
        .map((snap) => snap.docs.map((d) => fromMap(d.data(), d.id)).toList());
  }

  Future<Result<List<T>>> getWhere({
    required Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>) query,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> ref = _db.collection(collection);
      ref = query(ref);
      if (limit != null) ref = ref.limit(limit);
      final snapshot = await ref.get();
      return Result.success(snapshot.docs.map((d) => fromMap(d.data(), d.id)).toList());
    } catch (e) {
      return resultFailureFrom(e);
    }
  }

  Future<Result<void>> delete(String id) => _firestoreService.delete(collection: collection, docId: id);

  /// Auto-generates a Firestore-assigned id, useful for `add`-style
  /// creates (posts, comments, reports, ai_history, ...).
  String newId() => _db.collection(collection).doc().id;
}
