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

abstract class SecretCopy
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SecretCopy._({
    required this.eventId,
    required this.value,
  });

  factory SecretCopy({
    required String eventId,
    required String value,
  }) = _SecretCopyImpl;

  factory SecretCopy.fromJson(Map<String, dynamic> jsonSerialization) {
    return SecretCopy(
      eventId: jsonSerialization['eventId'] as String,
      value: jsonSerialization['value'] as String,
    );
  }

  String eventId;

  String value;

  /// Returns a shallow copy of this [SecretCopy]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SecretCopy copyWith({
    String? eventId,
    String? value,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SecretCopy',
      'eventId': eventId,
      'value': value,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SecretCopy',
      'eventId': eventId,
      'value': value,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SecretCopyImpl extends SecretCopy {
  _SecretCopyImpl({
    required String eventId,
    required String value,
  }) : super._(
         eventId: eventId,
         value: value,
       );

  /// Returns a shallow copy of this [SecretCopy]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SecretCopy copyWith({
    String? eventId,
    String? value,
  }) {
    return SecretCopy(
      eventId: eventId ?? this.eventId,
      value: value ?? this.value,
    );
  }
}
