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
import 'account_view.dart' as _i4ejbnhv;

abstract class MemberView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  MemberView._({
    required this.account,
    required this.role,
    bool? accessDisabled,
    this.readProjects,
    this.writeProjects,
    this.deniedReadProjects,
    this.deniedWriteProjects,
    this.canCreateProjects,
  }) : accessDisabled = accessDisabled ?? false;

  factory MemberView({
    required _i4ejbnhv.AccountView account,
    required String role,
    bool? accessDisabled,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) = _MemberViewImpl;

  factory MemberView.fromJson(Map<String, dynamic> jsonSerialization) {
    return MemberView(
      account: _ii063q5q.Protocol().deserialize<_i4ejbnhv.AccountView>(
        jsonSerialization['account'],
      ),
      role: jsonSerialization['role'] as String,
      accessDisabled: jsonSerialization['accessDisabled'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['accessDisabled']),
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

  _i4ejbnhv.AccountView account;

  String role;

  bool accessDisabled;

  List<String>? readProjects;

  List<String>? writeProjects;

  List<String>? deniedReadProjects;

  List<String>? deniedWriteProjects;

  bool? canCreateProjects;

  /// Returns a shallow copy of this [MemberView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MemberView copyWith({
    _i4ejbnhv.AccountView? account,
    String? role,
    bool? accessDisabled,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MemberView',
      'account': account.toJson(),
      'role': role,
      'accessDisabled': accessDisabled,
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
      '__className__': 'MemberView',
      'account': account.toJsonForProtocol(),
      'role': role,
      'accessDisabled': accessDisabled,
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

class _MemberViewImpl extends MemberView {
  _MemberViewImpl({
    required _i4ejbnhv.AccountView account,
    required String role,
    bool? accessDisabled,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) : super._(
         account: account,
         role: role,
         accessDisabled: accessDisabled,
         readProjects: readProjects,
         writeProjects: writeProjects,
         deniedReadProjects: deniedReadProjects,
         deniedWriteProjects: deniedWriteProjects,
         canCreateProjects: canCreateProjects,
       );

  /// Returns a shallow copy of this [MemberView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MemberView copyWith({
    _i4ejbnhv.AccountView? account,
    String? role,
    bool? accessDisabled,
    Object? readProjects = _Undefined,
    Object? writeProjects = _Undefined,
    Object? deniedReadProjects = _Undefined,
    Object? deniedWriteProjects = _Undefined,
    Object? canCreateProjects = _Undefined,
  }) {
    return MemberView(
      account: account ?? this.account.copyWith(),
      role: role ?? this.role,
      accessDisabled: accessDisabled ?? this.accessDisabled,
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
