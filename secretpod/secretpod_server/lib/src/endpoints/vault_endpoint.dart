import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';
import '../services.dart';
import '../paging.dart';

class VaultEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;
  @override
  bool get logSessions => false;

  String _actor(Session session) => session.authenticated!.userIdentifier;

  Future<List<OrganizationView>> organizations(
    Session session, {
    int? offset,
    int? limit,
  }) => VaultServices.instance.organizations.list(
    _actor(session),
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
  );
  Future<OrganizationView> createOrganization(Session session, String name) =>
      VaultServices.instance.organizations.create(_actor(session), name);
  Future<OrganizationView> renameOrganization(
    Session session,
    String organizationId,
    String name,
  ) => VaultServices.instance.organizations.rename(
    _actor(session),
    organizationId,
    name,
  );
  Future<List<MemberView>> members(
    Session session,
    String organizationId, {
    int? offset,
    int? limit,
  }) => VaultServices.instance.organizations.members(
    _actor(session),
    organizationId,
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
  );
  Future<void> addMember(
    Session session,
    String organizationId,
    String email,
    String role,
  ) => VaultServices.instance.organizations.addMember(
    _actor(session),
    organizationId,
    email,
    role,
  );
  Future<List<SecretView>> memberRemovalSecrets(
    Session session,
    String organizationId,
    String accountId, {
    int? offset,
    int? limit,
    int? utcOffsetMinutes,
  }) => VaultServices.instance.organizations.memberRemovalSecrets(
    _actor(session),
    organizationId,
    accountId,
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
    utcOffsetMinutes: utcOffsetMinutes ?? 0,
  );

  Future<void> removeMember(
    Session session,
    String organizationId,
    String accountId,
    List<String> reviewedSecretIds,
    List<String> rotateSecretIds, {
    int? utcOffsetMinutes,
  }) => VaultServices.instance.organizations.removeMember(
    _actor(session),
    organizationId,
    accountId,
    reviewedSecretIds: reviewedSecretIds,
    rotateSecretIds: rotateSecretIds,
    utcOffsetMinutes: utcOffsetMinutes ?? 0,
  );

  Future<SecretView> setSecretRotationRequired(
    Session session,
    String organizationId,
    String id,
    bool required,
  ) => VaultServices.instance.vault.setRotationRequired(
    _actor(session),
    organizationId,
    id,
    required,
  );

  Future<List<SecretView>> listSecrets(
    Session session,
    String organizationId, {
    int? offset,
    int? limit,
    String? query,
    String? project,
    String? environment,
  }) => VaultServices.instance.vault.list(
    _actor(session),
    organizationId,
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
    query: query ?? '',
    project: project,
    environment: environment,
  );

  Future<WorkspaceSummary> summary(
    Session session,
    String organizationId, {
    String? query,
    String? project,
    String? environment,
  }) => VaultServices.instance.vault.summary(
    _actor(session),
    organizationId,
    query: query ?? '',
    project: project,
    environment: environment,
  );
  Future<SecretView> saveSecret(
    Session session,
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
  }) => VaultServices.instance.vault.save(
    _actor(session),
    organizationId,
    id: id,
    name: name,
    value: value,
    project: project,
    environment: environment,
    kind: kind,
    description: description,
    username: username,
    url: url,
    expiresAt: expiresAt,
    // Clients predating these fields omit all three arguments. Preserve metadata.
    replaceMetadata: replaceMetadata ?? (url != null || expiresAt != null),
  );
  Future<String> revealSecret(
    Session session,
    String organizationId,
    String id,
  ) => VaultServices.instance.vault.reveal(_actor(session), organizationId, id);
  Future<SecretFields> revealSecretFields(
    Session session,
    String organizationId,
    String id,
  ) => VaultServices.instance.vault.revealFields(
    _actor(session),
    organizationId,
    id,
  );
  Future<void> deleteSecret(
    Session session,
    String organizationId,
    String id,
  ) => VaultServices.instance.vault.delete(_actor(session), organizationId, id);
  Future<List<AuditView>> activity(
    Session session,
    String organizationId, {
    int? offset,
    int? limit,
  }) => VaultServices.instance.tracking.list(
    _actor(session),
    organizationId,
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
  );
  Future<List<AuditView>> secretActivity(
    Session session,
    String organizationId,
    String secretId,
    String? beforeEventId, {
    int? offset,
    int? limit,
  }) => VaultServices.instance.tracking.forSecret(
    _actor(session),
    organizationId,
    secretId,
    beforeEventId: beforeEventId,
    offset: offset ?? 0,
    limit: limit ?? Pagination.defaultLimit,
  );
  Future<SecretCopy> copySecret(
    Session session,
    String organizationId,
    String id, {
    String? field,
  }) => VaultServices.instance.vault.copy(
    _actor(session),
    organizationId,
    id,
    field: field,
  );
  Future<void> confirmCopy(
    Session session,
    String organizationId,
    String secretId,
    String eventId,
  ) => VaultServices.instance.tracking.confirmCopy(
    _actor(session),
    organizationId,
    secretId,
    eventId,
  );
  Future<void> logout(Session session) => VaultServices.instance.accounts
      .revokeDigest(session.authenticated!.authId);
}
