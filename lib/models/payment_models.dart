import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// The rail a [PaymentMethodModel] uses. Every current and future
/// provider is a value here, never a bespoke screen per provider.
enum PaymentProvider {
  bankTransfer,
  paystack,
  flutterwave,
  stripe,
  paypal,
  mobileMoney,
  other;

  String get id => name;

  static PaymentProvider fromId(String id) => PaymentProvider.values.firstWhere(
        (p) => p.id == id,
        orElse: () => PaymentProvider.other,
      );
}

enum PaymentMethodStatus {
  active,
  inactive,
  comingSoon;

  String get id => name;

  static PaymentMethodStatus fromId(String id) => PaymentMethodStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => PaymentMethodStatus.inactive,
      );
}

/// `payment_methods/{paymentMethodId}` — one configurable way to pay
/// EduSphere (or an institution operating on it). Nothing about
/// payment details is hardcoded in the app; the Control Center manages
/// unlimited methods across bank transfer, card gateways, PayPal,
/// mobile money, and whatever rail comes next.
class PaymentMethodModel extends Equatable implements FirestoreModel {
  final String paymentMethodId;
  final String name;
  final String? logoUrl;
  final String? description;
  final String currency;
  final PaymentMethodStatus status;
  final PaymentProvider provider;
  final int sortOrder;

  // Bank-transfer-specific fields — null/unused for gateway providers.
  final String? accountName;
  final String? accountNumber;
  final String? bankName;
  final String? qrCodeUrl;

  // Gateway-specific fields (Paystack/Flutterwave/Stripe/PayPal).
  final String? publicKey;
  final String? gatewayLink;

  final String? instructions;

  const PaymentMethodModel({
    required this.paymentMethodId,
    required this.name,
    required this.currency,
    required this.provider,
    this.logoUrl,
    this.description,
    this.status = PaymentMethodStatus.inactive,
    this.sortOrder = 0,
    this.accountName,
    this.accountNumber,
    this.bankName,
    this.qrCodeUrl,
    this.publicKey,
    this.gatewayLink,
    this.instructions,
  });

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map, String paymentMethodId) {
    return PaymentMethodModel(
      paymentMethodId: paymentMethodId,
      name: map['name'] as String? ?? '',
      currency: map['currency'] as String? ?? 'NGN',
      provider: PaymentProvider.fromId(map['provider'] as String? ?? 'other'),
      logoUrl: map['logoUrl'] as String?,
      description: map['description'] as String?,
      status: PaymentMethodStatus.fromId(map['status'] as String? ?? 'inactive'),
      sortOrder: map['sortOrder'] as int? ?? 0,
      accountName: map['accountName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      bankName: map['bankName'] as String?,
      qrCodeUrl: map['qrCodeUrl'] as String?,
      publicKey: map['publicKey'] as String?,
      gatewayLink: map['gatewayLink'] as String?,
      instructions: map['instructions'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'currency': currency,
        'provider': provider.id,
        'logoUrl': logoUrl,
        'description': description,
        'status': status.id,
        'sortOrder': sortOrder,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'bankName': bankName,
        'qrCodeUrl': qrCodeUrl,
        'publicKey': publicKey,
        'gatewayLink': gatewayLink,
        'instructions': instructions,
      };

  bool get isActive => status == PaymentMethodStatus.active;

  @override
  String get id => paymentMethodId;

  @override
  List<Object?> get props => [paymentMethodId, name, provider, status, sortOrder];
}
