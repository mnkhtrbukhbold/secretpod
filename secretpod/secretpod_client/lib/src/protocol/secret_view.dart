/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class SecretView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SecretView._({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.project,
    required this.environment,
    required this.kind,
    required this.description,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.url,
    this.expiresAt,
    bool? needsRotation,
  }) : needsRotation = needsRotation ?? false;

  factory SecretView({
    required String id,
    required String organizationId,
    required String name,
    required String project,
    required String environment,
    required String kind,
    required String description,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? url,
    DateTime? expiresAt,
    bool? needsRotation,
  }) = _SecretViewImpl;

  factory SecretView.fromJson(Map<String, dynamic> jsonSerialization) {
    return SecretView(
      id: jsonSerialization['id'] as String,
      organizationId: jsonSerialization['organizationId'] as String,
      name: jsonSerialization['name'] as String,
      project: jsonSerialization['project'] as String,
      environment: jsonSerialization['environment'] as String,
      kind: jsonSerialization['kind'] as String,
      description: jsonSerialization['description'] as String,
      version: jsonSerialization['version'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      url: jsonSerialization['url'] as String?,
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      needsRotation: jsonSerialization['needsRotation'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['needsRotation']),
    );
  }

  String id;

  String organizationId;

  String name;

  String project;

  String environment;

  String kind;

  String description;

  int version;

  DateTime createdAt;

  DateTime updatedAt;

  String? url;

  DateTime? expiresAt;

  bool needsRotation;

  /// Returns a shallow copy of this [SecretView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SecretView copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? project,
    String? environment,
    String? kind,
    String? description,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? url,
    DateTime? expiresAt,
    bool? needsRotation,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SecretView',
      'id': id,
      'organizationId': organizationId,
      'name': name,
      'project': project,
      'environment': environment,
      'kind': kind,
      'description': description,
      'version': version,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (url != null) 'url': url,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      'needsRotation': needsRotation,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SecretView',
      'id': id,
      'organizationId': organizationId,
      'name': name,
      'project': project,
      'environment': environment,
      'kind': kind,
      'description': description,
      'version': version,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (url != null) 'url': url,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      'needsRotation': needsRotation,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SecretViewImpl extends SecretView {
  _SecretViewImpl({
    required String id,
    required String organizationId,
    required String name,
    required String project,
    required String environment,
    required String kind,
    required String description,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? url,
    DateTime? expiresAt,
    bool? needsRotation,
  }) : super._(
         id: id,
         organizationId: organizationId,
         name: name,
         project: project,
         environment: environment,
         kind: kind,
         description: description,
         version: version,
         createdAt: createdAt,
         updatedAt: updatedAt,
         url: url,
         expiresAt: expiresAt,
         needsRotation: needsRotation,
       );

  /// Returns a shallow copy of this [SecretView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SecretView copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? project,
    String? environment,
    String? kind,
    String? description,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? url = _Undefined,
    Object? expiresAt = _Undefined,
    bool? needsRotation,
  }) {
    return SecretView(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      project: project ?? this.project,
      environment: environment ?? this.environment,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      url: url is String? ? url : this.url,
      expiresAt: expiresAt is DateTime? ? expiresAt : this.expiresAt,
      needsRotation: needsRotation ?? this.needsRotation,
    );
  }
}
