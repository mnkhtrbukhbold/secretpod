import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/storage/sqlite_session.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  final key = base64Encode(List.filled(32, 42));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('access-persistence-');
    services = await VaultServices.open(directory, key);
    await services.store.write((data) {
      for (final id in ['owner', 'member']) {
        (data['accounts'] as List).add({
          'id': id,
          'name': id,
          'email': '$id@example.test',
          'salt': 'fixture',
          'passwordHash': 'fixture',
        });
      }
      (data['organizations'] as List).add({
        'id': 'org',
        'name': 'Team',
        'createdAt': '2026-10-14T00:00:00Z',
      });
      (data['members'] as List).add({
        'organizationId': 'org',
        'accountId': 'owner',
        'role': 'owner',
      });
    });
    await services.vault.createProject('owner', 'org', 'Alpha');
    await services.vault.createProject('owner', 'org', 'Beta');
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });

  test(
    'creator exclusions survive invitation acceptance and database reopen',
    () async {
      final invite = await services.invitations.create(
        'owner',
        'org',
        'member@example.test',
        'Member',
        'editor',
        canCreateProjects: true,
        deniedReadProjects: ['Alpha'],
        deniedWriteProjects: ['Alpha', 'Beta'],
      );
      expect(
        (await services.invitations.preview(invite.token)).deniedReadProjects,
        ['Alpha'],
      );
      await services.invitations.accept(
        'member',
        invite.invitation.id,
        invite.token,
      );
      await services.close();
      services = await VaultServices.open(directory, key);
      final member = (await services.organizations.list('member')).single;
      expect(member.canCreateProjects, isTrue);
      expect(member.deniedReadProjects, ['Alpha']);
      expect(member.deniedWriteProjects, ['Alpha', 'Beta']);
      expect(
        (await services.vault.summary('member', 'org')).projectCounts.keys,
        containsAll(['Default', 'Beta']),
      );
      expect(
        (await services.vault.summary('member', 'org')).projectCounts.keys,
        isNot(contains('Alpha')),
      );
      await services.vault.createProject('member', 'org', 'Gamma');
      final secret = await services.vault.save(
        'member',
        'org',
        name: 'NEW',
        value: 'fixture',
        project: 'Gamma',
        environment: 'Production',
        kind: 'API key',
        description: '',
      );
      await services.organizations.updateMemberAccess(
        'owner',
        'org',
        'member',
        'editor',
        canCreateProjects: false,
        deniedReadProjects: ['Alpha', 'Gamma'],
        deniedWriteProjects: ['Alpha', 'Beta', 'Gamma'],
      );
      await expectLater(
        services.tracking.forSecret('member', 'org', secret.id),
        throwsA(isA<VaultException>()),
      );
      await services.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services.organizations.members(
          'owner',
          'org',
        )).last.canCreateProjects,
        isFalse,
      );
      await expectLater(
        services.vault.createProject('member', 'org', 'Delta'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'invitation scopes survive acceptance, role change and database reopen',
    () async {
      final invite = await services.invitations.create(
        'owner',
        'org',
        'member@example.test',
        'Member',
        'editor',
        readProjects: ['alpha'],
        writeProjects: ['Alpha'],
      );
      expect(invite.invitation.readProjects, ['Alpha']);
      expect((await services.invitations.preview(invite.token)).writeProjects, [
        'Alpha',
      ]);
      await services.invitations.accept(
        'member',
        invite.invitation.id,
        invite.token,
      );
      expect(
        (await services.organizations.list('member')).single.readProjects,
        ['Alpha'],
      );
      await services.close();
      services = await VaultServices.open(directory, key);
      final org = (await services.organizations.list('member')).single;
      expect(org.readProjects, ['Alpha']);
      expect(org.writeProjects, ['Alpha']);
      final secret = await services.vault.save(
        'member',
        'org',
        name: 'KEY',
        value: 'fixture-value',
        project: 'Alpha',
        environment: 'Production',
        kind: 'API key',
        description: '',
      );
      await services.organizations.updateMemberAccess(
        'owner',
        'org',
        'member',
        'reader',
        readProjects: ['Beta'],
      );
      await services.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services.organizations.members('owner', 'org')).last.role,
        'reader',
      );
      await expectLater(
        services.vault.reveal('member', 'org', secret.id),
        throwsA(isA<VaultException>()),
      );
      expect((await services.vault.summary('member', 'org')).projectCounts, {
        'Beta': 0,
      });
    },
  );

  test(
    'signup-and-accept uses the same scoped membership as existing accounts',
    () async {
      final invite = await services.invitations.create(
        'owner',
        'org',
        'new@example.test',
        'New member',
        'reader',
        readProjects: ['Beta'],
        writeProjects: [],
      );
      final result = await services.invitations.registerAndAccept(
        invite.token,
        'New member',
        'test-password-123!',
      );
      expect(
        (await services.organizations.list(
          result.account.id,
        )).single.readProjects,
        ['Beta'],
      );
    },
  );

  test(
    'schema eight migration retains legacy member and pending invite access',
    () async {
      final invite = await services.invitations.create(
        'owner',
        'org',
        'member@example.test',
        'Member',
        'editor',
      );
      await services.close();
      final database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      for (final table in ['members', 'invitations']) {
        final columns = (await database.db.unsafeQuery(
          'PRAGMA table_info(vault_$table)',
        )).map((row) => row[1]).toSet();
        for (final field in [
          'readProjects',
          'writeProjects',
          'deniedReadProjects',
          'deniedWriteProjects',
          'canCreateProjects',
          if (table == 'members') 'accessDisabled',
        ]) {
          if (!columns.contains(field)) continue;
          await database.db.unsafeExecute(
            'ALTER TABLE vault_$table DROP COLUMN $field',
          );
        }
      }
      await database.db.unsafeExecute('PRAGMA user_version = 8');
      await database.close();
      services = await VaultServices.open(directory, key);
      await services.invitations.accept(
        'member',
        invite.invitation.id,
        invite.token,
      );
      final member = (await services.organizations.list('member')).single;
      expect(member.readProjects, isNull);
      expect(member.writeProjects, isNull);
      expect(
        (await services.vault.summary('member', 'org')).projectCounts.keys,
        containsAll(['Default', 'Alpha', 'Beta']),
      );
    },
  );
}
