import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/organization/organization_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  final key = base64Encode(List.filled(32, 29));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-removal-');
    services = await VaultServices.open(directory, key);
    await services.store.write((data) {
      for (final id in ['owner', 'editor', 'reader', 'outsider']) {
        (data['accounts'] as List).add({
          'id': id,
          'email': '$id@example.com',
          'name': id,
          'salt': 'fixture',
          'passwordHash': 'fixture',
        });
      }
      for (final org in ['org', 'other']) {
        (data['organizations'] as List).add({
          'id': org,
          'name': org,
          'createdAt': '2026-10-14T00:00:00.000Z',
        });
        for (final id in ['owner', 'editor', 'reader']) {
          (data['members'] as List).add({
            'organizationId': org,
            'accountId': id,
            'role': id,
          });
        }
      }
    });
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });

  Future<SecretView> save(
    String name, {
    String actor = 'owner',
    String org = 'org',
    String? id,
    String? value = 'fixture-secret-value',
    DateTime? expiresAt,
  }) => services.vault.save(
    actor,
    org,
    id: id,
    name: name,
    value: value,
    project: 'Project',
    environment: 'Production',
    kind: 'API key',
    description: '',
    expiresAt: expiresAt,
  );

  Future<List<SecretView>> preview(
    String member, {
    String actor = 'owner',
  }) async => List<SecretView>.from(
    await (services.organizations as dynamic).memberRemovalSecrets(
      actor,
      'org',
      member,
    ),
  );

  Future<void> remove(
    String member,
    List<String> reviewed,
    List<String> selected, {
    String actor = 'owner',
  }) async => (services.organizations as dynamic).removeMember(
    actor,
    'org',
    member,
    reviewedSecretIds: reviewed,
    rotateSecretIds: selected,
  );

  test(
    'review includes created, modified and read live secrets once by ID',
    () async {
      final created = await save('Created', actor: 'editor');
      final modified = await save('Modified');
      await save(
        'Modified renamed',
        actor: 'editor',
        id: modified.id,
        value: null,
      );
      final rotated = await save('Rotated');
      await save(
        'Rotated',
        actor: 'editor',
        id: rotated.id,
        value: 'changed-value',
      );
      final read = await save('Read');
      await services.vault.reveal('editor', 'org', read.id);
      await services.vault.reveal('editor', 'org', read.id);
      final copied = await save('Requested copy');
      await services.vault.copy('editor', 'org', copied.id);
      final confirmed = await save('Confirmed copy');
      final copy = await services.vault.copy('editor', 'org', confirmed.id);
      await services.tracking.confirmCopy(
        'editor',
        'org',
        confirmed.id,
        copy.eventId,
      );
      final expired = await save(
        'Expired',
        actor: 'editor',
        expiresAt: DateTime.utc(2000),
      );
      await services.vault.reveal('editor', 'org', expired.id);
      final deleted = await save('Deleted', actor: 'editor');
      await services.vault.delete('owner', 'org', deleted.id);
      await save('Other org', actor: 'editor', org: 'other');
      await save('Untouched');
      final result = await preview('editor');
      expect(
        result.map((s) => s.id),
        unorderedEquals([
          created.id,
          modified.id,
          rotated.id,
          read.id,
          copied.id,
          confirmed.id,
        ]),
      );
      expect(
        result.firstWhere((s) => s.id == modified.id).name,
        'Modified renamed',
      );
      expect(
        jsonEncode(result.map((s) => s.toJson()).toList()),
        isNot(contains('fixture-secret-value')),
      );
    },
  );

  test(
    'only owner may review/remove; owner and self removal are rejected',
    () async {
      for (final actor in ['editor', 'reader', 'outsider']) {
        await expectLater(
          preview('reader', actor: actor),
          throwsA(isA<VaultException>()),
        );
        await expectLater(
          remove('reader', [], [], actor: actor),
          throwsA(isA<VaultException>()),
        );
      }
      await expectLater(
        remove('owner', [], []),
        throwsA(isA<VaultException>()),
      );
      await expectLater(preview('outsider'), throwsA(isA<VaultException>()));
      expect((await services.organizations.members('owner', 'org')).length, 3);
    },
  );

  test(
    'removal revokes org access and persists only chosen flags with audit',
    () async {
      final selected = await save('Selected', actor: 'editor');
      final skipped = await save('Skipped', actor: 'editor');
      await remove('editor', [selected.id, skipped.id], [selected.id]);
      await expectLater(
        services.vault.reveal('editor', 'org', selected.id),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        services.vault.list('editor', 'org'),
        throwsA(isA<VaultException>()),
      );
      expect((await services.organizations.list('editor')).map((o) => o.id), [
        'other',
      ]);
      final events = await services.tracking.list('owner', 'org');
      expect(events.where((e) => e.action == 'removed member'), hasLength(1));
      expect(
        events
            .where((e) => e.action == 'marked needs rotating')
            .single
            .secretId,
        selected.id,
      );
      expect(events.where((e) => e.actorId == 'editor'), hasLength(2));
      await services.close();
      services = await VaultServices.open(directory, key);
      final secrets = await services.vault.list('owner', 'org');
      expect(
        secrets
            .firstWhere((s) => s.id == selected.id)
            .toJson()['needsRotation'],
        true,
      );
      expect(
        secrets.firstWhere((s) => s.id == skipped.id).toJson()['needsRotation'],
        false,
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

  test('empty selection removes member without marking secrets', () async {
    final secret = await save('Read');
    await services.vault.reveal('reader', 'org', secret.id);
    await remove('reader', [secret.id], []);
    expect(
      (await services.vault.list(
        'owner',
        'org',
      )).single.toJson()['needsRotation'],
      false,
    );
  });

  test(
    'expiry follows owner calendar through expiry day and is rechecked at confirmation',
    () async {
      var now = DateTime.utc(2026, 10, 14, 23, 30);
      final organizations = OrganizationService(services.store, now: () => now);
      final today = await save(
        'Expires today',
        actor: 'editor',
        expiresAt: DateTime.utc(2026, 10, 14),
      );
      final tomorrow = await save(
        'Expires tomorrow',
        actor: 'editor',
        expiresAt: DateTime.utc(2026, 10, 15),
      );
      final never = await save('Never expires', actor: 'editor');
      expect(
        (await organizations.memberRemovalSecrets(
          'owner',
          'org',
          'editor',
          utcOffsetMinutes: -60,
        )).map((s) => s.id),
        unorderedEquals([today.id, tomorrow.id, never.id]),
      );
      expect(
        (await organizations.memberRemovalSecrets(
          'owner',
          'org',
          'editor',
          utcOffsetMinutes: 120,
        )).map((s) => s.id),
        unorderedEquals([tomorrow.id, never.id]),
      );
      await expectLater(
        organizations.memberRemovalSecrets(
          'owner',
          'org',
          'editor',
          utcOffsetMinutes: 841,
        ),
        throwsA(isA<VaultException>()),
      );
      now = DateTime.utc(2026, 10, 16);
      await expectLater(
        organizations.removeMember(
          'owner',
          'org',
          'editor',
          reviewedSecretIds: [today.id, tomorrow.id, never.id],
          rotateSecretIds: [today.id],
        ),
        throwsA(isA<VaultException>()),
      );
      expect((await services.organizations.members('owner', 'org')).length, 3);
    },
  );

  test(
    'deletion after preview forces review without partial member removal',
    () async {
      final secret = await save('Deleted during review', actor: 'editor');
      await services.vault.delete('owner', 'org', secret.id);
      await expectLater(
        remove('editor', [secret.id], [secret.id]),
        throwsA(isA<VaultException>()),
      );
      expect(await preview('editor'), isEmpty);
      await remove('editor', [], []);
      expect(
        (await services.organizations.members(
          'owner',
          'org',
        )).map((m) => m.account.id),
        isNot(contains('editor')),
      );
    },
  );

  test(
    'new exposure requires review and invalid selection rolls back everything',
    () async {
      final first = await save('First', actor: 'editor');
      final second = await save('Second');
      await services.vault.reveal('editor', 'org', second.id);
      await expectLater(
        remove('editor', [first.id], [first.id]),
        throwsA(isA<VaultException>()),
      );
      final foreign = await save('Foreign', org: 'other');
      await expectLater(
        remove('editor', [first.id, second.id], [first.id, foreign.id]),
        throwsA(isA<VaultException>()),
      );
      expect((await services.organizations.members('owner', 'org')).length, 3);
      expect(
        (await services.vault.list(
          'owner',
          'org',
        )).every((s) => s.toJson()['needsRotation'] == false),
        isTrue,
      );
      expect(
        (await services.tracking.list(
          'owner',
          'org',
        )).any((e) => e.action == 'removed member'),
        isFalse,
      );
    },
  );

  test(
    'legacy display-only events never imply access by a matching name',
    () async {
      final secret = await save('Legacy');
      await services.store.write((data) {
        (data['events'] as List).add({
          'id': 'legacy',
          'organizationId': 'org',
          'actor': 'editor (editor@example.com)',
          'action': 'revealed',
          'target': secret.name,
          'createdAt': '2026-10-14T00:00:00.000Z',
        });
      });
      expect(await preview('editor'), isEmpty);
    },
  );

  test(
    'rotation flag survives metadata/same-value edits, clears on new value',
    () async {
      final secret = await save('Flagged');
      final dynamic vault = services.vault;
      await expectLater(
        vault.setRotationRequired('reader', 'org', secret.id, true),
        throwsA(isA<VaultException>()),
      );
      await vault.setRotationRequired('editor', 'org', secret.id, true);
      var updated = await save('Renamed', id: secret.id, value: null);
      expect(updated.toJson()['needsRotation'], true);
      updated = await save('Renamed', id: secret.id);
      expect(updated.toJson()['needsRotation'], true);
      updated = await save(
        'Renamed',
        id: secret.id,
        value: 'replacement-value',
      );
      expect(updated.toJson()['needsRotation'], false);
      await vault.setRotationRequired('owner', 'org', secret.id, true);
      await vault.setRotationRequired('owner', 'org', secret.id, false);
      expect(
        (await services.vault.list(
          'owner',
          'org',
        )).single.toJson()['needsRotation'],
        false,
      );
    },
  );
}
