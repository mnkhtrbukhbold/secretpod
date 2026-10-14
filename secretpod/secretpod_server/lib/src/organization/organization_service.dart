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
    ).where((m) => m['accountId'] == actor);
    return Pagination(offset: offset, limit: limit)
        .apply(memberships)
        .map(
          (m) => _view(
            rows(
              data,
              'organizations',
            ).firstWhere((o) => o['id'] == m['organizationId']),
            m['role'] as String,
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
            'Secret access changed. Refresh the review before removing this member.',
      );
    }
    final selected = rotateSecretIds.toSet();
    if (!current.containsAll(selected)) {
      throw VaultException(
        message: 'Choose secrets from this member’s current access review.',
      );
    }
    final account = rows(
      data,
      'accounts',
    ).firstWhere((a) => a['id'] == accountId);
    for (final secret in secrets.where((s) => selected.contains(s['id']))) {
      markSecretRotation(
        data,
        actor,
        secret,
        true,
        details: 'Member removed: $accountId',
      );
    }
    rows(data, 'members').remove(member);
    recordEvent(
      data,
      actor,
      organizationId,
      'removed member',
      '${account['name']} (${account['email']})',
      details: 'Account: $accountId; selected for rotation: ${selected.length}',
    );
  });

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
        message: 'The organization owner cannot be removed.',
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

  static OrganizationView _view(Map<String, dynamic> o, String role) =>
      OrganizationView(
        id: o['id'] as String,
        name: o['name'] as String,
        role: role,
        createdAt: DateTime.parse(o['createdAt'] as String),
      );
}
