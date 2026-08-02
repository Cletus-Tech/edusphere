import '../core/constants/app_constants.dart';
import '../models/contact_models.dart';
import 'base_repository.dart';

class ContactRepository extends BaseRepository<ContactItemModel> {
  ContactRepository() : super(AppConstants.contactsCollection);

  @override
  ContactItemModel fromMap(Map<String, dynamic> map, String id) =>
      ContactItemModel.fromMap(map, id);

  /// All visible contacts, ordered for display within their category.
  Stream<List<ContactItemModel>> watchVisible() {
    return streamCollection(
      query: (q) => q.where('isVisible', isEqualTo: true).orderBy('sortOrder'),
    );
  }

  /// Visible contacts for one category only (e.g. the Support screen).
  Stream<List<ContactItemModel>> watchByCategory(ContactCategory category) {
    return streamCollection(
      query: (q) => q
          .where('isVisible', isEqualTo: true)
          .where('category', isEqualTo: category.id)
          .orderBy('sortOrder'),
    );
  }
}
