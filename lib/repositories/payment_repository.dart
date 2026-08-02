import '../core/constants/app_constants.dart';
import '../models/payment_models.dart';
import 'base_repository.dart';

class PaymentRepository extends BaseRepository<PaymentMethodModel> {
  PaymentRepository() : super(AppConstants.paymentMethodsCollection);

  @override
  PaymentMethodModel fromMap(Map<String, dynamic> map, String id) =>
      PaymentMethodModel.fromMap(map, id);

  /// Only active, currently-usable payment methods, in admin-defined order.
  Stream<List<PaymentMethodModel>> watchActive() {
    return streamCollection(
      query: (q) => q.where('status', isEqualTo: PaymentMethodStatus.active.id).orderBy('sortOrder'),
    );
  }
}
