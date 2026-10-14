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

abstract class AccountView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AccountView._({
    required this.id,
    required this.name,
    required this.email,
    this.invitationPolicy,
    this.themeMode,
  });

  factory AccountView({
    required String id,
    required String name,
    required String email,
    String? invitationPolicy,
    String? themeMode,
  }) = _AccountViewImpl;

  factory AccountView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccountView(
      id: jsonSerialization['id'] as String,
      name: jsonSerialization['name'] as String,
      email: jsonSerialization['email'] as String,
      invitationPolicy: jsonSerialization['invitationPolicy'] as String?,
      themeMode: jsonSerialization['themeMode'] as String?,
    );
  }

  String id;

  String name;

  String email;

  String? invitationPolicy;

  String? themeMode;

  /// Returns a shallow copy of this [AccountView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AccountView copyWith({
    String? id,
    String? name,
    String? email,
    String? invitationPolicy,
    String? themeMode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccountView',
      'id': id,
      'name': name,
      'email': email,
      if (invitationPolicy != null) 'invitationPolicy': invitationPolicy,
      if (themeMode != null) 'themeMode': themeMode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccountView',
      'id': id,
      'name': name,
      'email': email,
      if (invitationPolicy != null) 'invitationPolicy': invitationPolicy,
      if (themeMode != null) 'themeMode': themeMode,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AccountViewImpl extends AccountView {
  _AccountViewImpl({
    required String id,
    required String name,
    required String email,
    String? invitationPolicy,
    String? themeMode,
  }) : super._(
         id: id,
         name: name,
         email: email,
         invitationPolicy: invitationPolicy,
         themeMode: themeMode,
       );

  /// Returns a shallow copy of this [AccountView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AccountView copyWith({
    String? id,
    String? name,
    String? email,
    Object? invitationPolicy = _Undefined,
    Object? themeMode = _Undefined,
  }) {
    return AccountView(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      invitationPolicy: invitationPolicy is String?
          ? invitationPolicy
          : this.invitationPolicy,
      themeMode: themeMode is String? ? themeMode : this.themeMode,
    );
  }
}
