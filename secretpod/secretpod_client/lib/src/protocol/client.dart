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
import 'dart:async' as _ida;
import 'package:http/http.dart' as _i85jenna;
import 'package:secretpod_client/src/protocol/account_view.dart' as _isheburk;
import 'package:secretpod_client/src/protocol/audit_view.dart' as _ijkr5qom;
import 'package:secretpod_client/src/protocol/auth_result.dart' as _ifzh8csa;
import 'package:secretpod_client/src/protocol/invitation_created.dart'
    as _iyyr91rv;
import 'package:secretpod_client/src/protocol/invitation_view.dart'
    as _irfuoomv;
import 'package:secretpod_client/src/protocol/member_view.dart' as _idtekx1t;
import 'package:secretpod_client/src/protocol/organization_view.dart'
    as _io5hdo2c;
import 'package:secretpod_client/src/protocol/secret_copy.dart' as _ijghhy3x;
import 'package:secretpod_client/src/protocol/secret_fields.dart' as _ipgvdui0;
import 'package:secretpod_client/src/protocol/secret_view.dart' as _il4xcmkq;
import 'package:secretpod_client/src/protocol/workspace_summary.dart'
    as _iuy5swc1;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'protocol.dart' as _il2as5qe;

/// {@category Endpoint}
class EndpointAccount extends _isc.EndpointRef {
  EndpointAccount(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'account';

  _ida.Future<_ifzh8csa.AuthResult> register(
    String email,
    String password,
    String name,
  ) => caller.callServerEndpoint<_ifzh8csa.AuthResult>(
    'account',
    'register',
    {
      'email': email,
      'password': password,
      'name': name,
    },
  );

  _ida.Future<_ifzh8csa.AuthResult> login(
    String email,
    String password,
  ) => caller.callServerEndpoint<_ifzh8csa.AuthResult>(
    'account',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  _ida.Future<_irfuoomv.InvitationView> previewInvitation(String token) =>
      caller.callServerEndpoint<_irfuoomv.InvitationView>(
        'account',
        'previewInvitation',
        {'token': token},
      );

  _ida.Future<_ifzh8csa.AuthResult> registerFromInvitation(
    String token,
    String name,
    String password,
  ) => caller.callServerEndpoint<_ifzh8csa.AuthResult>(
    'account',
    'registerFromInvitation',
    {
      'token': token,
      'name': name,
      'password': password,
    },
  );

  _ida.Future<void> declineInvitation(String token) =>
      caller.callServerEndpoint<void>(
        'account',
        'declineInvitation',
        {'token': token},
      );
}

/// {@category Endpoint}
class EndpointInvitation extends _isc.EndpointRef {
  EndpointInvitation(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'invitation';

  _ida.Future<_iyyr91rv.InvitationCreated> create(
    String organizationId,
    String email,
    String name,
    String role, {
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) => caller.callServerEndpoint<_iyyr91rv.InvitationCreated>(
    'invitation',
    'create',
    {
      'organizationId': organizationId,
      'email': email,
      'name': name,
      'role': role,
      'readProjects': readProjects,
      'writeProjects': writeProjects,
      'deniedReadProjects': deniedReadProjects,
      'deniedWriteProjects': deniedWriteProjects,
      'canCreateProjects': canCreateProjects,
    },
  );

  _ida.Future<List<_irfuoomv.InvitationView>> inbox({
    int? offset,
    int? limit,
  }) => caller.callServerEndpoint<List<_irfuoomv.InvitationView>>(
    'invitation',
    'inbox',
    {
      'offset': offset,
      'limit': limit,
    },
  );

  _ida.Future<List<_irfuoomv.InvitationView>> outgoing(
    String organizationId, {
    int? offset,
    int? limit,
  }) => caller.callServerEndpoint<List<_irfuoomv.InvitationView>>(
    'invitation',
    'outgoing',
    {
      'organizationId': organizationId,
      'offset': offset,
      'limit': limit,
    },
  );

  _ida.Future<void> accept(
    String id,
    String token,
  ) => caller.callServerEndpoint<void>(
    'invitation',
    'accept',
    {
      'id': id,
      'token': token,
    },
  );

  _ida.Future<void> decline(String id) => caller.callServerEndpoint<void>(
    'invitation',
    'decline',
    {'id': id},
  );

  _ida.Future<void> revoke(
    String organizationId,
    String id,
  ) => caller.callServerEndpoint<void>(
    'invitation',
    'revoke',
    {
      'organizationId': organizationId,
      'id': id,
    },
  );

  _ida.Future<_isheburk.AccountView> profile() =>
      caller.callServerEndpoint<_isheburk.AccountView>(
        'invitation',
        'profile',
        {},
      );

  _ida.Future<_isheburk.AccountView> updatePolicy(String policy) =>
      caller.callServerEndpoint<_isheburk.AccountView>(
        'invitation',
        'updatePolicy',
        {'policy': policy},
      );
}

/// {@category Endpoint}
class EndpointProfile extends _isc.EndpointRef {
  EndpointProfile(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'profile';

  _ida.Future<_isheburk.AccountView> updateName(String name) =>
      caller.callServerEndpoint<_isheburk.AccountView>(
        'profile',
        'updateName',
        {'name': name},
      );

  _ida.Future<_isheburk.AccountView> updateEmail(
    String currentPassword,
    String email,
  ) => caller.callServerEndpoint<_isheburk.AccountView>(
    'profile',
    'updateEmail',
    {
      'currentPassword': currentPassword,
      'email': email,
    },
  );

  _ida.Future<_isheburk.AccountView> updateTheme(String themeMode) =>
      caller.callServerEndpoint<_isheburk.AccountView>(
        'profile',
        'updateTheme',
        {'themeMode': themeMode},
      );

  _ida.Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) => caller.callServerEndpoint<void>(
    'profile',
    'changePassword',
    {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    },
  );
}

/// {@category Endpoint}
class EndpointVault extends _isc.EndpointRef {
  EndpointVault(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'vault';

  _ida.Future<List<_io5hdo2c.OrganizationView>> organizations({
    int? offset,
    int? limit,
  }) => caller.callServerEndpoint<List<_io5hdo2c.OrganizationView>>(
    'vault',
    'organizations',
    {
      'offset': offset,
      'limit': limit,
    },
  );

  _ida.Future<_io5hdo2c.OrganizationView> createOrganization(String name) =>
      caller.callServerEndpoint<_io5hdo2c.OrganizationView>(
        'vault',
        'createOrganization',
        {'name': name},
      );

  _ida.Future<String> createProject(
    String organizationId,
    String name,
  ) => caller.callServerEndpoint<String>(
    'vault',
    'createProject',
    {
      'organizationId': organizationId,
      'name': name,
    },
  );

  _ida.Future<_io5hdo2c.OrganizationView> renameOrganization(
    String organizationId,
    String name,
  ) => caller.callServerEndpoint<_io5hdo2c.OrganizationView>(
    'vault',
    'renameOrganization',
    {
      'organizationId': organizationId,
      'name': name,
    },
  );

  _ida.Future<List<_idtekx1t.MemberView>> members(
    String organizationId, {
    int? offset,
    int? limit,
  }) => caller.callServerEndpoint<List<_idtekx1t.MemberView>>(
    'vault',
    'members',
    {
      'organizationId': organizationId,
      'offset': offset,
      'limit': limit,
    },
  );

  _ida.Future<void> addMember(
    String organizationId,
    String email,
    String role,
  ) => caller.callServerEndpoint<void>(
    'vault',
    'addMember',
    {
      'organizationId': organizationId,
      'email': email,
      'role': role,
    },
  );

  _ida.Future<_idtekx1t.MemberView> updateMemberAccess(
    String organizationId,
    String accountId,
    String role, {
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) => caller.callServerEndpoint<_idtekx1t.MemberView>(
    'vault',
    'updateMemberAccess',
    {
      'organizationId': organizationId,
      'accountId': accountId,
      'role': role,
      'readProjects': readProjects,
      'writeProjects': writeProjects,
      'deniedReadProjects': deniedReadProjects,
      'deniedWriteProjects': deniedWriteProjects,
      'canCreateProjects': canCreateProjects,
    },
  );

  _ida.Future<List<_il4xcmkq.SecretView>> memberRemovalSecrets(
    String organizationId,
    String accountId, {
    int? offset,
    int? limit,
    int? utcOffsetMinutes,
  }) => caller.callServerEndpoint<List<_il4xcmkq.SecretView>>(
    'vault',
    'memberRemovalSecrets',
    {
      'organizationId': organizationId,
      'accountId': accountId,
      'offset': offset,
      'limit': limit,
      'utcOffsetMinutes': utcOffsetMinutes,
    },
  );

  _ida.Future<void> removeMember(
    String organizationId,
    String accountId,
    List<String> reviewedSecretIds,
    List<String> rotateSecretIds, {
    int? utcOffsetMinutes,
  }) => caller.callServerEndpoint<void>(
    'vault',
    'removeMember',
    {
      'organizationId': organizationId,
      'accountId': accountId,
      'reviewedSecretIds': reviewedSecretIds,
      'rotateSecretIds': rotateSecretIds,
      'utcOffsetMinutes': utcOffsetMinutes,
    },
  );

  _ida.Future<_idtekx1t.MemberView> setMemberEnabled(
    String organizationId,
    String accountId,
    bool enabled,
    List<String> reviewedSecretIds,
    List<String> rotateSecretIds, {
    int? utcOffsetMinutes,
  }) => caller.callServerEndpoint<_idtekx1t.MemberView>(
    'vault',
    'setMemberEnabled',
    {
      'organizationId': organizationId,
      'accountId': accountId,
      'enabled': enabled,
      'reviewedSecretIds': reviewedSecretIds,
      'rotateSecretIds': rotateSecretIds,
      'utcOffsetMinutes': utcOffsetMinutes,
    },
  );

  _ida.Future<_il4xcmkq.SecretView> setSecretRotationRequired(
    String organizationId,
    String id,
    bool required,
  ) => caller.callServerEndpoint<_il4xcmkq.SecretView>(
    'vault',
    'setSecretRotationRequired',
    {
      'organizationId': organizationId,
      'id': id,
      'required': required,
    },
  );

  _ida.Future<List<_il4xcmkq.SecretView>> listSecrets(
    String organizationId, {
    int? offset,
    int? limit,
    String? query,
    String? project,
    String? environment,
  }) => caller.callServerEndpoint<List<_il4xcmkq.SecretView>>(
    'vault',
    'listSecrets',
    {
      'organizationId': organizationId,
      'offset': offset,
      'limit': limit,
      'query': query,
      'project': project,
      'environment': environment,
    },
  );

  _ida.Future<_iuy5swc1.WorkspaceSummary> summary(
    String organizationId, {
    String? query,
    String? project,
    String? environment,
    DateTime? activityFrom,
    DateTime? activityUntil,
    String? activityProject,
    String? activityAction,
    String? activityUser,
  }) => caller.callServerEndpoint<_iuy5swc1.WorkspaceSummary>(
    'vault',
    'summary',
    {
      'organizationId': organizationId,
      'query': query,
      'project': project,
      'environment': environment,
      'activityFrom': activityFrom,
      'activityUntil': activityUntil,
      'activityProject': activityProject,
      'activityAction': activityAction,
      'activityUser': activityUser,
    },
  );

  _ida.Future<_il4xcmkq.SecretView> saveSecret(
    String organizationId,
    String? id,
    String name,
    String? value,
    String project,
    String environment,
    String kind,
    String description, {
    String? username,
    String? url,
    DateTime? expiresAt,
    bool? replaceMetadata,
  }) => caller.callServerEndpoint<_il4xcmkq.SecretView>(
    'vault',
    'saveSecret',
    {
      'organizationId': organizationId,
      'id': id,
      'name': name,
      'value': value,
      'project': project,
      'environment': environment,
      'kind': kind,
      'description': description,
      'username': username,
      'url': url,
      'expiresAt': expiresAt,
      'replaceMetadata': replaceMetadata,
    },
  );

  _ida.Future<String> revealSecret(
    String organizationId,
    String id,
  ) => caller.callServerEndpoint<String>(
    'vault',
    'revealSecret',
    {
      'organizationId': organizationId,
      'id': id,
    },
  );

  _ida.Future<_ipgvdui0.SecretFields> revealSecretFields(
    String organizationId,
    String id,
  ) => caller.callServerEndpoint<_ipgvdui0.SecretFields>(
    'vault',
    'revealSecretFields',
    {
      'organizationId': organizationId,
      'id': id,
    },
  );

  _ida.Future<void> deleteSecret(
    String organizationId,
    String id,
  ) => caller.callServerEndpoint<void>(
    'vault',
    'deleteSecret',
    {
      'organizationId': organizationId,
      'id': id,
    },
  );

  _ida.Future<List<_ijkr5qom.AuditView>> activity(
    String organizationId, {
    int? offset,
    int? limit,
    DateTime? from,
    DateTime? until,
    String? project,
    String? action,
    String? user,
  }) => caller.callServerEndpoint<List<_ijkr5qom.AuditView>>(
    'vault',
    'activity',
    {
      'organizationId': organizationId,
      'offset': offset,
      'limit': limit,
      'from': from,
      'until': until,
      'project': project,
      'action': action,
      'user': user,
    },
  );

  _ida.Future<List<_ijkr5qom.AuditView>> secretActivity(
    String organizationId,
    String secretId,
    String? beforeEventId, {
    int? offset,
    int? limit,
  }) => caller.callServerEndpoint<List<_ijkr5qom.AuditView>>(
    'vault',
    'secretActivity',
    {
      'organizationId': organizationId,
      'secretId': secretId,
      'beforeEventId': beforeEventId,
      'offset': offset,
      'limit': limit,
    },
  );

  _ida.Future<_ijghhy3x.SecretCopy> copySecret(
    String organizationId,
    String id, {
    String? field,
  }) => caller.callServerEndpoint<_ijghhy3x.SecretCopy>(
    'vault',
    'copySecret',
    {
      'organizationId': organizationId,
      'id': id,
      'field': field,
    },
  );

  _ida.Future<void> confirmCopy(
    String organizationId,
    String secretId,
    String eventId,
  ) => caller.callServerEndpoint<void>(
    'vault',
    'confirmCopy',
    {
      'organizationId': organizationId,
      'secretId': secretId,
      'eventId': eventId,
    },
  );

  _ida.Future<void> logout() => caller.callServerEndpoint<void>(
    'vault',
    'logout',
    {},
  );
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    account = EndpointAccount(this);
    invitation = EndpointInvitation(this);
    profile = EndpointProfile(this);
    vault = EndpointVault(this);
  }

  late final EndpointAccount account;

  late final EndpointInvitation invitation;

  late final EndpointProfile profile;

  late final EndpointVault vault;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'account': account,
    'invitation': invitation,
    'profile': profile,
    'vault': vault,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {};
}
