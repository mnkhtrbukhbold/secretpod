/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:secretpod_server/src/generated/audit_view.dart' as _ic743zrz;
import 'package:secretpod_server/src/generated/invitation_view.dart'
    as _iyqr9w4w;
import 'package:secretpod_server/src/generated/member_view.dart' as _ivfywoed;
import 'package:secretpod_server/src/generated/organization_view.dart'
    as _i59nqxt4;
import 'package:secretpod_server/src/generated/secret_view.dart' as _irfersm6;
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'account_view.dart' as _i4ejbnhv;
import 'audit_view.dart' as _ij35bxgi;
import 'auth_result.dart' as _i6p2fgl8;
import 'invitation_created.dart' as _iylup2zd;
import 'invitation_view.dart' as _i3eoqonr;
import 'member_view.dart' as _iwpqxdug;
import 'organization_view.dart' as _ic2ajh9j;
import 'secret_copy.dart' as _ie3943cq;
import 'secret_fields.dart' as _irh963ls;
import 'secret_view.dart' as _i2klvzuk;
import 'vault_exception.dart' as _iesl6joq;
import 'workspace_summary.dart' as _igsz6by5;
export 'account_view.dart';
export 'audit_view.dart';
export 'auth_result.dart';
export 'invitation_created.dart';
export 'invitation_view.dart';
export 'member_view.dart';
export 'organization_view.dart';
export 'secret_copy.dart';
export 'secret_fields.dart';
export 'secret_view.dart';
export 'vault_exception.dart';
export 'workspace_summary.dart';

class Protocol extends _is.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i4ejbnhv.AccountView) {
      return _i4ejbnhv.AccountView.fromJson(data) as T;
    }
    if (t == _ij35bxgi.AuditView) {
      return _ij35bxgi.AuditView.fromJson(data) as T;
    }
    if (t == _i6p2fgl8.AuthResult) {
      return _i6p2fgl8.AuthResult.fromJson(data) as T;
    }
    if (t == _iylup2zd.InvitationCreated) {
      return _iylup2zd.InvitationCreated.fromJson(data) as T;
    }
    if (t == _i3eoqonr.InvitationView) {
      return _i3eoqonr.InvitationView.fromJson(data) as T;
    }
    if (t == _iwpqxdug.MemberView) {
      return _iwpqxdug.MemberView.fromJson(data) as T;
    }
    if (t == _ic2ajh9j.OrganizationView) {
      return _ic2ajh9j.OrganizationView.fromJson(data) as T;
    }
    if (t == _ie3943cq.SecretCopy) {
      return _ie3943cq.SecretCopy.fromJson(data) as T;
    }
    if (t == _irh963ls.SecretFields) {
      return _irh963ls.SecretFields.fromJson(data) as T;
    }
    if (t == _i2klvzuk.SecretView) {
      return _i2klvzuk.SecretView.fromJson(data) as T;
    }
    if (t == _iesl6joq.VaultException) {
      return _iesl6joq.VaultException.fromJson(data) as T;
    }
    if (t == _igsz6by5.WorkspaceSummary) {
      return _igsz6by5.WorkspaceSummary.fromJson(data) as T;
    }
    if (t == _is.getType<_i4ejbnhv.AccountView?>()) {
      return (data != null ? _i4ejbnhv.AccountView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ij35bxgi.AuditView?>()) {
      return (data != null ? _ij35bxgi.AuditView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i6p2fgl8.AuthResult?>()) {
      return (data != null ? _i6p2fgl8.AuthResult.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iylup2zd.InvitationCreated?>()) {
      return (data != null ? _iylup2zd.InvitationCreated.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i3eoqonr.InvitationView?>()) {
      return (data != null ? _i3eoqonr.InvitationView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iwpqxdug.MemberView?>()) {
      return (data != null ? _iwpqxdug.MemberView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ic2ajh9j.OrganizationView?>()) {
      return (data != null ? _ic2ajh9j.OrganizationView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ie3943cq.SecretCopy?>()) {
      return (data != null ? _ie3943cq.SecretCopy.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_irh963ls.SecretFields?>()) {
      return (data != null ? _irh963ls.SecretFields.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i2klvzuk.SecretView?>()) {
      return (data != null ? _i2klvzuk.SecretView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iesl6joq.VaultException?>()) {
      return (data != null ? _iesl6joq.VaultException.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_igsz6by5.WorkspaceSummary?>()) {
      return (data != null ? _igsz6by5.WorkspaceSummary.fromJson(data) : null)
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _is.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == Map<String, int>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<int>(v)),
          )
          as T;
    }
    if (t == Map<String, String>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<String>(v)),
          )
          as T;
    }
    if (t == _is.getType<Map<String, String>?>()) {
      return (data != null
              ? (data as Map).map(
                  (k, v) =>
                      MapEntry(deserialize<String>(k), deserialize<String>(v)),
                )
              : null)
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _is.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_iyqr9w4w.InvitationView>) {
      return (data as List)
              .map((e) => deserialize<_iyqr9w4w.InvitationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i59nqxt4.OrganizationView>) {
      return (data as List)
              .map((e) => deserialize<_i59nqxt4.OrganizationView>(e))
              .toList()
          as T;
    }
    if (t == List<_ivfywoed.MemberView>) {
      return (data as List)
              .map((e) => deserialize<_ivfywoed.MemberView>(e))
              .toList()
          as T;
    }
    if (t == List<_irfersm6.SecretView>) {
      return (data as List)
              .map((e) => deserialize<_irfersm6.SecretView>(e))
              .toList()
          as T;
    }
    if (t == List<_ic743zrz.AuditView>) {
      return (data as List)
              .map((e) => deserialize<_ic743zrz.AuditView>(e))
              .toList()
          as T;
    }
    try {
      return _isp.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i4ejbnhv.AccountView => 'AccountView',
      _ij35bxgi.AuditView => 'AuditView',
      _i6p2fgl8.AuthResult => 'AuthResult',
      _iylup2zd.InvitationCreated => 'InvitationCreated',
      _i3eoqonr.InvitationView => 'InvitationView',
      _iwpqxdug.MemberView => 'MemberView',
      _ic2ajh9j.OrganizationView => 'OrganizationView',
      _ie3943cq.SecretCopy => 'SecretCopy',
      _irh963ls.SecretFields => 'SecretFields',
      _i2klvzuk.SecretView => 'SecretView',
      _iesl6joq.VaultException => 'VaultException',
      _igsz6by5.WorkspaceSummary => 'WorkspaceSummary',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('secretpod.', '');
    }

    switch (data) {
      case _i4ejbnhv.AccountView():
        return 'AccountView';
      case _ij35bxgi.AuditView():
        return 'AuditView';
      case _i6p2fgl8.AuthResult():
        return 'AuthResult';
      case _iylup2zd.InvitationCreated():
        return 'InvitationCreated';
      case _i3eoqonr.InvitationView():
        return 'InvitationView';
      case _iwpqxdug.MemberView():
        return 'MemberView';
      case _ic2ajh9j.OrganizationView():
        return 'OrganizationView';
      case _ie3943cq.SecretCopy():
        return 'SecretCopy';
      case _irh963ls.SecretFields():
        return 'SecretFields';
      case _i2klvzuk.SecretView():
        return 'SecretView';
      case _iesl6joq.VaultException():
        return 'VaultException';
      case _igsz6by5.WorkspaceSummary():
        return 'WorkspaceSummary';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AccountView') {
      return deserialize<_i4ejbnhv.AccountView>(data['data']);
    }
    if (dataClassName == 'AuditView') {
      return deserialize<_ij35bxgi.AuditView>(data['data']);
    }
    if (dataClassName == 'AuthResult') {
      return deserialize<_i6p2fgl8.AuthResult>(data['data']);
    }
    if (dataClassName == 'InvitationCreated') {
      return deserialize<_iylup2zd.InvitationCreated>(data['data']);
    }
    if (dataClassName == 'InvitationView') {
      return deserialize<_i3eoqonr.InvitationView>(data['data']);
    }
    if (dataClassName == 'MemberView') {
      return deserialize<_iwpqxdug.MemberView>(data['data']);
    }
    if (dataClassName == 'OrganizationView') {
      return deserialize<_ic2ajh9j.OrganizationView>(data['data']);
    }
    if (dataClassName == 'SecretCopy') {
      return deserialize<_ie3943cq.SecretCopy>(data['data']);
    }
    if (dataClassName == 'SecretFields') {
      return deserialize<_irh963ls.SecretFields>(data['data']);
    }
    if (dataClassName == 'SecretView') {
      return deserialize<_i2klvzuk.SecretView>(data['data']);
    }
    if (dataClassName == 'VaultException') {
      return deserialize<_iesl6joq.VaultException>(data['data']);
    }
    if (dataClassName == 'WorkspaceSummary') {
      return deserialize<_igsz6by5.WorkspaceSummary>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'secretpod';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _isp.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
