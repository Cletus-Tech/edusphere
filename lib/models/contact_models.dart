import 'package:equatable/equatable.dart';
import 'firestore_model.dart';

/// Which part of EduSphere a contact item belongs to. Drives which
/// section of the in-app Contact Center it's grouped under.
enum ContactCategory {
  owner,
  company,
  support,
  marketing,
  admissions,
  payments,
  emergency;

  String get id => name;

  static ContactCategory fromId(String id) => ContactCategory.values.firstWhere(
        (c) => c.id == id,
        orElse: () => ContactCategory.support,
      );
}

/// How a contact item's [ContactItemModel.value] should be handled when
/// tapped. Maps 1:1 onto [SmartLinkType] in the Smart Links Engine, kept
/// as a separate enum here since not every action is a "link" (e.g. a
/// plain copy-to-clipboard address).
enum ContactAction {
  call,
  whatsapp,
  email,
  sms,
  website,
  facebook,
  instagram,
  youtube,
  tiktok,
  twitter,
  linkedin,
  telegram,
  googleMaps,
  copyOnly;

  String get id => name;

  static ContactAction fromId(String id) => ContactAction.values.firstWhere(
        (a) => a.id == id,
        orElse: () => ContactAction.copyOnly,
      );
}

/// `contacts/{contactId}` — one reachable contact point (a phone
/// number, an email, a social handle...) under one [ContactCategory].
/// Every field an admin should be able to edit without an app update:
/// icon, title, the raw value, what tapping it should do, whether it's
/// currently shown, and its position in the list.
class ContactItemModel extends Equatable implements FirestoreModel {
  final String contactId;
  final ContactCategory category;
  final String iconName;
  final String title;
  final String value;
  final ContactAction action;
  final bool isVisible;
  final int sortOrder;
  final String? subtitle;

  const ContactItemModel({
    required this.contactId,
    required this.category,
    required this.iconName,
    required this.title,
    required this.value,
    required this.action,
    this.isVisible = true,
    this.sortOrder = 0,
    this.subtitle,
  });

  factory ContactItemModel.fromMap(Map<String, dynamic> map, String contactId) {
    return ContactItemModel(
      contactId: contactId,
      category: ContactCategory.fromId(map['category'] as String? ?? 'support'),
      iconName: map['iconName'] as String? ?? 'help_outline',
      title: map['title'] as String? ?? '',
      value: map['value'] as String? ?? '',
      action: ContactAction.fromId(map['action'] as String? ?? 'copyOnly'),
      isVisible: map['isVisible'] as bool? ?? true,
      sortOrder: map['sortOrder'] as int? ?? 0,
      subtitle: map['subtitle'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'category': category.id,
        'iconName': iconName,
        'title': title,
        'value': value,
        'action': action.id,
        'isVisible': isVisible,
        'sortOrder': sortOrder,
        'subtitle': subtitle,
      };

  @override
  String get id => contactId;

  @override
  List<Object?> get props => [contactId, category, title, value, action, isVisible, sortOrder];
}
