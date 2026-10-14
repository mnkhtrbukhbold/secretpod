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
import 'package:secretpod_client/src/protocol/protocol.dart' as _i7izs5b9;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'account_view.dart' as _i4ejbnhv;

abstract class AuthResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AuthResult._({
    required this.token,
    required this.account,
  });

  factory AuthResult({
    required String token,
    required _i4ejbnhv.AccountView account,
  }) = _AuthResultImpl;

  factory AuthResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return AuthResult(
      token: jsonSerialization['token'] as String,
      account: _i7izs5b9.Protocol().deserialize<_i4ejbnhv.AccountView>(
        jsonSerialization['account'],
      ),
    );
  }

  String token;

  _i4ejbnhv.AccountView account;

  /// Returns a shallow copy of this [AuthResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AuthResult copyWith({
    String? token,
    _i4ejbnhv.AccountView? account,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AuthResult',
      'token': token,
      'account': account.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AuthResult',
      'token': token,
      'account': account.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AuthResultImpl extends AuthResult {
  _AuthResultImpl({
    required String token,
    required _i4ejbnhv.AccountView account,
  }) : super._(
         token: token,
         account: account,
       );

  /// Returns a shallow copy of this [AuthResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AuthResult copyWith({
    String? token,
    _i4ejbnhv.AccountView? account,
  }) {
    return AuthResult(
      token: token ?? this.token,
      account: account ?? this.account.copyWith(),
    );
  }
}
