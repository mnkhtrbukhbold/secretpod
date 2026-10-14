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

abstract class WorkspaceSummary
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WorkspaceSummary._({
    required this.secretCount,
    required this.filteredSecretCount,
    required this.memberCount,
    required this.activityCount,
    required this.projectCounts,
    this.filteredActivityCount,
    this.activityProjects,
    this.activityActions,
    this.activityUsers,
  });

  factory WorkspaceSummary({
    required int secretCount,
    required int filteredSecretCount,
    required int memberCount,
    required int activityCount,
    required Map<String, int> projectCounts,
    int? filteredActivityCount,
    List<String>? activityProjects,
    List<String>? activityActions,
    Map<String, String>? activityUsers,
  }) = _WorkspaceSummaryImpl;

  factory WorkspaceSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkspaceSummary(
      secretCount: jsonSerialization['secretCount'] as int,
      filteredSecretCount: jsonSerialization['filteredSecretCount'] as int,
      memberCount: jsonSerialization['memberCount'] as int,
      activityCount: jsonSerialization['activityCount'] as int,
      projectCounts: _ii063q5q.Protocol().deserialize<Map<String, int>>(
        jsonSerialization['projectCounts'],
      ),
      filteredActivityCount: jsonSerialization['filteredActivityCount'] as int?,
      activityProjects: jsonSerialization['activityProjects'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<List<String>>(
              jsonSerialization['activityProjects'],
            ),
      activityActions: jsonSerialization['activityActions'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<List<String>>(
              jsonSerialization['activityActions'],
            ),
      activityUsers: jsonSerialization['activityUsers'] == null
          ? null
          : _ii063q5q.Protocol().deserialize<Map<String, String>>(
              jsonSerialization['activityUsers'],
            ),
    );
  }

  int secretCount;

  int filteredSecretCount;

  int memberCount;

  int activityCount;

  Map<String, int> projectCounts;

  int? filteredActivityCount;

  List<String>? activityProjects;

  List<String>? activityActions;

  Map<String, String>? activityUsers;

  /// Returns a shallow copy of this [WorkspaceSummary]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WorkspaceSummary copyWith({
    int? secretCount,
    int? filteredSecretCount,
    int? memberCount,
    int? activityCount,
    Map<String, int>? projectCounts,
    int? filteredActivityCount,
    List<String>? activityProjects,
    List<String>? activityActions,
    Map<String, String>? activityUsers,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkspaceSummary',
      'secretCount': secretCount,
      'filteredSecretCount': filteredSecretCount,
      'memberCount': memberCount,
      'activityCount': activityCount,
      'projectCounts': projectCounts.toJson(),
      if (filteredActivityCount != null)
        'filteredActivityCount': filteredActivityCount,
      if (activityProjects != null)
        'activityProjects': activityProjects?.toJson(),
      if (activityActions != null) 'activityActions': activityActions?.toJson(),
      if (activityUsers != null) 'activityUsers': activityUsers?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkspaceSummary',
      'secretCount': secretCount,
      'filteredSecretCount': filteredSecretCount,
      'memberCount': memberCount,
      'activityCount': activityCount,
      'projectCounts': projectCounts.toJson(),
      if (filteredActivityCount != null)
        'filteredActivityCount': filteredActivityCount,
      if (activityProjects != null)
        'activityProjects': activityProjects?.toJson(),
      if (activityActions != null) 'activityActions': activityActions?.toJson(),
      if (activityUsers != null) 'activityUsers': activityUsers?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkspaceSummaryImpl extends WorkspaceSummary {
  _WorkspaceSummaryImpl({
    required int secretCount,
    required int filteredSecretCount,
    required int memberCount,
    required int activityCount,
    required Map<String, int> projectCounts,
    int? filteredActivityCount,
    List<String>? activityProjects,
    List<String>? activityActions,
    Map<String, String>? activityUsers,
  }) : super._(
         secretCount: secretCount,
         filteredSecretCount: filteredSecretCount,
         memberCount: memberCount,
         activityCount: activityCount,
         projectCounts: projectCounts,
         filteredActivityCount: filteredActivityCount,
         activityProjects: activityProjects,
         activityActions: activityActions,
         activityUsers: activityUsers,
       );

  /// Returns a shallow copy of this [WorkspaceSummary]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WorkspaceSummary copyWith({
    int? secretCount,
    int? filteredSecretCount,
    int? memberCount,
    int? activityCount,
    Map<String, int>? projectCounts,
    Object? filteredActivityCount = _Undefined,
    Object? activityProjects = _Undefined,
    Object? activityActions = _Undefined,
    Object? activityUsers = _Undefined,
  }) {
    return WorkspaceSummary(
      secretCount: secretCount ?? this.secretCount,
      filteredSecretCount: filteredSecretCount ?? this.filteredSecretCount,
      memberCount: memberCount ?? this.memberCount,
      activityCount: activityCount ?? this.activityCount,
      projectCounts:
          projectCounts ??
          this.projectCounts.map(
            (
              key0,
              value0,
            ) => MapEntry(
              key0,
              value0,
            ),
          ),
      filteredActivityCount: filteredActivityCount is int?
          ? filteredActivityCount
          : this.filteredActivityCount,
      activityProjects: activityProjects is List<String>?
          ? activityProjects
          : this.activityProjects?.map((e0) => e0).toList(),
      activityActions: activityActions is List<String>?
          ? activityActions
          : this.activityActions?.map((e0) => e0).toList(),
      activityUsers: activityUsers is Map<String, String>?
          ? activityUsers
          : this.activityUsers?.map(
              (
                key0,
                value0,
              ) => MapEntry(
                key0,
                value0,
              ),
            ),
    );
  }
}
