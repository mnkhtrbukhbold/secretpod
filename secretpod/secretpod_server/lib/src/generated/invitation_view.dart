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
import 'package:secretpod_server/src/generated/protocol.dart' as _ii063q5q;
import 'package:serverpod/serverpod.dart' as _is;

abstract class InvitationView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  InvitationView._({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.inviterName,
    required this.inviterEmail,
    required this.recipientEmail,
    required this.recipientName,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
    this.readProjects,
    this.writeProjects,
    this.deniedReadProjects,
    this.deniedWriteProjects,
    this.canCreateProjects,
  });

  factory InvitationView({
    required String id,
    required String organizationId,
    required String organizationName,
    required String inviterName,
    required String inviterEmail,
    required String recipientEmail,
    required String recipientName,
    required String role,
    required String status,
    required DateTime createdAt,
    required DateTime expiresAt,
    DateTime? respondedAt,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) = _InvitationViewImpl;

  factory InvitationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return InvitationView(
      id: jsonSerialization['id'] as String,
      organizationId: jsonSerialization['organizationId'] as String,
      organizationName: jsonSerialization['organizationName'] as String,
      inviterName: jsonSerialization['inviterName'] as String,
      inviterEmail: jsonSerialization['inviterEmail'] as String,
      recipientEmail: jsonSerialization['recipientEmail'] as String,
      recipientName: jsonSerialization['recipientName'] as String,
      role: jsonSerialization['role'] as String,
      status: jsonSerialization['status'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      respondedAt: jsonSerialization['respondedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['respondedAt'],
            ),
      readProjects: jsonSerialization['readProjects'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<List<String>>(
              jsonSerialization['readProjects'],
            ),
      writeProjects: jsonSerialization['writeProjects'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<List<String>>(
              jsonSerialization['writeProjects'],
            ),
      deniedReadProjects: jsonSerialization['deniedReadProjects'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<List<String>>(
              jsonSerialization['deniedReadProjects'],
            ),
      deniedWriteProjects: jsonSerialization['deniedWriteProjects'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<List<String>>(
              jsonSerialization['deniedWriteProjects'],
            ),
      canCreateProjects: jsonSerialization['canCreateProjects'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['canCreateProjects'],
            ),
    );
  }

  String id;

  String organizationId;

  String organizationName;

  String inviterName;

  String inviterEmail;

  String recipientEmail;

  String recipientName;

  String role;

  String status;

  DateTime createdAt;

  DateTime expiresAt;

  DateTime? respondedAt;

  List<String>? readProjects;

  List<String>? writeProjects;

  List<String>? deniedReadProjects;

  List<String>? deniedWriteProjects;

  bool? canCreateProjects;

  /// Returns a shallow copy of this [InvitationView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  InvitationView copyWith({
    String? id,
    String? organizationId,
    String? organizationName,
    String? inviterName,
    String? inviterEmail,
    String? recipientEmail,
    String? recipientName,
    String? role,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? respondedAt,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InvitationView',
      'id': id,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'inviterName': inviterName,
      'inviterEmail': inviterEmail,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'role': role,
      'status': status,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      if (respondedAt != null) 'respondedAt': respondedAt?.toJson(),
      if (readProjects != null) 'readProjects': readProjects?.toJson(),
      if (writeProjects != null) 'writeProjects': writeProjects?.toJson(),
      if (deniedReadProjects != null)
        'deniedReadProjects': deniedReadProjects?.toJson(),
      if (deniedWriteProjects != null)
        'deniedWriteProjects': deniedWriteProjects?.toJson(),
      if (canCreateProjects != null) 'canCreateProjects': canCreateProjects,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InvitationView',
      'id': id,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'inviterName': inviterName,
      'inviterEmail': inviterEmail,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'role': role,
      'status': status,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      if (respondedAt != null) 'respondedAt': respondedAt?.toJson(),
      if (readProjects != null) 'readProjects': readProjects?.toJson(),
      if (writeProjects != null) 'writeProjects': writeProjects?.toJson(),
      if (deniedReadProjects != null)
        'deniedReadProjects': deniedReadProjects?.toJson(),
      if (deniedWriteProjects != null)
        'deniedWriteProjects': deniedWriteProjects?.toJson(),
      if (canCreateProjects != null) 'canCreateProjects': canCreateProjects,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InvitationViewImpl extends InvitationView {
  _InvitationViewImpl({
    required String id,
    required String organizationId,
    required String organizationName,
    required String inviterName,
    required String inviterEmail,
    required String recipientEmail,
    required String recipientName,
    required String role,
    required String status,
    required DateTime createdAt,
    required DateTime expiresAt,
    DateTime? respondedAt,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) : super._(
         id: id,
         organizationId: organizationId,
         organizationName: organizationName,
         inviterName: inviterName,
         inviterEmail: inviterEmail,
         recipientEmail: recipientEmail,
         recipientName: recipientName,
         role: role,
         status: status,
         createdAt: createdAt,
         expiresAt: expiresAt,
         respondedAt: respondedAt,
         readProjects: readProjects,
         writeProjects: writeProjects,
         deniedReadProjects: deniedReadProjects,
         deniedWriteProjects: deniedWriteProjects,
         canCreateProjects: canCreateProjects,
       );

  /// Returns a shallow copy of this [InvitationView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  InvitationView copyWith({
    String? id,
    String? organizationId,
    String? organizationName,
    String? inviterName,
    String? inviterEmail,
    String? recipientEmail,
    String? recipientName,
    String? role,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    Object? respondedAt = _Undefined,
    Object? readProjects = _Undefined,
    Object? writeProjects = _Undefined,
    Object? deniedReadProjects = _Undefined,
    Object? deniedWriteProjects = _Undefined,
    Object? canCreateProjects = _Undefined,
  }) {
    return InvitationView(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      inviterName: inviterName ?? this.inviterName,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientName: recipientName ?? this.recipientName,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      respondedAt: respondedAt is DateTime? ? respondedAt : this.respondedAt,
      readProjects: readProjects is List<String>?
          ? readProjects
          : this.readProjects?.map((e0) => e0).toList(),
      writeProjects: writeProjects is List<String>?
          ? writeProjects
          : this.writeProjects?.map((e0) => e0).toList(),
      deniedReadProjects: deniedReadProjects is List<String>?
          ? deniedReadProjects
          : this.deniedReadProjects?.map((e0) => e0).toList(),
      deniedWriteProjects: deniedWriteProjects is List<String>?
          ? deniedWriteProjects
          : this.deniedWriteProjects?.map((e0) => e0).toList(),
      canCreateProjects: canCreateProjects is bool?
          ? canCreateProjects
          : this.canCreateProjects,
    );
  }
}
