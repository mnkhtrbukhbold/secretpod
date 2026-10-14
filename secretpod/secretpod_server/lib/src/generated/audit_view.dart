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
import 'package:serverpod/serverpod.dart' as _is;

abstract class AuditView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AuditView._({
    required this.id,
    required this.actor,
    required this.action,
    required this.target,
    required this.createdAt,
    this.secretId,
    this.actorId,
    this.version,
    this.details,
  });

  factory AuditView({
    required String id,
    required String actor,
    required String action,
    required String target,
    required DateTime createdAt,
    String? secretId,
    String? actorId,
    int? version,
    String? details,
  }) = _AuditViewImpl;

  factory AuditView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AuditView(
      id: jsonSerialization['id'] as String,
      actor: jsonSerialization['actor'] as String,
      action: jsonSerialization['action'] as String,
      target: jsonSerialization['target'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      secretId: jsonSerialization['secretId'] as String?,
      actorId: jsonSerialization['actorId'] as String?,
      version: jsonSerialization['version'] as int?,
      details: jsonSerialization['details'] as String?,
    );
  }

  String id;

  String actor;

  String action;

  String target;

  DateTime createdAt;

  String? secretId;

  String? actorId;

  int? version;

  String? details;

  /// Returns a shallow copy of this [AuditView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AuditView copyWith({
    String? id,
    String? actor,
    String? action,
    String? target,
    DateTime? createdAt,
    String? secretId,
    String? actorId,
    int? version,
    String? details,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AuditView',
      'id': id,
      'actor': actor,
      'action': action,
      'target': target,
      'createdAt': createdAt.toJson(),
      if (secretId != null) 'secretId': secretId,
      if (actorId != null) 'actorId': actorId,
      if (version != null) 'version': version,
      if (details != null) 'details': details,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AuditView',
      'id': id,
      'actor': actor,
      'action': action,
      'target': target,
      'createdAt': createdAt.toJson(),
      if (secretId != null) 'secretId': secretId,
      if (actorId != null) 'actorId': actorId,
      if (version != null) 'version': version,
      if (details != null) 'details': details,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AuditViewImpl extends AuditView {
  _AuditViewImpl({
    required String id,
    required String actor,
    required String action,
    required String target,
    required DateTime createdAt,
    String? secretId,
    String? actorId,
    int? version,
    String? details,
  }) : super._(
         id: id,
         actor: actor,
         action: action,
         target: target,
         createdAt: createdAt,
         secretId: secretId,
         actorId: actorId,
         version: version,
         details: details,
       );

  /// Returns a shallow copy of this [AuditView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AuditView copyWith({
    String? id,
    String? actor,
    String? action,
    String? target,
    DateTime? createdAt,
    Object? secretId = _Undefined,
    Object? actorId = _Undefined,
    Object? version = _Undefined,
    Object? details = _Undefined,
  }) {
    return AuditView(
      id: id ?? this.id,
      actor: actor ?? this.actor,
      action: action ?? this.action,
      target: target ?? this.target,
      createdAt: createdAt ?? this.createdAt,
      secretId: secretId is String? ? secretId : this.secretId,
      actorId: actorId is String? ? actorId : this.actorId,
      version: version is int? ? version : this.version,
      details: details is String? ? details : this.details,
    );
  }
}
