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

abstract class SecretFields
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SecretFields._({
    required this.value,
    this.username,
  });

  factory SecretFields({
    required String value,
    String? username,
  }) = _SecretFieldsImpl;

  factory SecretFields.fromJson(Map<String, dynamic> jsonSerialization) {
    return SecretFields(
      value: jsonSerialization['value'] as String,
      username: jsonSerialization['username'] as String?,
    );
  }

  String value;

  String? username;

  /// Returns a shallow copy of this [SecretFields]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SecretFields copyWith({
    String? value,
    String? username,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SecretFields',
      'value': value,
      if (username != null) 'username': username,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SecretFields',
      'value': value,
      if (username != null) 'username': username,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SecretFieldsImpl extends SecretFields {
  _SecretFieldsImpl({
    required String value,
    String? username,
  }) : super._(
         value: value,
         username: username,
       );

  /// Returns a shallow copy of this [SecretFields]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SecretFields copyWith({
    String? value,
    Object? username = _Undefined,
  }) {
    return SecretFields(
      value: value ?? this.value,
      username: username is String? ? username : this.username,
    );
  }
}
