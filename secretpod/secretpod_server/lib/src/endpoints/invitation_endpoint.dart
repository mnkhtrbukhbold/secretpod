import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';
import '../services.dart';
import '../paging.dart';

class InvitationEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;
  @override
  bool get logSessions => false;
  String _actor(Session session) => session.authenticated!.userIdentifier;

  Future<InvitationCreated> create(
    Session session,
    String organizationId,
    String email,
    String name,
    String role, {
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) => VaultServices.instance.invitations.create(
    _actor(session),
    organizationId,
    email,
    name,
    role,
    readProjects: readProjects,
    writeProjects: writeProjects,
    deniedReadProjects: deniedReadProjects,
    deniedWriteProjects: deniedWriteProjects,
    canCreateProjects: canCreateProjects,
  );
  Future<List<InvitationView>> inbox(
    Session session, {
    int? offset,
    int? limit,
  }) => VaultServices.instance.invitations.inbox(
    _actor(session),
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
  );
  Future<List<InvitationView>> outgoing(
    Session session,
    String organizationId, {
    int? offset,
    int? limit,
  }) => VaultServices.instance.invitations.outgoing(
    _actor(session),
    organizationId,
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
  );
  Future<void> accept(Session session, String id, String token) =>
      VaultServices.instance.invitations.accept(_actor(session), id, token);
  Future<void> decline(Session session, String id) =>
      VaultServices.instance.invitations.decline(_actor(session), id);
  Future<void> revoke(Session session, String organizationId, String id) =>
      VaultServices.instance.invitations.revoke(
        _actor(session),
        organizationId,
        id,
      );
  Future<AccountView> profile(Session session) =>
      VaultServices.instance.invitations.profile(_actor(session));
  Future<AccountView> updatePolicy(Session session, String policy) =>
      VaultServices.instance.invitations.updatePolicy(_actor(session), policy);
}
