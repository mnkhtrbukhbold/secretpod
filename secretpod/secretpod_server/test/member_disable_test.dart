import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  late SecretView secret;
  final key = base64Encode(List.filled(32, 39));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-disable-');
    services = await VaultServices.open(directory, key);
    await services.store.write((data) {
      for (final id in ['owner', 'editor', 'reader', 'outsider']) {
        (data['accounts'] as List).add({
          'id': id,
          'email': '$id@example.test',
          'name': id,
          'salt': 'fixture',
          'passwordHash': 'fixture',
        });
      }
      for (final org in ['org', 'other']) {
        (data['organizations'] as List).add({
          'id': org,
          'name': org,
          'createdAt': '2026-10-14T00:00:00Z',
        });
        for (final actor in ['owner', 'editor', 'reader']) {
          (data['members'] as List).add({
            'organizationId': org,
            'accountId': actor,
            'role': actor,
          });
        }
      }
    });
    secret = await services.vault.save(
      'editor',
      'org',
      name: 'API_KEY',
      value: 'synthetic-value',
      project: 'Payments',
      environment: 'Production',
      kind: 'API key',
      description: '',
    );
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });
  Future<MemberView> setEnabled(
    bool enabled, {
    String actor = 'owner',
    String member = 'editor',
    List<String>? reviewed,
    List<String> selected = const [],
  }) => services.organizations.setMemberEnabled(
    actor,
    'org',
    member,
    enabled,
    reviewedSecretIds: reviewed ?? (enabled ? <String>[] : [secret.id]),
    rotateSecretIds: selected,
  );

  test(
    'disable retains member and other organizations but denies every org access path',
    () async {
      final copy = await services.vault.copy('editor', 'org', secret.id);
      final updated = await setEnabled(false, selected: [secret.id]);
      expect(updated.toJson()['accessDisabled'], true);
      expect((await services.organizations.list('editor')).map((o) => o.id), [
        'other',
      ]);
      expect(
        (await services.organizations.members(
          'owner',
          'org',
        )).map((m) => m.account.id),
        contains('editor'),
      );
      expect((await services.vault.summary('owner', 'org')).memberCount, 3);
      for (final call in <Future<dynamic> Function()>[
        () => services.vault.save(
          'editor',
          'org',
          id: secret.id,
          name: 'Blocked',
          value: 'synthetic-replacement',
          project: 'Payments',
          environment: 'Production',
          kind: 'API key',
          description: '',
        ),
        () => services.vault.list('editor', 'org'),
        () => services.vault.summary('editor', 'org'),
        () => services.vault.reveal('editor', 'org', secret.id),
        () => services.vault.revealFields('editor', 'org', secret.id),
        () => services.vault.copy('editor', 'org', secret.id),
        () => services.vault.delete('editor', 'org', secret.id),
        () => services.vault.setRotationRequired(
          'editor',
          'org',
          secret.id,
          false,
        ),
        () => services.vault.createProject('editor', 'org', 'Blocked'),
        () => services.organizations.members('editor', 'org'),
        () => services.tracking.list('editor', 'org'),
        () => services.tracking.forSecret('editor', 'org', secret.id),
        () => services.tracking.confirmCopy(
          'editor',
          'org',
          secret.id,
          copy.eventId,
        ),
      ]) {
        await expectLater(call(), throwsA(isA<VaultException>()));
      }
      expect(
        (await services.vault.list('owner', 'org')).single.needsRotation,
        true,
      );
    },
  );

  test(
    'reenable restores scoped role without clearing rotation flags after restart',
    () async {
      await services.organizations.updateMemberAccess(
        'owner',
        'org',
        'editor',
        'editor',
        readProjects: ['Payments'],
        writeProjects: ['Payments'],
      );
      await setEnabled(false, selected: [secret.id]);
      await services.close();
      services = await VaultServices.open(directory, key);
      expect((await services.organizations.list('editor')).map((o) => o.id), [
        'other',
      ]);
      final enabled = await setEnabled(true);
      expect(enabled.toJson()['accessDisabled'], false);
      expect(enabled.role, 'editor');
      expect(enabled.readProjects, ['Payments']);
      expect(enabled.writeProjects, ['Payments']);
      expect(
        (await services.organizations.list('editor')).map((o) => o.id),
        contains('org'),
      );
      expect(
        await services.vault.reveal('editor', 'org', secret.id),
        'synthetic-value',
      );
      expect(
        (await services.vault.list('editor', 'org')).single.needsRotation,
        true,
      );
      await setEnabled(true);
      final events = await services.tracking.list('owner', 'org', limit: 100);
      expect(
        events.where((e) => e.action == 'disabled member access'),
        hasLength(1),
      );
      expect(
        events.where((e) => e.action == 'enabled member access'),
        hasLength(1),
      );
    },
  );

  test('only owner may toggle access and owner/self are protected', () async {
    for (final actor in ['reader', 'editor', 'outsider']) {
      await expectLater(
        setEnabled(false, actor: actor),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        setEnabled(true, actor: actor),
        throwsA(isA<VaultException>()),
      );
    }
    await expectLater(
      setEnabled(false, member: 'owner'),
      throwsA(isA<VaultException>()),
    );
    await expectLater(
      setEnabled(true, member: 'owner'),
      throwsA(isA<VaultException>()),
    );
    await expectLater(
      setEnabled(false, member: 'outsider'),
      throwsA(isA<VaultException>()),
    );
  });

  test(
    'stale review or foreign selection cannot partially suspend or mark',
    () async {
      await expectLater(
        setEnabled(false, reviewed: []),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        setEnabled(false, selected: [secret.id, 'foreign']),
        throwsA(isA<VaultException>()),
      );
      expect(
        (await services.organizations.list('editor')).map((o) => o.id),
        contains('org'),
      );
      expect(
        (await services.vault.list('owner', 'org')).single.needsRotation,
        false,
      );
      await setEnabled(false);
      expect(
        (await services.vault.list('owner', 'org')).single.needsRotation,
        false,
      );
    },
  );

  test(
    'editing permissions cannot reenable disabled member and removal still works',
    () async {
      await setEnabled(false);
      final updated = await services.organizations.updateMemberAccess(
        'owner',
        'org',
        'editor',
        'reader',
      );
      expect(updated.toJson()['accessDisabled'], true);
      expect((await services.organizations.list('editor')).map((o) => o.id), [
        'other',
      ]);
      await expectLater(
        services.invitations.create(
          'owner',
          'org',
          'editor@example.test',
          'editor',
          'reader',
        ),
        throwsA(isA<VaultException>()),
      );
      await services.organizations.removeMember(
        'owner',
        'org',
        'editor',
        reviewedSecretIds: [secret.id],
        rotateSecretIds: [],
      );
      expect(
        (await services.organizations.members(
          'owner',
          'org',
        )).map((m) => m.account.id),
        isNot(contains('editor')),
      );
    },
  );
}
