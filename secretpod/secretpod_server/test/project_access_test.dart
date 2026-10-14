import 'dart:async';
import 'dart:convert';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/organization/organization_service.dart';
import 'package:secretpod_server/src/storage/sqlite_schema.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:secretpod_server/src/tracking/tracking_service.dart';
import 'package:secretpod_server/src/vault/vault_service.dart';
import 'package:test/test.dart';

class MemoryStore implements VaultStore {
  VaultData data = emptyVault();
  VaultData snapshot() => jsonDecode(jsonEncode(data)) as VaultData;
  @override
  Future<T> read<T>(T Function(VaultData) operation) async =>
      operation(snapshot());
  @override
  Future<T> write<T>(FutureOr<T> Function(VaultData) operation) async {
    final next = snapshot();
    final result = await operation(next);
    data = next;
    return result;
  }

  @override
  Future<void> close() async {}
}

void main() {
  late MemoryStore store;
  late VaultService vault;
  late OrganizationService organizations;
  late TrackingService tracking;
  late SecretView alpha, beta;
  Future<SecretView> save(String actor, String project, {String? id}) =>
      vault.save(
        actor,
        'org',
        id: id,
        name: 'API_KEY',
        value: 'synthetic-value',
        project: project,
        environment: 'Production',
        kind: 'API key',
        description: '',
      );
  Future<void> scope(String role, List<String>? read, List<String>? write) =>
      store.write((data) {
        final member = rows(
          data,
          'members',
        ).firstWhere((m) => m['accountId'] == 'member');
        member['role'] = role;
        member['readProjects'] = read == null ? null : jsonEncode(read);
        member['writeProjects'] = write == null ? null : jsonEncode(write);
      });
  setUp(() async {
    store = MemoryStore();
    for (final id in ['owner', 'member', 'outsider']) {
      rows(
        store.data,
        'accounts',
      ).add({'id': id, 'name': id, 'email': '$id@example.test'});
    }
    rows(
      store.data,
      'organizations',
    ).add({'id': 'org', 'name': 'Team', 'createdAt': '2026-10-14T00:00:00Z'});
    rows(store.data, 'members').addAll([
      {'organizationId': 'org', 'accountId': 'owner', 'role': 'owner'},
      {'organizationId': 'org', 'accountId': 'member', 'role': 'editor'},
    ]);
    vault = VaultService(
      store,
      CryptoService(base64Encode(List.filled(32, 41))),
    );
    organizations = OrganizationService(store);
    tracking = TrackingService(store);
    alpha = await save('owner', 'Alpha');
    beta = await save('owner', 'Beta');
  });

  test(
    'creators use project exclusions and can use newly created projects',
    () async {
      final dynamic service = organizations;
      await service.updateMemberAccess(
        'owner',
        'org',
        'member',
        'editor',
        canCreateProjects: true,
        deniedReadProjects: <String>['alpha'],
        deniedWriteProjects: <String>['Alpha', 'Beta'],
      );
      expect((await vault.list('member', 'org')).map((s) => s.id), [beta.id]);
      expect((await vault.summary('member', 'org')).projectCounts.keys, [
        'Default',
        'Beta',
      ]);
      expect((await tracking.list('member', 'org')).map((e) => e.secretId), [
        beta.id,
      ]);
      for (final operation in <Future<dynamic> Function()>[
        () => vault.reveal('member', 'org', alpha.id),
        () => vault.copy('member', 'org', alpha.id),
        () => tracking.forSecret('member', 'org', alpha.id),
        () => save('member', 'Beta', id: beta.id),
        () => vault.delete('member', 'org', alpha.id),
        () => vault.setRotationRequired('member', 'org', beta.id, true),
      ]) {
        await expectLater(operation(), throwsA(isA<VaultException>()));
      }
      await vault.createProject('member', 'org', 'Gamma');
      final gamma = await save('member', 'Gamma');
      expect(await vault.reveal('member', 'org', gamma.id), 'synthetic-value');
      final implicit = await save('member', 'Delta');
      expect(
        await vault.reveal('member', 'org', implicit.id),
        'synthetic-value',
      );
    },
  );

  test(
    'noncreator cannot bypass creation permission through secret save',
    () async {
      final dynamic service = organizations;
      await service.updateMemberAccess(
        'owner',
        'org',
        'member',
        'editor',
        canCreateProjects: false,
      );
      await save('member', 'Alpha', id: alpha.id);
      await expectLater(
        vault.createProject('member', 'org', 'Gamma'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        save('member', 'Gamma'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'creator allow lists and writes to denied reads are rejected atomically',
    () async {
      final dynamic service = organizations;
      final before = store.snapshot();
      await expectLater(
        service.updateMemberAccess(
          'owner',
          'org',
          'member',
          'editor',
          canCreateProjects: true,
          readProjects: <String>['Alpha'],
          writeProjects: <String>['Alpha'],
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        service.updateMemberAccess(
          'owner',
          'org',
          'member',
          'reader',
          canCreateProjects: true,
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        service.updateMemberAccess(
          'owner',
          'org',
          'member',
          'editor',
          deniedReadProjects: <String>['Alpha'],
          writeProjects: <String>['Alpha'],
        ),
        throwsA(isA<VaultException>()),
      );
      expect(store.data, before);
    },
  );

  test(
    'deleting the last legacy secret preserves an existing project for noncreators',
    () async {
      await store.write((data) => rows(data, 'projects').clear());
      await organizations.updateMemberAccess(
        'owner',
        'org',
        'member',
        'editor',
        readProjects: ['Alpha'],
        writeProjects: ['Alpha'],
        canCreateProjects: false,
      );
      await vault.delete('member', 'org', alpha.id);
      final recreated = await save('member', 'Alpha');
      expect(recreated.project, 'Alpha');
      await organizations.updateMemberAccess(
        'owner',
        'org',
        'member',
        'editor',
        canCreateProjects: false,
      );
      await vault.delete('member', 'org', recreated.id);
      expect((await vault.summary('member', 'org')).projectCounts['Alpha'], 0);
      expect((await save('member', 'Alpha')).project, 'Alpha');
    },
  );

  test('malformed stored exclusions deny access', () async {
    await store.write((data) {
      rows(data, 'members').last['deniedReadProjects'] = 'invalid-json';
    });
    expect(await vault.list('member', 'org'), isEmpty);
    await expectLater(
      vault.createProject('member', 'org', 'Gamma'),
      throwsA(isA<VaultException>()),
    );
  });

  test(
    'project scope filters lists, counts and history before pagination',
    () async {
      await scope('reader', ['alpha'], []);
      expect((await vault.list('member', 'org')).map((s) => s.id), [alpha.id]);
      expect(await vault.list('member', 'org', offset: 1), isEmpty);
      final summary = await vault.summary('member', 'org');
      expect(summary.secretCount, 1);
      expect(summary.projectCounts.keys, ['Alpha']);
      expect(summary.activityCount, 1);
      expect(summary.activityProjects, ['Alpha']);
      expect((await tracking.list('member', 'org')).map((e) => e.secretId), [
        alpha.id,
      ]);
    },
  );

  test('all secret read paths and history deny another project', () async {
    await scope('reader', ['Alpha'], []);
    expect(await vault.reveal('member', 'org', alpha.id), 'synthetic-value');
    final before = store.snapshot();
    for (final operation in <Future<dynamic> Function()>[
      () => vault.reveal('member', 'org', beta.id),
      () => vault.revealFields('member', 'org', beta.id),
      () => vault.copy('member', 'org', beta.id),
      () => tracking.forSecret('member', 'org', beta.id),
    ]) {
      await expectLater(operation(), throwsA(isA<VaultException>()));
    }
    expect(store.data, before);
  });

  test(
    'read all with scoped write checks source and destination projects',
    () async {
      await scope('editor', null, ['Alpha']);
      expect(await vault.list('member', 'org'), hasLength(2));
      await save('member', 'Alpha', id: alpha.id);
      for (final operation in <Future<dynamic> Function()>[
        () => save('member', 'Beta', id: beta.id),
        () => save('member', 'Beta', id: alpha.id),
        () => save('member', 'Alpha', id: beta.id),
        () => save('member', 'Gamma'),
        () => vault.delete('member', 'org', beta.id),
        () => vault.setRotationRequired('member', 'org', beta.id, true),
        () => vault.createProject('member', 'org', 'Gamma'),
      ]) {
        await expectLater(operation(), throwsA(isA<VaultException>()));
      }
    },
  );

  test(
    'owner updates role and scopes atomically and records changes once',
    () async {
      final dynamic service = organizations;
      final result = await service.updateMemberAccess(
        'owner',
        'org',
        'member',
        'reader',
        readProjects: <String>[' alpha ', 'ALPHA'],
        writeProjects: <String>[],
      );
      expect(result.role, 'reader');
      expect(result.readProjects, ['Alpha']);
      await expectLater(
        save('member', 'Alpha', id: alpha.id),
        throwsA(isA<VaultException>()),
      );
      final before = store.snapshot();
      await service.updateMemberAccess(
        'owner',
        'org',
        'member',
        'reader',
        readProjects: <String>['Alpha'],
        writeProjects: <String>[],
      );
      expect(store.data, before);
      expect(
        (await tracking.list(
          'owner',
          'org',
        )).where((e) => e.action == 'changed member access'),
        hasLength(1),
      );
    },
  );

  test(
    'revocation blocks pending copy acknowledgments and hides moved-secret history',
    () async {
      await scope('reader', ['Alpha'], []);
      final receipt = await vault.copy('member', 'org', alpha.id);
      await scope('reader', ['Beta'], []);
      await expectLater(
        tracking.confirmCopy('member', 'org', alpha.id, receipt.eventId),
        throwsA(isA<VaultException>()),
      );
      await scope('reader', ['Alpha'], []);
      await vault.save(
        'owner',
        'org',
        id: alpha.id,
        name: 'MOVED_KEY',
        value: null,
        project: 'Beta',
        environment: 'Production',
        kind: 'API key',
        description: '',
      );
      expect(await tracking.list('member', 'org'), isEmpty);
      expect((await vault.summary('member', 'org')).activityCount, 0);
    },
  );

  test(
    'restricted history never guesses a project for legacy events',
    () async {
      await store.write((data) {
        rows(data, 'events').first.remove('project');
      });
      await scope('reader', ['Alpha'], []);
      expect(await tracking.forSecret('member', 'org', alpha.id), isEmpty);
      expect(await tracking.list('member', 'org'), isEmpty);
      expect((await tracking.list('owner', 'org')).length, 2);
    },
  );

  test(
    'role changes preserve existing access to an emptied implicit project',
    () async {
      await organizations.updateMemberAccess(
        'owner',
        'org',
        'member',
        'reader',
        readProjects: ['Alpha'],
      );
      await vault.delete('owner', 'org', alpha.id);
      final updated = await organizations.updateMemberAccess(
        'owner',
        'org',
        'member',
        'editor',
        readProjects: ['alpha'],
        writeProjects: [],
      );
      expect(updated.readProjects, ['Alpha']);
      expect(
        (await tracking.list(
          'member',
          'org',
        )).where((event) => event.secretId == alpha.id),
        hasLength(2),
      );
    },
  );

  test('only owner can edit members and ownership cannot be changed', () async {
    final dynamic service = organizations;
    for (final actor in ['member', 'outsider']) {
      await expectLater(
        service.updateMemberAccess(actor, 'org', 'member', 'reader'),
        throwsA(isA<VaultException>()),
      );
    }
    for (final target in ['owner', 'outsider']) {
      await expectLater(
        service.updateMemberAccess('owner', 'org', target, 'reader'),
        throwsA(isA<VaultException>()),
      );
    }
    for (final role in ['owner', 'invalid']) {
      await expectLater(
        service.updateMemberAccess('owner', 'org', 'member', role),
        throwsA(isA<VaultException>()),
      );
    }
  });

  test(
    'invalid scopes cannot grant writes without reads or invent projects',
    () async {
      final dynamic service = organizations;
      final before = store.snapshot();
      for (final scopes in [
        (<String>['Alpha'], <String>['Beta']),
        (<String>['Alpha'], null),
        (<String>['Missing'], <String>[]),
      ]) {
        await expectLater(
          service.updateMemberAccess(
            'owner',
            'org',
            'member',
            'editor',
            readProjects: scopes.$1,
            writeProjects: scopes.$2,
          ),
          throwsA(isA<VaultException>()),
        );
      }
      expect(store.data, before);
    },
  );

  test(
    'missing scopes retain legacy access; explicit empty scope denies secrets',
    () async {
      expect(await vault.list('member', 'org'), hasLength(2));
      await scope('editor', [], []);
      expect(await vault.list('member', 'org'), isEmpty);
      await expectLater(
        save('member', 'Alpha'),
        throwsA(isA<VaultException>()),
      );
      expect(await vault.list('owner', 'org'), hasLength(2));
    },
  );
}
