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

abstract class OrganizationView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  OrganizationView._({
    required this.id,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory OrganizationView({
    required String id,
    required String name,
    required String role,
    required DateTime createdAt,
  }) = _OrganizationViewImpl;

  factory OrganizationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return OrganizationView(
      id: jsonSerialization['id'] as String,
      name: jsonSerialization['name'] as String,
      role: jsonSerialization['role'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String id;

  String name;

  String role;

  DateTime createdAt;

  /// Returns a shallow copy of this [OrganizationView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  OrganizationView copyWith({
    String? id,
    String? name,
    String? role,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OrganizationView',
      'id': id,
      'name': name,
      'role': role,
      'createdAt': createdAt.toJson(),
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
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _OrganizationViewImpl extends OrganizationView {
  _OrganizationViewImpl({
    required String id,
    required String name,
    required String role,
    required DateTime createdAt,
  }) : super._(
         id: id,
         name: name,
         role: role,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [OrganizationView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  OrganizationView copyWith({
    String? id,
    String? name,
    String? role,
    DateTime? createdAt,
  }) {
    return OrganizationView(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
