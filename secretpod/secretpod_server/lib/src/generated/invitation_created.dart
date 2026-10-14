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
import 'invitation_view.dart' as _i3eoqonr;

abstract class InvitationCreated
    implements _is.SerializableModel, _is.ProtocolSerialization {
  InvitationCreated._({
    required this.invitation,
    required this.token,
  });

  factory InvitationCreated({
    required _i3eoqonr.InvitationView invitation,
    required String token,
  }) = _InvitationCreatedImpl;

  factory InvitationCreated.fromJson(Map<String, dynamic> jsonSerialization) {
    return InvitationCreated(
      invitation: _ii063q5q.Protocol().deserialize<_i3eoqonr.InvitationView>(
        jsonSerialization['invitation'],
      ),
      token: jsonSerialization['token'] as String,
    );
  }

  _i3eoqonr.InvitationView invitation;

  String token;

  /// Returns a shallow copy of this [InvitationCreated]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  InvitationCreated copyWith({
    _i3eoqonr.InvitationView? invitation,
    String? token,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InvitationCreated',
      'invitation': invitation.toJson(),
      'token': token,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InvitationCreated',
      'invitation': invitation.toJsonForProtocol(),
      'token': token,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _InvitationCreatedImpl extends InvitationCreated {
  _InvitationCreatedImpl({
    required _i3eoqonr.InvitationView invitation,
    required String token,
  }) : super._(
         invitation: invitation,
         token: token,
       );

  /// Returns a shallow copy of this [InvitationCreated]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  InvitationCreated copyWith({
    _i3eoqonr.InvitationView? invitation,
    String? token,
  }) {
    return InvitationCreated(
      invitation: invitation ?? this.invitation.copyWith(),
      token: token ?? this.token,
    );
  }
}
