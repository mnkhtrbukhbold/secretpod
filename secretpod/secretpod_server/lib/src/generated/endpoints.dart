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
import '../endpoints/account_endpoint.dart' as _iaho7ul5;
import '../endpoints/invitation_endpoint.dart' as _iipval89;
import '../endpoints/profile_endpoint.dart' as _i2cx2pww;
import '../endpoints/vault_endpoint.dart' as _iy4ugio0;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'account': _iaho7ul5.AccountEndpoint()
        ..initialize(
          server,
          'account',
          null,
        ),
      'invitation': _iipval89.InvitationEndpoint()
        ..initialize(
          server,
          'invitation',
          null,
        ),
      'profile': _i2cx2pww.ProfileEndpoint()
        ..initialize(
          server,
          'profile',
          null,
        ),
      'vault': _iy4ugio0.VaultEndpoint()
        ..initialize(
          server,
          'vault',
          null,
        ),
    };
    connectors['account'] = _is.EndpointConnector(
      name: 'account',
      endpoint: endpoints['account']!,
      methodConnectors: {
        'register': _is.MethodConnector(
          name: 'register',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['account'] as _iaho7ul5.AccountEndpoint).register(
                    session,
                    params['email'],
                    params['password'],
                    params['name'],
                  ),
        ),
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['account'] as _iaho7ul5.AccountEndpoint).login(
                    session,
                    params['email'],
                    params['password'],
                  ),
        ),
        'previewInvitation': _is.MethodConnector(
          name: 'previewInvitation',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['account'] as _iaho7ul5.AccountEndpoint)
                  .previewInvitation(
                    session,
                    params['token'],
                  ),
        ),
        'registerFromInvitation': _is.MethodConnector(
          name: 'registerFromInvitation',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['account'] as _iaho7ul5.AccountEndpoint)
                  .registerFromInvitation(
                    session,
                    params['token'],
                    params['name'],
                    params['password'],
                  ),
        ),
        'declineInvitation': _is.MethodConnector(
          name: 'declineInvitation',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['account'] as _iaho7ul5.AccountEndpoint)
                  .declineInvitation(
                    session,
                    params['token'],
                  ),
        ),
      },
    );
    connectors['invitation'] = _is.EndpointConnector(
      name: 'invitation',
      endpoint: endpoints['invitation']!,
      methodConnectors: {
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'readProjects': _is.ParameterDescription(
              name: 'readProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'writeProjects': _is.ParameterDescription(
              name: 'writeProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'deniedReadProjects': _is.ParameterDescription(
              name: 'deniedReadProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'deniedWriteProjects': _is.ParameterDescription(
              name: 'deniedWriteProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'canCreateProjects': _is.ParameterDescription(
              name: 'canCreateProjects',
              type: _is.getType<bool?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .create(
                        session,
                        params['organizationId'],
                        params['email'],
                        params['name'],
                        params['role'],
                        readProjects: params['readProjects'],
                        writeProjects: params['writeProjects'],
                        deniedReadProjects: params['deniedReadProjects'],
                        deniedWriteProjects: params['deniedWriteProjects'],
                        canCreateProjects: params['canCreateProjects'],
                      ),
        ),
        'inbox': _is.MethodConnector(
          name: 'inbox',
          params: {
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .inbox(
                        session,
                        offset: params['offset'],
                        limit: params['limit'],
                      ),
        ),
        'outgoing': _is.MethodConnector(
          name: 'outgoing',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .outgoing(
                        session,
                        params['organizationId'],
                        offset: params['offset'],
                        limit: params['limit'],
                      ),
        ),
        'accept': _is.MethodConnector(
          name: 'accept',
          params: {
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .accept(
                        session,
                        params['id'],
                        params['token'],
                      ),
        ),
        'decline': _is.MethodConnector(
          name: 'decline',
          params: {
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .decline(
                        session,
                        params['id'],
                      ),
        ),
        'revoke': _is.MethodConnector(
          name: 'revoke',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .revoke(
                        session,
                        params['organizationId'],
                        params['id'],
                      ),
        ),
        'profile': _is.MethodConnector(
          name: 'profile',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .profile(session),
        ),
        'updatePolicy': _is.MethodConnector(
          name: 'updatePolicy',
          params: {
            'policy': _is.ParameterDescription(
              name: 'policy',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitation'] as _iipval89.InvitationEndpoint)
                      .updatePolicy(
                        session,
                        params['policy'],
                      ),
        ),
      },
    );
    connectors['profile'] = _is.EndpointConnector(
      name: 'profile',
      endpoint: endpoints['profile']!,
      methodConnectors: {
        'updateName': _is.MethodConnector(
          name: 'updateName',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .updateName(
                    session,
                    params['name'],
                  ),
        ),
        'updateEmail': _is.MethodConnector(
          name: 'updateEmail',
          params: {
            'currentPassword': _is.ParameterDescription(
              name: 'currentPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .updateEmail(
                    session,
                    params['currentPassword'],
                    params['email'],
                  ),
        ),
        'updateTheme': _is.MethodConnector(
          name: 'updateTheme',
          params: {
            'themeMode': _is.ParameterDescription(
              name: 'themeMode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .updateTheme(
                    session,
                    params['themeMode'],
                  ),
        ),
        'changePassword': _is.MethodConnector(
          name: 'changePassword',
          params: {
            'currentPassword': _is.ParameterDescription(
              name: 'currentPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'newPassword': _is.ParameterDescription(
              name: 'newPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .changePassword(
                    session,
                    params['currentPassword'],
                    params['newPassword'],
                  ),
        ),
      },
    );
    connectors['vault'] = _is.EndpointConnector(
      name: 'vault',
      endpoint: endpoints['vault']!,
      methodConnectors: {
        'organizations': _is.MethodConnector(
          name: 'organizations',
          params: {
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).organizations(
                    session,
                    offset: params['offset'],
                    limit: params['limit'],
                  ),
        ),
        'createOrganization': _is.MethodConnector(
          name: 'createOrganization',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .createOrganization(
                    session,
                    params['name'],
                  ),
        ),
        'createProject': _is.MethodConnector(
          name: 'createProject',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).createProject(
                    session,
                    params['organizationId'],
                    params['name'],
                  ),
        ),
        'renameOrganization': _is.MethodConnector(
          name: 'renameOrganization',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .renameOrganization(
                    session,
                    params['organizationId'],
                    params['name'],
                  ),
        ),
        'members': _is.MethodConnector(
          name: 'members',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).members(
                    session,
                    params['organizationId'],
                    offset: params['offset'],
                    limit: params['limit'],
                  ),
        ),
        'addMember': _is.MethodConnector(
          name: 'addMember',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).addMember(
                    session,
                    params['organizationId'],
                    params['email'],
                    params['role'],
                  ),
        ),
        'updateMemberAccess': _is.MethodConnector(
          name: 'updateMemberAccess',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'accountId': _is.ParameterDescription(
              name: 'accountId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'readProjects': _is.ParameterDescription(
              name: 'readProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'writeProjects': _is.ParameterDescription(
              name: 'writeProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'deniedReadProjects': _is.ParameterDescription(
              name: 'deniedReadProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'deniedWriteProjects': _is.ParameterDescription(
              name: 'deniedWriteProjects',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
            'canCreateProjects': _is.ParameterDescription(
              name: 'canCreateProjects',
              type: _is.getType<bool?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .updateMemberAccess(
                    session,
                    params['organizationId'],
                    params['accountId'],
                    params['role'],
                    readProjects: params['readProjects'],
                    writeProjects: params['writeProjects'],
                    deniedReadProjects: params['deniedReadProjects'],
                    deniedWriteProjects: params['deniedWriteProjects'],
                    canCreateProjects: params['canCreateProjects'],
                  ),
        ),
        'memberRemovalSecrets': _is.MethodConnector(
          name: 'memberRemovalSecrets',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'accountId': _is.ParameterDescription(
              name: 'accountId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'utcOffsetMinutes': _is.ParameterDescription(
              name: 'utcOffsetMinutes',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .memberRemovalSecrets(
                    session,
                    params['organizationId'],
                    params['accountId'],
                    offset: params['offset'],
                    limit: params['limit'],
                    utcOffsetMinutes: params['utcOffsetMinutes'],
                  ),
        ),
        'removeMember': _is.MethodConnector(
          name: 'removeMember',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'accountId': _is.ParameterDescription(
              name: 'accountId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'reviewedSecretIds': _is.ParameterDescription(
              name: 'reviewedSecretIds',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
            'rotateSecretIds': _is.ParameterDescription(
              name: 'rotateSecretIds',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
            'utcOffsetMinutes': _is.ParameterDescription(
              name: 'utcOffsetMinutes',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).removeMember(
                    session,
                    params['organizationId'],
                    params['accountId'],
                    params['reviewedSecretIds'],
                    params['rotateSecretIds'],
                    utcOffsetMinutes: params['utcOffsetMinutes'],
                  ),
        ),
        'setMemberEnabled': _is.MethodConnector(
          name: 'setMemberEnabled',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'accountId': _is.ParameterDescription(
              name: 'accountId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'enabled': _is.ParameterDescription(
              name: 'enabled',
              type: _is.getType<bool>(),
              nullable: false,
            ),
            'reviewedSecretIds': _is.ParameterDescription(
              name: 'reviewedSecretIds',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
            'rotateSecretIds': _is.ParameterDescription(
              name: 'rotateSecretIds',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
            'utcOffsetMinutes': _is.ParameterDescription(
              name: 'utcOffsetMinutes',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .setMemberEnabled(
                    session,
                    params['organizationId'],
                    params['accountId'],
                    params['enabled'],
                    params['reviewedSecretIds'],
                    params['rotateSecretIds'],
                    utcOffsetMinutes: params['utcOffsetMinutes'],
                  ),
        ),
        'setSecretRotationRequired': _is.MethodConnector(
          name: 'setSecretRotationRequired',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'required': _is.ParameterDescription(
              name: 'required',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .setSecretRotationRequired(
                    session,
                    params['organizationId'],
                    params['id'],
                    params['required'],
                  ),
        ),
        'listSecrets': _is.MethodConnector(
          name: 'listSecrets',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'query': _is.ParameterDescription(
              name: 'query',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'project': _is.ParameterDescription(
              name: 'project',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'environment': _is.ParameterDescription(
              name: 'environment',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).listSecrets(
                    session,
                    params['organizationId'],
                    offset: params['offset'],
                    limit: params['limit'],
                    query: params['query'],
                    project: params['project'],
                    environment: params['environment'],
                  ),
        ),
        'summary': _is.MethodConnector(
          name: 'summary',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'query': _is.ParameterDescription(
              name: 'query',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'project': _is.ParameterDescription(
              name: 'project',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'environment': _is.ParameterDescription(
              name: 'environment',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'activityFrom': _is.ParameterDescription(
              name: 'activityFrom',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'activityUntil': _is.ParameterDescription(
              name: 'activityUntil',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'activityProject': _is.ParameterDescription(
              name: 'activityProject',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'activityAction': _is.ParameterDescription(
              name: 'activityAction',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'activityUser': _is.ParameterDescription(
              name: 'activityUser',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).summary(
                    session,
                    params['organizationId'],
                    query: params['query'],
                    project: params['project'],
                    environment: params['environment'],
                    activityFrom: params['activityFrom'],
                    activityUntil: params['activityUntil'],
                    activityProject: params['activityProject'],
                    activityAction: params['activityAction'],
                    activityUser: params['activityUser'],
                  ),
        ),
        'saveSecret': _is.MethodConnector(
          name: 'saveSecret',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'value': _is.ParameterDescription(
              name: 'value',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'project': _is.ParameterDescription(
              name: 'project',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'environment': _is.ParameterDescription(
              name: 'environment',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'description': _is.ParameterDescription(
              name: 'description',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'username': _is.ParameterDescription(
              name: 'username',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'url': _is.ParameterDescription(
              name: 'url',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'expiresAt': _is.ParameterDescription(
              name: 'expiresAt',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'replaceMetadata': _is.ParameterDescription(
              name: 'replaceMetadata',
              type: _is.getType<bool?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).saveSecret(
                    session,
                    params['organizationId'],
                    params['id'],
                    params['name'],
                    params['value'],
                    params['project'],
                    params['environment'],
                    params['kind'],
                    params['description'],
                    username: params['username'],
                    url: params['url'],
                    expiresAt: params['expiresAt'],
                    replaceMetadata: params['replaceMetadata'],
                  ),
        ),
        'revealSecret': _is.MethodConnector(
          name: 'revealSecret',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).revealSecret(
                    session,
                    params['organizationId'],
                    params['id'],
                  ),
        ),
        'revealSecretFields': _is.MethodConnector(
          name: 'revealSecretFields',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .revealSecretFields(
                    session,
                    params['organizationId'],
                    params['id'],
                  ),
        ),
        'deleteSecret': _is.MethodConnector(
          name: 'deleteSecret',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).deleteSecret(
                    session,
                    params['organizationId'],
                    params['id'],
                  ),
        ),
        'activity': _is.MethodConnector(
          name: 'activity',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'from': _is.ParameterDescription(
              name: 'from',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'until': _is.ParameterDescription(
              name: 'until',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'project': _is.ParameterDescription(
              name: 'project',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'action': _is.ParameterDescription(
              name: 'action',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'user': _is.ParameterDescription(
              name: 'user',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).activity(
                    session,
                    params['organizationId'],
                    offset: params['offset'],
                    limit: params['limit'],
                    from: params['from'],
                    until: params['until'],
                    project: params['project'],
                    action: params['action'],
                    user: params['user'],
                  ),
        ),
        'secretActivity': _is.MethodConnector(
          name: 'secretActivity',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'secretId': _is.ParameterDescription(
              name: 'secretId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'beforeEventId': _is.ParameterDescription(
              name: 'beforeEventId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint)
                  .secretActivity(
                    session,
                    params['organizationId'],
                    params['secretId'],
                    params['beforeEventId'],
                    offset: params['offset'],
                    limit: params['limit'],
                  ),
        ),
        'copySecret': _is.MethodConnector(
          name: 'copySecret',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'field': _is.ParameterDescription(
              name: 'field',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).copySecret(
                    session,
                    params['organizationId'],
                    params['id'],
                    field: params['field'],
                  ),
        ),
        'confirmCopy': _is.MethodConnector(
          name: 'confirmCopy',
          params: {
            'organizationId': _is.ParameterDescription(
              name: 'organizationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'secretId': _is.ParameterDescription(
              name: 'secretId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'eventId': _is.ParameterDescription(
              name: 'eventId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['vault'] as _iy4ugio0.VaultEndpoint).confirmCopy(
                    session,
                    params['organizationId'],
                    params['secretId'],
                    params['eventId'],
                  ),
        ),
        'logout': _is.MethodConnector(
          name: 'logout',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['vault'] as _iy4ugio0.VaultEndpoint).logout(
                session,
              ),
        ),
      },
    );
  }
}
