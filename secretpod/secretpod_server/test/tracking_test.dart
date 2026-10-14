import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/vault/secret_access_limiter.dart';
import 'package:secretpod_server/src/vault/vault_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  final key = base64Encode(List.filled(32, 17));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-tracking-');
    services = await VaultServices.open(directory, key);
    // Auth hashing is covered by account tests; these are persisted identities.
    await services.store.write((data) {
      for (final id in ['owner', 'reader', 'outsider']) {
        (data['accounts'] as List).add({
          'id': id,
          'email': '$id@example.com',
          'name': id,
          'salt': 'fixture',
          'passwordHash': 'fixture',
        });
      }
      (data['organizations'] as List).add({
        'id': 'org',
        'name': 'Team',
        'createdAt': '2026-10-13T00:00:00.000Z',
      });
      for (final id in ['owner', 'reader']) {
        (data['members'] as List).add({
          'organizationId': 'org',
          'accountId': id,
          'role': id,
        });
      }
    });
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });

  Future<SecretView> save({
    String? id,
    String name = 'API_KEY',
    String project = 'Payments',
    String value = 'private-test-value',
  }) => services.vault.save(
    'owner',
    'org',
    id: id,
    name: name,
    value: value,
    project: project,
    environment: 'Production',
    kind: 'API key',
    description: '',
  );

  test('secret mutations record permanent item and actor identities', () async {
    final secret = await save();
    final events = await services.store.read((data) => data['events'] as List);
    expect(events.single['secretId'], secret.id);
    expect(events.single['actorId'], 'owner');
    expect(events.single['version'], 1);
    expect(jsonEncode(events), isNot(contains('private-test-value')));
  });

  test(
    'activity filters combine before paging and preserve deleted projects',
    () async {
      final payments = await save();
      await save(project: 'Other');
      await services.vault.reveal('reader', 'org', payments.id);
      await services.vault.reveal('reader', 'org', payments.id);
      await services.store.write((data) {
        final events = data['events'] as List;
        for (var i = 0; i < events.length; i++) {
          events[i]['createdAt'] = DateTime.utc(
            2026,
            10,
            10 + i,
          ).toIso8601String();
        }
      });
      dynamic tracking = services.tracking;
      final List<AuditView> matches = await tracking.list(
        'owner',
        'org',
        project: 'payments',
        action: 'revealed',
        user: 'id:reader',
        from: DateTime.utc(2026, 10, 12),
        until: DateTime.utc(2026, 10, 14),
        offset: 1,
        limit: 1,
      );
      expect(matches.single.createdAt, DateTime.utc(2026, 10, 12));
      final List<AuditView> boundary = await tracking.list(
        'owner',
        'org',
        from: DateTime.utc(2026, 10, 12),
        until: DateTime.utc(2026, 10, 13),
      );
      expect(boundary.map((e) => e.createdAt), [DateTime.utc(2026, 10, 12)]);
      dynamic vault = services.vault;
      final summary = await vault.summary(
        'owner',
        'org',
        activityProject: 'Payments',
        activityAction: 'revealed',
        activityUser: 'id:reader',
        activityFrom: DateTime.utc(2026, 10, 12),
        activityUntil: DateTime.utc(2026, 10, 14),
      );
      expect(summary.filteredActivityCount, 2);
      expect(summary.activityProjects, ['Default', 'Other', 'Payments']);
      expect(summary.activityUsers['id:reader'], contains('reader@'));
      await services.vault.delete('owner', 'org', payments.id);
      await services.close();
      services = await VaultServices.open(directory, key);
      tracking = services.tracking;
      final List<AuditView> deleted = await tracking.list(
        'reader',
        'org',
        project: 'Payments',
        action: 'deleted',
      );
      expect(deleted.single.secretId, payments.id);
      await expectLater(
        tracking.list('outsider', 'org', project: 'Payments'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        tracking.list(
          'owner',
          'org',
          from: DateTime.utc(2026, 10, 14),
          until: DateTime.utc(2026, 10, 12),
        ),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'metadata edits and unchanged saves do not claim the value changed',
    () async {
      final secret = await save();
      await save(id: secret.id, name: 'RENAMED');
      var history = await services.tracking.forSecret(
        'reader',
        'org',
        secret.id,
      );
      expect(history.first.action, 'updated');
      expect(history.first.details, 'Changed: name');
      await save(id: secret.id, name: 'RENAMED');
      history = await services.tracking.forSecret('reader', 'org', secret.id);
      expect(history.first.action, 'saved');
      expect(history.first.details, 'Saved without changes');
    },
  );

  test(
    'item history follows renames and separates same-name secrets',
    () async {
      final secret = await save();
      final other = await save(project: 'Other project');
      await save(
        id: secret.id,
        name: 'RENAMED',
        value: 'replacement-private-value',
      );
      await services.vault.reveal('reader', 'org', secret.id);
      dynamic tracking = services.tracking;
      final List<AuditView> history = await tracking.forSecret(
        'reader',
        'org',
        secret.id,
      );
      expect(history.map((e) => e.action), ['revealed', 'rotated', 'created']);
      expect(history.first.actor, 'reader (reader@example.com)');
      expect(history[1].toJson()['details'], 'Changed: value, name');
      expect(history[1].toJson()['version'], 2);
      expect(history.last.target, 'API_KEY');
      expect(
        jsonEncode(history.map((e) => e.toJson()).toList()),
        isNot(contains('private-value')),
      );
      final List<AuditView> otherHistory = await tracking.forSecret(
        'owner',
        'org',
        other.id,
      );
      expect(otherHistory.length, 1);
      await services.close();
      services = await VaultServices.open(directory, key);
      tracking = services.tracking;
      expect(
        (await tracking.forSecret('owner', 'org', secret.id) as List).length,
        3,
      );
    },
  );

  test(
    'copy is pending until its authenticated requester confirms, idempotently',
    () async {
      final secret = await save();
      dynamic vault = services.vault;
      dynamic tracking = services.tracking;
      final receipt = await vault.copy('reader', 'org', secret.id);
      expect(receipt.value, 'private-test-value');
      var history =
          await tracking.forSecret('owner', 'org', secret.id)
              as List<AuditView>;
      expect(history.first.action, 'copy requested');
      await expectLater(
        tracking.confirmCopy('owner', 'org', secret.id, receipt.eventId),
        throwsA(isA<VaultException>()),
      );
      final other = await save(project: 'Other');
      await expectLater(
        tracking.confirmCopy('reader', 'org', other.id, receipt.eventId),
        throwsA(isA<VaultException>()),
      );
      await save(id: secret.id, value: 'new-version');
      await tracking.confirmCopy('reader', 'org', secret.id, receipt.eventId);
      await tracking.confirmCopy('reader', 'org', secret.id, receipt.eventId);
      history =
          await tracking.forSecret('owner', 'org', secret.id)
              as List<AuditView>;
      final copies = history.where((e) => e.action == 'copied').toList();
      expect(copies.length, 1);
      expect(copies.single.actor, 'reader (reader@example.com)');
      expect(copies.single.toJson()['version'], 1);
      expect(
        jsonEncode(history.map((e) => e.toJson()).toList()),
        isNot(contains(receipt.value)),
      );
    },
  );

  test(
    'outsiders cannot read history, copy or forge copy confirmation',
    () async {
      final secret = await save();
      dynamic vault = services.vault;
      dynamic tracking = services.tracking;
      await expectLater(
        tracking.forSecret('outsider', 'org', secret.id),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        tracking.forSecret('reader', 'org', 'missing'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        vault.copy('outsider', 'org', secret.id),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        tracking.confirmCopy('outsider', 'org', secret.id, 'forged'),
        throwsA(isA<VaultException>()),
      );
      expect((await services.tracking.list('owner', 'org')).length, 1);
    },
  );

  test(
    'history pagination keeps older events reachable while new ones arrive',
    () async {
      final secret = await save();
      var accessTime = DateTime.utc(2026, 10, 14);
      final vault = VaultService(
        services.store,
        services.crypto,
        accessLimiter: SecretAccessLimiter(now: () => accessTime),
      );
      for (var i = 0; i < 54; i++) {
        await vault.reveal('reader', 'org', secret.id);
        accessTime = accessTime.add(const Duration(seconds: 2));
      }
      dynamic tracking = services.tracking;
      final first =
          await tracking.forSecret('reader', 'org', secret.id, limit: 50)
              as List<AuditView>;
      expect(first.length, 50);
      await services.vault.reveal('owner', 'org', secret.id);
      final next =
          await tracking.forSecret(
                'reader',
                'org',
                secret.id,
                beforeEventId: first.last.id,
              )
              as List<AuditView>;
      expect(next.length, 5);
      expect(next.last.action, 'created');
      expect({...first.map((e) => e.id), ...next.map((e) => e.id)}.length, 55);
      await expectLater(
        tracking.forSecret(
          'reader',
          'org',
          secret.id,
          beforeEventId: 'missing',
        ),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'deletion retains linked audit history without blocking the transaction',
    () async {
      final secret = await save();
      await services.vault.delete('owner', 'org', secret.id);
      expect(await services.vault.list('owner', 'org'), isEmpty);
      final events = await services.tracking.list('owner', 'org');
      expect(events.map((e) => e.action), ['deleted', 'created']);
      expect(events.first.toJson()['secretId'], secret.id);
    },
  );
}
