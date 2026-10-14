import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../account/account_service.dart';
import '../generated/protocol.dart';
import '../storage/vault_store.dart';
import '../tracking/tracking_service.dart';
import '../validation.dart';
import 'access.dart';
import '../paging.dart';
import '../vault/vault_service.dart';
import '../vault/rotation.dart';

class OrganizationService {
  OrganizationService(this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final VaultStore store;
  final DateTime Function() _now;

  Future<OrganizationView> create(String actor, String name) {
    name = bounded(name, 'Organization name', max: 80);
    return store.write((data) {
      if (!rows(data, 'accounts').any((a) => a['id'] == actor)) {
        throw VaultException(message: 'Sign in to continue.');
      }
      final org = <String, dynamic>{
        'id': const Uuid().v4(),
        'name': name,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      rows(data, 'organizations').add(org);
      rows(
        data,
        'members',
      ).add({'organizationId': org['id'], 'accountId': actor, 'role': 'owner'});
      recordEvent(
        data,
        actor,
        org['id'] as String,
        'created organization',
        name,
      );
      return _view(org, 'owner');
    });
  }

  Future<List<OrganizationView>> list(
    String actor, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
  }) => store.read((data) {
    final memberships = rows(
      data,
      'members',
    ).where((m) => m['accountId'] == actor && m['accessDisabled'] != 1);
    return Pagination(offset: offset, limit: limit)
        .apply(memberships)
        .map(
          (m) => _view(
            rows(
              data,
              'organizations',
            ).firstWhere((o) => o['id'] == m['organizationId']),
            m['role'] as String,
            member: m,
          ),
        )
        .toList();
  });

  Future<OrganizationView> rename(
    String actor,
    String organizationId,
    String name,
  ) => store.write((data) {
    final role = requireMembership(data, actor, organizationId, owner: true);
    final nextName = bounded(name, 'Organization name', max: 80);
    final organization = rows(data, 'organizations').firstWhere(
      (o) => o['id'] == organizationId,
    );
    final previousName = organization['name'] as String;
    if (nextName != previousName) {
      organization['name'] = nextName;
      recordEvent(
        data,
        actor,
        organizationId,
        'renamed organization',
        nextName,
        details: 'Previous name: $previousName',
      );
    }
    return _view(organization, role);
  });

  Future<List<MemberView>> members(
    String actor,
    String organizationId, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
  }) => store.read((data) {
    requireMembership(data, actor, organizationId);
    return Pagination(offset: offset, limit: limit)
        .apply(
          rows(
            data,
            'members',
          ).where((m) => m['organizationId'] == organizationId),
        )
        .map(
          (m) => MemberView(
            account: AccountService.view(
              rows(
                data,
                'accounts',
              ).firstWhere((a) => a['id'] == m['accountId']),
            ),
            role: m['role'] as String,
            accessDisabled: m['accessDisabled'] == 1,
            readProjects: projectScope(m, 'readProjects'),
            writeProjects: projectScope(m, 'writeProjects'),
            deniedReadProjects: projectScope(m, 'deniedReadProjects'),
            deniedWriteProjects: projectScope(m, 'deniedWriteProjects'),
            canCreateProjects: projectCreationAllowed(m),
          ),
        )
        .toList();
  });

  Future<void> addMember(
    String actor,
    String organizationId,
    String email,
    String role,
  ) async {
    throw VaultException(
      message:
          'Direct member addition is disabled. Create an invitation and wait for acceptance.',
    );
  }

  Future<MemberView> updateMemberAccess(
    String actor,
    String organizationId,
    String accountId,
    String role, {
    List<String>? readProjects,
    List<String>? writeProjects,
    List<String>? deniedReadProjects,
    List<String>? deniedWriteProjects,
    bool? canCreateProjects,
  }) => store.write((data) {
    final member = _removableMember(data, actor, organizationId, accountId);
    final scopes = validateProjectScopes(
      data,
      organizationId,
      role,
      readProjects,
      writeProjects,
      existingMember: member,
      deniedReadProjects: deniedReadProjects,
      deniedWriteProjects: deniedWriteProjects,
      canCreateProjects: canCreateProjects,
    );
    final read = scopes.read == null ? null : jsonEncode(scopes.read);
    final write = scopes.write == null ? null : jsonEncode(scopes.write);
    final deniedRead = jsonEncode(scopes.deniedRead);
    final deniedWrite = jsonEncode(scopes.deniedWrite);
    final create = scopes.create ? 1 : 0;
    final account = rows(
      data,
      'accounts',
    ).firstWhere((a) => a['id'] == accountId);
    if (member['role'] != role ||
        member['readProjects'] != read ||
        member['writeProjects'] != write ||
        member['deniedReadProjects'] != deniedRead ||
        member['deniedWriteProjects'] != deniedWrite ||
        member['canCreateProjects'] != create) {
      final previousRole = member['role'];
      member['role'] = role;
      member['readProjects'] = read;
      member['writeProjects'] = write;
      member['deniedReadProjects'] = deniedRead;
      member['deniedWriteProjects'] = deniedWrite;
      member['canCreateProjects'] = create;
      recordEvent(
        data,
        actor,
        organizationId,
        'changed member access',
        account['email'] as String,
        details:
            'Role: $previousRole → $role; Read: ${scopes.read?.join(', ') ?? 'all projects'}; Write: ${scopes.write?.join(', ') ?? 'all projects'}; Denied read: ${scopes.deniedRead.join(', ')}; Denied write: ${scopes.deniedWrite.join(', ')}; Create projects: ${scopes.create}',
      );
    }
    return MemberView(
      account: AccountService.view(account),
      role: role,
      accessDisabled: member['accessDisabled'] == 1,
      readProjects: scopes.read,
      writeProjects: scopes.write,
      deniedReadProjects: scopes.deniedRead,
      deniedWriteProjects: scopes.deniedWrite,
      canCreateProjects: scopes.create,
    );
  });

  Future<List<SecretView>> memberRemovalSecrets(
    String actor,
    String organizationId,
    String accountId, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
    int utcOffsetMinutes = 0,
  }) => store.read((data) {
    _removableMember(data, actor, organizationId, accountId);
    return Pagination(offset: offset, limit: limit)
        .apply(
          _accessedSecrets(data, organizationId, accountId, utcOffsetMinutes),
        )
        .map(VaultService.view)
        .toList();
  });

  Future<void> removeMember(
    String actor,
    String organizationId,
    String accountId, {
    required List<String> reviewedSecretIds,
    required List<String> rotateSecretIds,
    int utcOffsetMinutes = 0,
  }) => store.write((data) {
    final member = _removableMember(data, actor, organizationId, accountId);
    final selectedCount = _markReviewedSecrets(
      data,
      actor,
      organizationId,
      accountId,
      reviewedSecretIds,
      rotateSecretIds,
      utcOffsetMinutes,
      reason: 'Member removed',
    );
    final account = rows(
      data,
      'accounts',
    ).firstWhere((a) => a['id'] == accountId);
    rows(data, 'members').remove(member);
    recordEvent(
      data,
      actor,
      organizationId,
      'removed member',
      '${account['name']} (${account['email']})',
      details: 'Account: $accountId; selected for rotation: $selectedCount',
    );
  });

  Future<MemberView> setMemberEnabled(
    String actor,
    String organizationId,
    String accountId,
    bool enabled, {
    List<String> reviewedSecretIds = const [],
    List<String> rotateSecretIds = const [],
    int utcOffsetMinutes = 0,
  }) => store.write((data) {
    final member = _removableMember(data, actor, organizationId, accountId);
    if (enabled &&
        (reviewedSecretIds.isNotEmpty || rotateSecretIds.isNotEmpty)) {
      throw VaultException(
        message: 'Re-enabling access does not change rotation flags.',
      );
    }
    final selectedCount = enabled
        ? 0
        : _markReviewedSecrets(
            data,
            actor,
            organizationId,
            accountId,
            reviewedSecretIds,
            rotateSecretIds,
            utcOffsetMinutes,
            reason: 'Member access disabled',
          );
    final account = rows(
      data,
      'accounts',
    ).firstWhere((a) => a['id'] == accountId);
    if ((member['accessDisabled'] == 1) == enabled) {
      member['accessDisabled'] = enabled ? 0 : 1;
      recordEvent(
        data,
        actor,
        organizationId,
        enabled ? 'enabled member access' : 'disabled member access',
        '${account['name']} (${account['email']})',
        details: 'Account: $accountId; selected for rotation: $selectedCount',
      );
    }
    return MemberView(
      account: AccountService.view(account),
      role: member['role'] as String,
      accessDisabled: member['accessDisabled'] == 1,
      readProjects: projectScope(member, 'readProjects'),
      writeProjects: projectScope(member, 'writeProjects'),
      deniedReadProjects: projectScope(member, 'deniedReadProjects'),
      deniedWriteProjects: projectScope(member, 'deniedWriteProjects'),
      canCreateProjects: projectCreationAllowed(member),
    );
  });

  int _markReviewedSecrets(
    VaultData data,
    String actor,
    String organizationId,
    String accountId,
    List<String> reviewedSecretIds,
    List<String> rotateSecretIds,
    int utcOffsetMinutes, {
    required String reason,
  }) {
    final secrets = _accessedSecrets(
      data,
      organizationId,
      accountId,
      utcOffsetMinutes,
    );
    final current = secrets.map((s) => s['id'] as String).toSet();
    final reviewed = reviewedSecretIds.toSet();
    if (current.length != reviewed.length || !current.containsAll(reviewed)) {
      throw VaultException(
        message:
            'Secret access changed. Refresh the review before changing this member’s access.',
      );
    }
    final selected = rotateSecretIds.toSet();
    if (!current.containsAll(selected)) {
      throw VaultException(
        message: 'Choose secrets from this member’s current access review.',
      );
    }
    for (final secret in secrets.where((s) => selected.contains(s['id']))) {
      markSecretRotation(
        data,
        actor,
        secret,
        true,
        details: '$reason: $accountId',
      );
    }
    return selected.length;
  }

  Map<String, dynamic> _removableMember(
    VaultData data,
    String actor,
    String organizationId,
    String accountId,
  ) {
    requireMembership(data, actor, organizationId, owner: true);
    final member = rows(data, 'members')
        .where(
          (m) =>
              m['organizationId'] == organizationId &&
              m['accountId'] == accountId,
        )
        .firstOrNull;
    if (member == null) throw VaultException(message: 'Member not found.');
    if (member['role'] == 'owner' || accountId == actor) {
      throw VaultException(
        message: 'The organization owner cannot be removed or disabled.',
      );
    }
    return member;
  }

  List<Map<String, dynamic>> _accessedSecrets(
    VaultData data,
    String organizationId,
    String accountId,
    int utcOffsetMinutes,
  ) {
    if (utcOffsetMinutes < -720 || utcOffsetMinutes > 840) {
      throw VaultException(message: 'Invalid time zone offset.');
    }
    final localNow = _now().toUtc().add(Duration(minutes: utcOffsetMinutes));
    final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
    const actions = {
      'created',
      'updated',
      'rotated',
      'saved',
      'revealed',
      'copy requested',
      'copied',
    };
    final accessed = rows(data, 'events')
        .where(
          (e) =>
              e['organizationId'] == organizationId &&
              e['actorId'] == accountId &&
              e['secretId'] != null &&
              actions.contains(e['action']),
        )
        .map((e) => e['secretId'])
        .toSet();
    return rows(data, 'secrets').where((s) {
      if (s['organizationId'] != organizationId ||
          !accessed.contains(s['id'])) {
        return false;
      }
      final expiry = s['expiresAt'] as String?;
      return expiry == null || !DateTime.parse(expiry).isBefore(today);
    }).toList()..sort(
      (a, b) => (a['id'] as String).compareTo(b['id'] as String),
    );
  }

  static OrganizationView _view(
    Map<String, dynamic> o,
    String role, {
    Map<String, dynamic>? member,
  }) => OrganizationView(
    id: o['id'] as String,
    name: o['name'] as String,
    role: role,
    createdAt: DateTime.parse(o['createdAt'] as String),
    readProjects: member == null ? null : projectScope(member, 'readProjects'),
    writeProjects: member == null
        ? null
        : projectScope(member, 'writeProjects'),
    deniedReadProjects: member == null
        ? null
        : projectScope(member, 'deniedReadProjects'),
    deniedWriteProjects: member == null
        ? null
        : projectScope(member, 'deniedWriteProjects'),
    canCreateProjects: member == null ? null : projectCreationAllowed(member),
  );
}
