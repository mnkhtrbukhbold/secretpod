import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:secretpod_server/src/organization/organization_service.dart';
import 'package:secretpod_server/src/tracking/tracking_service.dart';
import 'package:secretpod_server/src/vault/vault_service.dart';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/account/account_service.dart';
import 'package:secretpod_server/src/invitation/invitation_service.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:test/test.dart';
import 'dart:async';
import 'dart:convert';

class MemoryStore implements VaultStore {
  final VaultData data = {
    'accounts': <Map<String, dynamic>>[],
    'organizations': <Map<String, dynamic>>[],
    'members': <Map<String, dynamic>>[],
    'events': <Map<String, dynamic>>[],
    'secrets': <Map<String, dynamic>>[],
    'invitations': <Map<String, dynamic>>[],
    'projects': <Map<String, dynamic>>[],
  };
  @override
  Future<T> read<T>(T Function(VaultData) operation) async => operation(data);
  @override
  Future<T> write<T>(FutureOr<T> Function(VaultData) operation) async =>
      operation(data);
  @override
  Future<void> close() async {}
}

void main() {
  late MemoryStore store;
  setUp(() {
    store = MemoryStore();
    for (var i = 0; i < 230; i++) {
      rows(
        store.data,
        'accounts',
      ).add({'id': 'a$i', 'name': 'User $i', 'email': 'a$i@example.test'});
      rows(store.data, 'organizations').add({
        'id': 'o$i',
        'name': 'Team $i',
        'createdAt': '2026-10-14T00:00:00Z',
      });
      rows(
        store.data,
        'members',
      ).add({'accountId': 'a0', 'organizationId': 'o$i', 'role': 'owner'});
      if (i > 0) {
        rows(
          store.data,
          'members',
        ).add({'accountId': 'a$i', 'organizationId': 'o0', 'role': 'reader'});
      }
      rows(store.data, 'events').add({
        'id': 'e$i',
        'organizationId': 'o0',
        'actor': 'User',
        'action': 'created',
        'target': 'fixture',
        'createdAt': '2026-10-14T00:00:00Z',
      });
      rows(store.data, 'events').last['secretId'] = 's0';
      rows(store.data, 'secrets').add({
        'id': 's$i',
        'organizationId': 'o0',
        'name': 'Secret $i',
        'project': i < 200 ? 'Default' : 'Other',
        'environment': 'Production',
        'kind': 'API key',
        'description': 'fixture',
        'version': 1,
        'createdAt': '2026-10-14T00:00:00Z',
        'updatedAt': '2026-10-14T00:00:00Z',
      });
      rows(store.data, 'invitations').add({
        'id': 'i$i',
        'organizationId': 'o0',
        'inviterId': 'a0',
        'inviterName': 'Owner',
        'inviterEmail': 'a0@example.test',
        'recipientEmail': 'a0@example.test',
        'recipientName': 'Owner',
        'role': 'reader',
        'status': 'pending',
        'createdAt': '2026-10-14T00:00:00Z',
        'expiresAt': '2099-10-14T00:00:00Z',
      });
    }
  });

  test('all large organization lists default to 10 records', () async {
    final organizations = OrganizationService(store);
    expect(await organizations.list('a0'), hasLength(10));
    expect(await organizations.members('a0', 'o0'), hasLength(10));
    expect(await TrackingService(store).list('a0', 'o0'), hasLength(10));
    expect(
      await TrackingService(store).forSecret('a0', 'o0', 's0'),
      hasLength(10),
    );
    expect(
      await VaultService(
        store,
        CryptoService(base64Encode(List.filled(32, 1))),
      ).list('a0', 'o0'),
      hasLength(10),
    );
    final invitations = InvitationService(store, AccountService(store));
    expect(await invitations.inbox('a0'), hasLength(10));
    expect(await invitations.outgoing('a0', 'o0'), hasLength(10));
  });

  test('every list supports bounded pages and rejects invalid input', () async {
    dynamic organizations = OrganizationService(store);
    dynamic tracking = TrackingService(store);
    dynamic vault = VaultService(
      store,
      CryptoService(base64Encode(List.filled(32, 1))),
    );
    dynamic invitations = InvitationService(store, AccountService(store));
    final operations = <Future<dynamic> Function(int, int)>[
      (offset, limit) => organizations.list('a0', offset: offset, limit: limit),
      (offset, limit) =>
          organizations.members('a0', 'o0', offset: offset, limit: limit),
      (offset, limit) => vault.list('a0', 'o0', offset: offset, limit: limit),
      (offset, limit) =>
          tracking.list('a0', 'o0', offset: offset, limit: limit),
      (offset, limit) =>
          tracking.forSecret('a0', 'o0', 's0', offset: offset, limit: limit),
      (offset, limit) => invitations.inbox('a0', offset: offset, limit: limit),
      (offset, limit) =>
          invitations.outgoing('a0', 'o0', offset: offset, limit: limit),
    ];
    for (final operation in operations) {
      expect(await operation(0, 25), hasLength(25));
      expect(await operation(225, 25), hasLength(5));
      expect(await operation(230, 25), isEmpty);
      expect(await operation(0, 100), hasLength(100));
      for (final bounds in [
        [-1, 25],
        [0, 0],
        [0, 101],
      ]) {
        await expectLater(
          Future.sync(() => operation(bounds[0], bounds[1])),
          throwsA(isA<VaultException>()),
        );
      }
    }
    final first =
        await tracking.list('a0', 'o0', offset: 0, limit: 100)
            as List<AuditView>;
    final second =
        await tracking.list('a0', 'o0', offset: 100, limit: 100)
            as List<AuditView>;
    final third =
        await tracking.list('a0', 'o0', offset: 200, limit: 100)
            as List<AuditView>;
    expect({
      ...first.map((e) => e.id),
      ...second.map((e) => e.id),
      ...third.map((e) => e.id),
    }, hasLength(230));
    expect(third.last.id, 'e0');
    for (final operation in [
      () => organizations.members('outsider', 'o0', offset: 25),
      () => tracking.list('outsider', 'o0', offset: 25),
      () => tracking.forSecret('outsider', 'o0', 's0', offset: 25),
      () => invitations.outgoing('a1', 'o0', offset: 25),
      () => invitations.inbox('outsider', offset: 25),
      () => tracking.forSecret(
        'a0',
        'o0',
        's0',
        offset: 1,
        beforeEventId: 'e229',
      ),
    ]) {
      await expectLater(Future.sync(operation), throwsA(isA<VaultException>()));
    }
  });

  test(
    'secret filters run before paging and summaries cover all records',
    () async {
      dynamic vault = VaultService(
        store,
        CryptoService(base64Encode(List.filled(32, 1))),
      );
      expect(await vault.list('a0', 'o0', project: 'other'), hasLength(10));
      expect(
        await vault.list('a0', 'o0', project: 'OTHER', offset: 25),
        hasLength(5),
      );
      expect(await vault.list('a0', 'o0', query: 'Secret 229'), hasLength(1));
      expect(await vault.list('a0', 'o0', environment: 'Development'), isEmpty);
      final summary = await vault.summary('a0', 'o0', project: 'Other');
      expect(summary.secretCount, 230);
      expect(summary.filteredSecretCount, 30);
      expect(summary.memberCount, 230);
      expect(summary.activityCount, 230);
      expect(summary.projectCounts['Other'], 30);
      await expectLater(
        vault.list('outsider', 'o0', offset: 25),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        vault.summary('outsider', 'o0'),
        throwsA(isA<VaultException>()),
      );
    },
  );
}
