import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:secretpod_server/src/storage/sqlite_session.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  late AuthResult owner;
  late OrganizationView organization;
  final key = base64Encode(List<int>.filled(32, 53));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-project-');
    services = await VaultServices.open(directory, key);
    owner = await services.accounts.register(
      'owner@example.test',
      'project-test-password',
      'Owner',
    );
    organization = await services.organizations.create(
      owner.account.id,
      'Team',
    );
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });

  Future<String> create(
    String actor,
    String name, {
    String? organizationId,
  }) async => await services.vault.createProject(
    actor,
    organizationId ?? organization.id,
    name,
  );

  Future<SecretView> secret(String name, String project) => services.vault.save(
    owner.account.id,
    organization.id,
    name: name,
    value: 'synthetic-project-secret',
    project: project,
    environment: 'Production',
    kind: 'API key',
    description: '',
  );

  test('summary includes stored empty projects without fake secrets', () async {
    await services.store.write((data) {
      data['projects'] = [
        {'organizationId': organization.id, 'name': 'Platform'},
      ];
    });
    final summary = await services.vault.summary(
      owner.account.id,
      organization.id,
    );
    expect(summary.projectCounts, {'Default': 0, 'Platform': 0});
    expect(summary.secretCount, 0);
    expect(
      await services.vault.list(owner.account.id, organization.id),
      isEmpty,
    );
  });

  test(
    'owner creates a trimmed empty project and audit that survive restart',
    () async {
      final before = await services.store.read((data) => data);
      expect(await create(owner.account.id, '  Platform  '), 'Platform');
      final after = await services.store.read((data) => data);
      for (final collection in [
        'accounts',
        'members',
        'secrets',
        'sessions',
        'organizations',
      ]) {
        expect(after[collection], before[collection]);
      }
      expect(rows(after, 'projects'), [
        {'organizationId': organization.id, 'name': 'Platform'},
      ]);
      final event = (await services.tracking.list(
        owner.account.id,
        organization.id,
      )).first;
      expect(event.action, 'created project');
      expect(event.target, 'Platform');
      expect(event.actorId, owner.account.id);
      expect(event.secretId, isNull);
      expect(
        (await services.tracking.list(
          owner.account.id,
          organization.id,
          project: 'Platform',
        )).single.id,
        event.id,
      );
      await services.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services.vault.summary(
          owner.account.id,
          organization.id,
        )).projectCounts,
        {'Default': 0, 'Platform': 0},
      );
      expect(
        await services.vault.list(owner.account.id, organization.id),
        isEmpty,
      );
    },
  );

  test('invalid and duplicate project names do not mutate records', () async {
    await create(owner.account.id, 'Platform');
    await secret('LEGACY', 'Legacy label');
    final before = await services.store.read((data) => data);
    for (final name in [
      '',
      '   ',
      'x' * 81,
      'DEFAULT',
      ' default ',
      'platform',
      ' PLATFORM ',
      'legacy LABEL',
    ]) {
      await expectLater(
        create(owner.account.id, name),
        throwsA(isA<VaultException>()),
      );
    }
    expect(await services.store.read((data) => data), before);
    expect((await create(owner.account.id, 'x' * 80)).length, 80);
  });

  test(
    'summary merges project counts case insensitively and preserves labels',
    () async {
      await create(owner.account.id, 'Platform');
      final one = await secret('ONE', 'platform');
      await secret('TWO', 'PLATFORM');
      await secret('THREE', 'Legacy label');
      final other = await services.organizations.create(
        owner.account.id,
        'Other',
      );
      await create(owner.account.id, 'Other only', organizationId: other.id);
      await create(owner.account.id, 'Platform', organizationId: other.id);
      final summary = await services.vault.summary(
        owner.account.id,
        organization.id,
        project: 'pLaTfOrM',
        query: 'ONE',
      );
      expect(summary.projectCounts, {
        'Default': 0,
        'Platform': 2,
        'Legacy label': 1,
      });
      expect(summary.filteredSecretCount, 1);
      expect(
        (await services.vault.list(
          owner.account.id,
          organization.id,
          project: 'PLATFORM',
        )).map((s) => s.project),
        containsAll(['platform', 'PLATFORM']),
      );
      await services.vault.delete(owner.account.id, organization.id, one.id);
      final remaining = await services.vault.list(
        owner.account.id,
        organization.id,
        project: 'Platform',
      );
      await services.vault.delete(
        owner.account.id,
        organization.id,
        remaining.single.id,
      );
      expect(
        (await services.vault.summary(
          owner.account.id,
          organization.id,
        )).projectCounts,
        {'Default': 0, 'Platform': 0, 'Legacy label': 1},
      );
    },
  );

  for (final role in ['editor', 'reader', 'outsider']) {
    test('$role project creation enforces organization write access', () async {
      final user = await services.accounts.register(
        '$role@example.test',
        'project-test-password',
        role,
      );
      if (role != 'outsider') {
        final invitation = await services.invitations.create(
          owner.account.id,
          organization.id,
          user.account.email,
          role,
          role,
        );
        await services.invitations.accept(
          user.account.id,
          invitation.invitation.id,
          invitation.token,
        );
      }
      final before = await services.store.read((data) => data);
      if (role == 'editor') {
        expect(
          await create(user.account.id, 'Editor project'),
          'Editor project',
        );
      } else {
        await expectLater(
          create(user.account.id, 'Forbidden'),
          throwsA(isA<VaultException>()),
        );
        expect(await services.store.read((data) => data), before);
      }
      await expectLater(
        create(owner.account.id, 'Unknown', organizationId: 'missing'),
        throwsA(isA<VaultException>()),
      );
    });
  }

  test(
    'concurrent case-insensitive duplicates commit exactly one project and audit',
    () async {
      final outcomes = await Future.wait(
        ['Platform', 'PLATFORM'].map((name) async {
          try {
            return await create(owner.account.id, name);
          } on VaultException {
            return null;
          }
        }),
      );
      expect(outcomes.whereType<String>(), hasLength(1));
      expect(
        await services.store.read((data) => rows(data, 'projects')),
        hasLength(1),
      );
      expect(
        (await services.tracking.list(
          owner.account.id,
          organization.id,
        )).where((event) => event.action == 'created project'),
        hasLength(1),
      );
    },
  );

  test(
    'project insertion failure rolls back the already inserted audit',
    () async {
      final before = await services.store.read((data) => data);
      await services.close();
      final database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      await database.db.unsafeExecute(
        "CREATE TRIGGER reject_project BEFORE INSERT ON vault_projects "
        "BEGIN SELECT RAISE(ABORT, 'test rejection'); END",
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      await expectLater(
        create(owner.account.id, 'Rejected project'),
        throwsA(anything),
      );
      expect(await services.store.read((data) => data), before);
      await services.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services.vault.summary(
          owner.account.id,
          organization.id,
        )).projectCounts,
        {'Default': 0},
      );
    },
  );
}
