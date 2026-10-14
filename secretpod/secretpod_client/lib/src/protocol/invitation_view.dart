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

abstract class InvitationView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      respondedAt: jsonSerialization['respondedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['respondedAt'],
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

  /// Returns a shallow copy of this [InvitationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
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
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
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
       );

  /// Returns a shallow copy of this [InvitationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
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
    );
  }
}
