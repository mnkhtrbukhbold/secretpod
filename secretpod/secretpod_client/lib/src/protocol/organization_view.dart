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

abstract class OrganizationView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  OrganizationView._({
    required this.id,
    required this.name,
    required this.role,
    required this.createdAt,
    this.readProjects,
    this.writeProjects,
    this.deniedReadProjects,
    this.deniedWriteProjects,
    this.canCreateProjects,
  });

  factory OrganizationView({
    required String id,
    required String name,
    required String role,
    required DateTime createdAt,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) = _OrganizationViewImpl;

  factory OrganizationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return OrganizationView(
      id: jsonSerialization['id'] as String,
      name: jsonSerialization['name'] as String,
      role: jsonSerialization['role'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      readProjects: jsonSerialization['readProjects'] == null
          ? null
          : _i7izs5b9.Protocol().deserialize<List<String>>(
              jsonSerialization['readProjects'],
            ),
      writeProjects: jsonSerialization['writeProjects'] == null
          ? null
          : _i7izs5b9.Protocol().deserialize<List<String>>(
              jsonSerialization['writeProjects'],
            ),
      deniedReadProjects: jsonSerialization['deniedReadProjects'] == null
          ? null
          : _i7izs5b9.Protocol().deserialize<List<String>>(
              jsonSerialization['deniedReadProjects'],
            ),
      deniedWriteProjects: jsonSerialization['deniedWriteProjects'] == null
          ? null
          : _i7izs5b9.Protocol().deserialize<List<String>>(
              jsonSerialization['deniedWriteProjects'],
            ),
      canCreateProjects: jsonSerialization['canCreateProjects'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['canCreateProjects'],
            ),
    );
  }

  String id;

  String name;

  String role;

  DateTime createdAt;

  List<String>? readProjects;

  List<String>? writeProjects;

  List<String>? deniedReadProjects;

  List<String>? deniedWriteProjects;

  bool? canCreateProjects;

  /// Returns a shallow copy of this [OrganizationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  OrganizationView copyWith({
    String? id,
    String? name,
    String? role,
    DateTime? createdAt,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OrganizationView',
      'id': id,
      'name': name,
      'role': role,
      'createdAt': createdAt.toJson(),
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
      '__className__': 'OrganizationView',
      'id': id,
      'name': name,
      'role': role,
      'createdAt': createdAt.toJson(),
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
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OrganizationViewImpl extends OrganizationView {
  _OrganizationViewImpl({
    required String id,
    required String name,
    required String role,
    required DateTime createdAt,
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) : super._(
         id: id,
         name: name,
         role: role,
         createdAt: createdAt,
         readProjects: readProjects,
         writeProjects: writeProjects,
         deniedReadProjects: deniedReadProjects,
         deniedWriteProjects: deniedWriteProjects,
         canCreateProjects: canCreateProjects,
       );

  /// Returns a shallow copy of this [OrganizationView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  OrganizationView copyWith({
    String? id,
    String? name,
    String? role,
    DateTime? createdAt,
    Object? readProjects = _Undefined,
    Object? writeProjects = _Undefined,
    Object? deniedReadProjects = _Undefined,
    Object? deniedWriteProjects = _Undefined,
    Object? canCreateProjects = _Undefined,
  }) {
    return OrganizationView(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
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
