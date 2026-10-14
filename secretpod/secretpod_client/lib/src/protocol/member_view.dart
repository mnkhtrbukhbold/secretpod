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

abstract class MemberView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  MemberView._({
    required this.account,
    required this.role,
  });

  factory MemberView({
    required _i4ejbnhv.AccountView account,
    required String role,
  }) = _MemberViewImpl;

  factory MemberView.fromJson(Map<String, dynamic> jsonSerialization) {
    return MemberView(
      account: _i7izs5b9.Protocol().deserialize<_i4ejbnhv.AccountView>(
        jsonSerialization['account'],
      ),
      role: jsonSerialization['role'] as String,
    );
  }

  _i4ejbnhv.AccountView account;

  String role;

  /// Returns a shallow copy of this [MemberView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  MemberView copyWith({
    _i4ejbnhv.AccountView? account,
    String? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MemberView',
      'account': account.toJson(),
      'role': role,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MemberView',
      'account': account.toJsonForProtocol(),
      'role': role,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _MemberViewImpl extends MemberView {
  _MemberViewImpl({
    required _i4ejbnhv.AccountView account,
    required String role,
  }) : super._(
         account: account,
         role: role,
       );

  /// Returns a shallow copy of this [MemberView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  MemberView copyWith({
    _i4ejbnhv.AccountView? account,
    String? role,
  }) {
    return MemberView(
      account: account ?? this.account.copyWith(),
      role: role ?? this.role,
    );
  }
}
