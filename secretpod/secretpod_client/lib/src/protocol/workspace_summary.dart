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

abstract class WorkspaceSummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WorkspaceSummary._({
    required this.secretCount,
    required this.filteredSecretCount,
    required this.memberCount,
    required this.activityCount,
    required this.projectCounts,
  });

  factory WorkspaceSummary({
    required int secretCount,
    required int filteredSecretCount,
    required int memberCount,
    required int activityCount,
    required Map<String, int> projectCounts,
  }) = _WorkspaceSummaryImpl;

  factory WorkspaceSummary.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkspaceSummary(
      secretCount: jsonSerialization['secretCount'] as int,
      filteredSecretCount: jsonSerialization['filteredSecretCount'] as int,
      memberCount: jsonSerialization['memberCount'] as int,
      activityCount: jsonSerialization['activityCount'] as int,
      projectCounts: _i7izs5b9.Protocol().deserialize<Map<String, int>>(
        jsonSerialization['projectCounts'],
      ),
    );
  }

  int secretCount;

  int filteredSecretCount;

  int memberCount;

  int activityCount;

  Map<String, int> projectCounts;

  /// Returns a shallow copy of this [WorkspaceSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WorkspaceSummary copyWith({
    int? secretCount,
    int? filteredSecretCount,
    int? memberCount,
    int? activityCount,
    Map<String, int>? projectCounts,
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
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _WorkspaceSummaryImpl extends WorkspaceSummary {
  _WorkspaceSummaryImpl({
    required int secretCount,
    required int filteredSecretCount,
    required int memberCount,
    required int activityCount,
    required Map<String, int> projectCounts,
  }) : super._(
         secretCount: secretCount,
         filteredSecretCount: filteredSecretCount,
         memberCount: memberCount,
         activityCount: activityCount,
         projectCounts: projectCounts,
       );

  /// Returns a shallow copy of this [WorkspaceSummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WorkspaceSummary copyWith({
    int? secretCount,
    int? filteredSecretCount,
    int? memberCount,
    int? activityCount,
    Map<String, int>? projectCounts,
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
    );
  }
}
