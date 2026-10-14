import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/storage/sqlite_session.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  late VaultDatabaseSession database;
  final token = CryptoService.randomToken();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secret-activity-query-');
    services = await VaultServices.open(
      directory,
      base64Encode(List.filled(32, 17)),
    );
    await services.store.write((data) {
      for (final id in ['owner', 'reader']) {
        rows(data, 'accounts').add({
          'id': id,
          'email': '$id@example.test',
          'name': id,
          'salt': 'fixture',
          'passwordHash': 'fixture',
        });
      }
      rows(
        data,
        'organizations',
      ).add({'id': 'org', 'name': 'Team', 'createdAt': '2026-10-14T00:00:00Z'});
      for (final id in ['owner', 'reader']) {
        rows(data, 'members').add({
          'organizationId': 'org',
          'accountId': id,
          'role': id,
          if (id == 'reader') 'readProjects': jsonEncode(['PÄYMENTS']),
        });
      }
      rows(data, 'sessions').add({
        'digest': CryptoService.tokenDigest(token),
        'accountId': 'owner',
        'expiresAt': '2099-01-01T00:00:00Z',
      });
      rows(data, 'secrets').add({
        'id': 's1',
        'organizationId': 'org',
        'name': 'API_KEY',
        'project': 'Päyments',
        'environment': 'Production',
        'kind': 'API key',
        'description': '',
        'ciphertext': 'unused',
        'version': 1,
        'createdAt': '2026-10-14T00:00:00Z',
        'updatedAt': '2026-10-14T00:00:00Z',
      });
      for (var i = 0; i < 25; i++) {
        rows(data, 'events').add({
          'id': 'e$i',
          'organizationId': 'org',
          'secretId': 's1',
          'actor': 'owner',
          'action': 'created',
          'target': 'API_KEY',
          'project': i.isEven ? 'päyments' : 'Other',
          'createdAt': '2026-10-14T00:00:00Z',
        });
      }
    });
    database = await VaultDatabaseSession.open(
      '${directory.path}/vault.sqlite',
    );
  });
  tearDown(() async {
    await database.close();
    await services.close();
    await directory.delete(recursive: true);
  });

  test(
    'exclusions filter historical projects before database pagination',
    () async {
      await services.store.write((data) {
        final member = rows(data, 'members').last;
        member.remove('readProjects');
        member['deniedReadProjects'] = jsonEncode(['OTHER']);
        rows(data, 'events').add({
          'id': 'legacy',
          'organizationId': 'org',
          'secretId': 's1',
          'actor': 'owner',
          'action': 'created',
          'target': 'API_KEY',
          'createdAt': '2026-10-14T00:00:00Z',
        });
      });
      final page = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        limit: 2,
      );
      expect(page.map((e) => e.id), ['e24', 'e22']);
      final next = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        beforeEventId: page.last.id,
        limit: 2,
      );
      expect(next.map((e) => e.id), ['e20', 'e18']);
      await expectLater(
        services.tracking.forSecret(
          'reader',
          'org',
          's1',
          beforeEventId: 'e23',
        ),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'database page does not read event payloads outside its limit',
    () async {
      // The oldest payload fails if evaluated. A bounded newest-page SELECT
      // never reads it; loading the whole history before slicing does.
      await database.db.unsafeExecute(
        'ALTER TABLE vault_events RENAME TO stored_events',
      );
      await database.db.unsafeExecute('''CREATE VIEW vault_events AS SELECT
      id, organizationId, CASE WHEN id = 'e0' THEN json('invalid-json') ELSE actor END AS actor,
      action, target, createdAt, secretId, actorId, version, details,
      CASE WHEN id = 'e0' THEN json('invalid-project-json') ELSE project END AS project, _order
      FROM stored_events''');
      final page = await services.tracking.forSecret(
        'owner',
        'org',
        's1',
        limit: 10,
      );
      expect(page.map((e) => e.id), [
        'e24',
        'e23',
        'e22',
        'e21',
        'e20',
        'e19',
        'e18',
        'e17',
        'e16',
        'e15',
      ]);
      final scoped = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        limit: 10,
      );
      expect(scoped.map((e) => e.id), [
        'e24',
        'e22',
        'e20',
        'e18',
        'e16',
        'e14',
        'e12',
        'e10',
        'e8',
        'e6',
      ]);
      await expectLater(
        database.db.unsafeQuery('SELECT actor FROM vault_events'),
        throwsA(anything),
      );
    },
  );

  test('session authentication reads only its session record', () async {
    await database.db.unsafeExecute(
      "INSERT INTO vault_metadata VALUES ('unrelated', 'invalid-json')",
    );
    expect(await services.accounts.authenticate(token), 'owner');
    expect(
      await services.accounts.authenticate(CryptoService.randomToken()),
      isNull,
    );
    await database.db.unsafeExecute(
      "UPDATE vault_sessions SET expiresAt = '2020-01-01T00:00:00Z'",
    );
    expect(await services.accounts.authenticate(token), isNull);
  });

  test(
    'scoped scans advance through denied batches and count only readable offsets',
    () async {
      await database.db.unsafeExecute(
        "UPDATE vault_events SET project = 'Other' WHERE _order >= 12",
      );
      await database.db.unsafeExecute(
        "UPDATE vault_events SET project = NULL WHERE id = 'e8'",
      );
      final first = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        limit: 3,
      );
      expect(first.map((e) => e.id), ['e10', 'e6', 'e4']);
      final next = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        beforeEventId: 'e4',
        limit: 3,
      );
      expect(next.map((e) => e.id), ['e2', 'e0']);
      final offset = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        offset: 3,
        limit: 3,
      );
      expect(offset.map((e) => e.id), ['e2', 'e0']);
      expect(
        await services.tracking.forSecret(
          'reader',
          'org',
          's1',
          offset: 5,
          limit: 3,
        ),
        isEmpty,
      );
      await expectLater(
        services.tracking.forSecret('reader', 'org', 's1', beforeEventId: 'e8'),
        throwsA(isA<VaultException>()),
      );
      await database.db.unsafeExecute(
        "UPDATE vault_events SET project = 'Other'",
      );
      expect(
        await services.tracking.forSecret('reader', 'org', 's1', limit: 3),
        isEmpty,
      );
    },
  );

  test(
    'scoped SQL paging filters before limiting and preserves Unicode matching',
    () async {
      final first = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        limit: 10,
      );
      expect(first.map((e) => e.id), [
        'e24',
        'e22',
        'e20',
        'e18',
        'e16',
        'e14',
        'e12',
        'e10',
        'e8',
        'e6',
      ]);
      final second = await services.tracking.forSecret(
        'reader',
        'org',
        's1',
        beforeEventId: 'e6',
        limit: 10,
      );
      expect(second.map((e) => e.id), ['e4', 'e2', 'e0']);
      expect(
        (await services.tracking.forSecret(
          'reader',
          'org',
          's1',
          offset: 10,
        )).map((e) => e.id),
        ['e4', 'e2', 'e0'],
      );
      for (final cursor in ['e23', 'missing']) {
        await expectLater(
          services.tracking.forSecret(
            'reader',
            'org',
            's1',
            beforeEventId: cursor,
          ),
          throwsA(isA<VaultException>()),
        );
      }
    },
  );

  test(
    'database history rejects missing membership, disabled access and moved secrets',
    () async {
      await expectLater(
        services.tracking.forSecret('outsider', 'org', 's1'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        services.tracking.forSecret('owner', 'org', 'missing'),
        throwsA(isA<VaultException>()),
      );
      await database.db.unsafeExecute(
        "UPDATE vault_members SET accessDisabled = 1 WHERE accountId = 'reader'",
      );
      await expectLater(
        services.tracking.forSecret('reader', 'org', 's1'),
        throwsA(isA<VaultException>()),
      );
      await database.db.unsafeExecute(
        "UPDATE vault_members SET accessDisabled = NULL WHERE accountId = 'reader'",
      );
      await database.db.unsafeExecute(
        "UPDATE vault_secrets SET project = 'Other' WHERE id = 's1'",
      );
      await expectLater(
        services.tracking.forSecret('reader', 'org', 's1'),
        throwsA(isA<VaultException>()),
      );
    },
  );
}
