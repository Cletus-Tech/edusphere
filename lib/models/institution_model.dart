import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../core/enums/institution_type.dart';
import 'firestore_model.dart';

/// `institutions/{institutionId}` — the top of the academic hierarchy.
/// Faculties/departments/levels/semesters below reference this by id
/// rather than duplicating institution data.
class InstitutionModel extends Equatable implements FirestoreModel {
  final String institutionId;
  final String name;
  final String shortName;
  final InstitutionType type;
  final String? logoUrl;
  final String? state;
  final String? country;
  final bool isActive;
  final List<String> enabledFeatures;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const InstitutionModel({
    required this.institutionId,
    required this.name,
    this.shortName = '',
    required this.type,
    this.logoUrl,
    this.state,
    this.country = 'Nigeria',
    this.isActive = true,
    this.enabledFeatures = const [],
    this.metadata = const {},
    required this.createdAt,
  });

  factory InstitutionModel.fromMap(Map<String, dynamic> map, String institutionId) {
    return InstitutionModel(
      institutionId: institutionId,
      name: map['name'] as String? ?? '',
      shortName: map['shortName'] as String? ?? '',
      type: InstitutionType.fromId(map['type'] as String? ?? ''),
      logoUrl: map['logoUrl'] as String?,
      state: map['state'] as String?,
      country: map['country'] as String? ?? 'Nigeria',
      isActive: map['isActive'] as bool? ?? true,
      enabledFeatures: FirestoreConvert.stringList(map['enabledFeatures']),
      metadata: FirestoreConvert.map(map['metadata']),
      createdAt: FirestoreConvert.dateTime(map['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'name': name,
        'shortName': shortName,
        'type': type.id,
        'logoUrl': logoUrl,
        'state': state,
        'country': country,
        'isActive': isActive,
        'enabledFeatures': enabledFeatures,
        'metadata': metadata,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  String get id => institutionId;

  @override
  List<Object?> get props => [institutionId, name, type, isActive];
}

/// Shared shape for `faculties`, `departments`, `levels`, and `semesters`
/// — each is a thin node in the academic tree, distinguished by
/// `parentId`/`parentCollection` rather than four near-identical classes.
class AcademicNodeModel extends Equatable implements FirestoreModel {
  final String nodeId;
  final String institutionId;
  final String? parentId;
  final String name;
  final String? code;
  final int order;
  final bool isActive;

  const AcademicNodeModel({
    required this.nodeId,
    required this.institutionId,
    this.parentId,
    required this.name,
    this.code,
    this.order = 0,
    this.isActive = true,
  });

  factory AcademicNodeModel.fromMap(Map<String, dynamic> map, String nodeId) {
    return AcademicNodeModel(
      nodeId: nodeId,
      institutionId: map['institutionId'] as String? ?? '',
      parentId: map['parentId'] as String?,
      name: map['name'] as String? ?? '',
      code: map['code'] as String?,
      order: map['order'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'institutionId': institutionId,
        'parentId': parentId,
        'name': name,
        'code': code,
        'order': order,
        'isActive': isActive,
      };

  @override
  String get id => nodeId;

  @override
  List<Object?> get props => [nodeId, institutionId, parentId, name];
}
