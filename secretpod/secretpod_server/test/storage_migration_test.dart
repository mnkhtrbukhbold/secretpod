import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/storage/sqlite_session.dart';
import 'package:test/test.dart';

void main() {
  final key = base64Encode(List<int>.generate(32, (i) => i + 1));
  final crypto = CryptoService(key);
  const value = 'migration-test-private-value';
  final token = CryptoService.randomToken();
  late Directory directory;
  late File legacy;
  VaultServices? services;

  Future<Map<String, dynamic>> fixture() async => {
    'schema': 1,
    'invitations': <Map<String, dynamic>>[],
    'keyCheck': await crypto.encrypt('SecretPod key check v1', 'key-check'),
    'accounts': [
      {
        'id': 'a1',
        'email': 'owner@example.com',
        'name': 'Owner',
        'salt': 'preserved-salt',
        'passwordHash': 'preserved-password-hash',
      },
    ],
    'sessions': [
      {
        'digest': CryptoService.tokenDigest(token),
        'accountId': 'a1',
        'expiresAt': '2099-01-01T00:00:00.000Z',
      },
    ],
    'organizations': [
      {'id': 'o1', 'name': 'Team', 'createdAt': '2026-10-01T00:00:00.000Z'},
    ],
    'members': [
      {'organizationId': 'o1', 'accountId': 'a1', 'role': 'owner'},
    ],
    'secrets': [
      {
        'id': 's1',
        'organizationId': 'o1',
        'name': 'API_KEY',
        'project': 'Website',
        'environment': 'Production',
        'kind': 'API key',
        'description': "Imported ' safely; DROP TABLE vault_secrets; --",
        'ciphertext': await crypto.encrypt(value, 'o1:s1'),
        'version': 3,
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-02T00:00:00.000Z',
      },
    ],
    'events': [
      for (var i = 1; i <= 2; i++)
        {
          'id': 'e$i',
          'organizationId': 'o1',
          'actor': 'Owner (owner@example.com)',
          'action': i == 1 ? 'created' : 'rotated',
          'target': 'API_KEY',
          'createdAt': '2026-10-0${i}T00:00:00.000Z',
        },
    ],
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-migration-');
    legacy = File('${directory.path}/vault.json');
    await legacy.writeAsString(jsonEncode(await fixture()));
  });
  tearDown(() async {
    await services?.close();
    services = null;
    await directory.delete(recursive: true);
  });

  test(
    'schema five gains rotation flags atomically without rewriting ciphertext',
    () async {
      services = await VaultServices.open(directory, key);
      final original = await services!.store.read((d) => d);
      await services!.close();
      services = null;
      var database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      await database.db.unsafeExecute(
        'ALTER TABLE vault_secrets DROP COLUMN needsRotation',
      );
      await database.db.unsafeExecute('PRAGMA user_version = 5');
      await database.close();
      await expectLater(
        VaultServices.open(directory, base64Encode(List.filled(32, 99))),
        throwsA(anything),
      );
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      expect(
        (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
        5,
      );
      expect(
        (await database.db.unsafeQuery(
          'PRAGMA table_info(vault_secrets)',
        )).map((r) => r[1]),
        isNot(contains('needsRotation')),
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((d) => d), original);
      expect(
        (await services!.vault.list('a1', 'o1')).single.needsRotation,
        isFalse,
      );
      await services!.vault.setRotationRequired('a1', 'o1', 's1', true);
      await services!.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services!.vault.list('a1', 'o1')).single.needsRotation,
        isTrue,
      );
      expect(await services!.vault.reveal('a1', 'o1', 's1'), value);
      expect(
        await services!.store.read(
          (d) => (d['secrets'] as List).single['ciphertext'],
        ),
        (original['secrets'] as List).single['ciphertext'],
      );
    },
  );

  test(
    'schema four adds theme atomically preserving all records and restart',
    () async {
      services = await VaultServices.open(directory, key);
      final original = await services!.store.read((d) => d);
      await services!.close();
      services = null;
      var database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      await database.db.unsafeExecute(
        'ALTER TABLE vault_accounts DROP COLUMN themeMode',
      );
      await database.db.unsafeExecute('PRAGMA user_version = 4');
      await database.db.unsafeExecute(
        'ALTER TABLE vault_secrets DROP COLUMN needsRotation',
      );
      await database.close();
      await expectLater(
        VaultServices.open(directory, base64Encode(List.filled(32, 99))),
        throwsA(anything),
      );
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      expect(
        (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
        4,
      );
      expect(
        (await database.db.unsafeQuery(
          'PRAGMA table_info(vault_accounts)',
        )).map((r) => r[1]),
        isNot(contains('themeMode')),
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((d) => d), original);
      expect((await services!.invitations.profile('a1')).themeMode, 'system');
      await services!.accounts.updateTheme('a1', 'dark');
      await services!.close();
      services = null;
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      expect(
        (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
        6,
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      expect((await services!.invitations.profile('a1')).themeMode, 'dark');
      expect(await services!.accounts.authenticate(token), 'a1');
      expect(await services!.vault.reveal('a1', 'o1', 's1'), value);
    },
  );

  test(
    'schema three upgrades invitations preserving all existing records',
    () async {
      services = await VaultServices.open(directory, key);
      final original = await services!.store.read((d) => d);
      await services!.close();
      services = null;
      var database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      await database.db.unsafeExecute('DROP TABLE vault_invitations');
      await database.db.unsafeExecute(
        'ALTER TABLE vault_accounts DROP COLUMN invitationPolicy',
      );
      await database.db.unsafeExecute(
        'ALTER TABLE vault_accounts DROP COLUMN themeMode',
      );
      await database.db.unsafeExecute('PRAGMA user_version = 3');
      await database.db.unsafeExecute(
        'ALTER TABLE vault_secrets DROP COLUMN needsRotation',
      );
      await database.close();
      await expectLater(
        VaultServices.open(directory, base64Encode(List.filled(32, 99))),
        throwsA(anything),
      );
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      expect(
        (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
        3,
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((d) => d), original);
      expect(
        (await services!.invitations.profile('a1')).invitationPolicy,
        'all',
      );
    },
  );

  test(
    'legacy JSON without invitation collection imports without changing source',
    () async {
      final data = await fixture()
        ..remove('invitations');
      final original = jsonEncode(data);
      await legacy.writeAsString(original);
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((d) => d['invitations']), isEmpty);
      final loaded = await services!.store.read((d) => d)
        ..remove('invitations');
      expect(loaded, data);
      expect(await legacy.readAsString(), original);
    },
  );

  test(
    'version-two vault gains optional credential metadata without changing records',
    () async {
      final original = jsonDecode(await legacy.readAsString());
      services = await VaultServices.open(directory, key);
      await services!.close();
      services = null;
      var database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      final columns = (await database.db.unsafeQuery(
        'PRAGMA table_info(vault_secrets)',
      )).map((row) => row[1]).toSet();
      for (final column in ['usernameCiphertext', 'url', 'expiresAt']) {
        if (columns.contains(column)) {
          await database.db.unsafeExecute(
            'ALTER TABLE vault_secrets DROP COLUMN "$column"',
          );
        }
      }
      await database.db.unsafeExecute('DROP TABLE vault_invitations');
      await database.db.unsafeExecute(
        'ALTER TABLE vault_accounts DROP COLUMN invitationPolicy',
      );
      await database.db.unsafeExecute(
        'ALTER TABLE vault_accounts DROP COLUMN themeMode',
      );
      await database.db.unsafeExecute('PRAGMA user_version = 2');
      await database.db.unsafeExecute(
        'ALTER TABLE vault_secrets DROP COLUMN needsRotation',
      );
      await database.close();
      await expectLater(
        VaultServices.open(directory, base64Encode(List.filled(32, 99))),
        throwsA(anything),
      );
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      expect(
        (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
        2,
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((data) => data), original);
      await services!.close();
      services = null;
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      try {
        expect(
          (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
          6,
        );
        expect(
          (await database.db.unsafeQuery(
            'SELECT usernameCiphertext, url, expiresAt FROM vault_secrets',
          )).first.toList(),
          [null, null, null],
        );
      } finally {
        await database.close();
      }
    },
  );

  test(
    'imports all records and ciphertext into SQLite without changing JSON',
    () async {
      final original = await legacy.readAsString();
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((data) => data), jsonDecode(original));
      expect(await services!.accounts.authenticate(token), 'a1');
      expect(await services!.vault.reveal('a1', 'o1', 's1'), value);
      expect((await services!.tracking.list('a1', 'o1')).map((e) => e.action), [
        'revealed',
        'rotated',
        'created',
      ]);
      await services!.close();
      services = null;
      final database = File('${directory.path}/vault.sqlite');
      expect(await database.exists(), isTrue);
      final bytes = await database.readAsBytes();
      expect(ascii.decode(bytes.take(16).toList()), 'SQLite format 3\u0000');
      expect(latin1.decode(bytes), isNot(contains(value)));
      expect(latin1.decode(bytes), isNot(contains(token)));
      expect(await legacy.readAsString(), original);
    },
  );

  test(
    'restart uses SQLite and never reimports stale JSON or resurrects a secret',
    () async {
      final original = await legacy.readAsString();
      services = await VaultServices.open(directory, key);
      await services!.vault.delete('a1', 'o1', 's1');
      await services!.close();
      services = null;
      expect(await legacy.readAsString(), original);
      services = await VaultServices.open(directory, key);
      expect(await services!.vault.list('a1', 'o1'), isEmpty);
      expect(await services!.accounts.authenticate(token), 'a1');
    },
  );

  test(
    'wrong key cannot import and a later correct-key retry succeeds',
    () async {
      final original = await legacy.readAsString();
      await expectLater(
        VaultServices.open(directory, base64Encode(List.filled(32, 99))),
        throwsA(anything),
      );
      expect(await legacy.readAsString(), original);
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((data) => data), jsonDecode(original));
    },
  );

  test(
    'broken foreign key rolls back the complete import and allows retry',
    () async {
      final original = await legacy.readAsString();
      final invalid = jsonDecode(original) as Map<String, dynamic>;
      invalid['sessions'][0]['accountId'] = 'missing-account';
      final invalidText = jsonEncode(invalid);
      await legacy.writeAsString(invalidText);
      await expectLater(VaultServices.open(directory, key), throwsA(anything));
      expect(await legacy.readAsString(), invalidText);
      await legacy.writeAsString(original);
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((data) => data), jsonDecode(original));
    },
  );

  test('missing key check on a nonempty legacy vault fails closed', () async {
    final invalid = await fixture()
      ..remove('keyCheck');
    await legacy.writeAsString(jsonEncode(invalid));
    final before = await legacy.readAsString();
    await expectLater(VaultServices.open(directory, key), throwsStateError);
    expect(await legacy.readAsString(), before);
  });

  test('tampered legacy ciphertext rejects the whole migration', () async {
    final invalid = await fixture();
    final bytes = base64Decode(invalid['secrets'][0]['ciphertext'] as String);
    bytes[15] ^= 1;
    invalid['secrets'][0]['ciphertext'] = base64Encode(bytes);
    await legacy.writeAsString(jsonEncode(invalid));
    final before = await legacy.readAsString();
    await expectLater(VaultServices.open(directory, key), throwsA(anything));
    expect(await legacy.readAsString(), before);
  });

  test(
    'SQL constraint failure rolls back records and their activity together',
    () async {
      services = await VaultServices.open(directory, key);
      final before = await services!.store.read((data) => data);
      await expectLater(
        services!.store.write((data) {
          data['accounts'][0]['name'] = 'must roll back';
          data['secrets'][0]['organizationId'] = 'missing-organization';
          data['events'][0]['action'] = 'must also roll back';
        }),
        throwsA(anything),
      );
      expect(await services!.store.read((data) => data), before);
    },
  );

  test(
    'invalid JSON is rejected without exposing or rewriting its contents',
    () async {
      const invalid = '{invalid-private-fixture';
      await legacy.writeAsString(invalid);
      await expectLater(
        VaultServices.open(directory, key),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('invalid-private-fixture')),
          ),
        ),
      );
      expect(await legacy.readAsString(), invalid);
    },
  );

  test(
    'unknown legacy fields are rejected instead of silently dropped',
    () async {
      final data = await fixture();
      data['secrets'][0]['futureField'] = 'preserve-me';
      final original = jsonEncode(data);
      await legacy.writeAsString(original);
      await expectLater(VaultServices.open(directory, key), throwsStateError);
      expect(await legacy.readAsString(), original);
    },
  );

  test(
    'unknown SQLite schema version is rejected without downgrading it',
    () async {
      services = await VaultServices.open(directory, key);
      await services!.close();
      services = null;
      var database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      await database.db.unsafeExecute('PRAGMA user_version = 99');
      await database.close();
      await expectLater(VaultServices.open(directory, key), throwsStateError);
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      try {
        expect(
          (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
          99,
        );
      } finally {
        await database.close();
      }
    },
  );

  test('an unrelated existing SQLite database is never overwritten', () async {
    var database = await VaultDatabaseSession.open(
      '${directory.path}/vault.sqlite',
    );
    await database.db.unsafeExecute('CREATE TABLE unrelated (value TEXT)');
    await database.db.unsafeExecute(
      "INSERT INTO unrelated VALUES ('do-not-touch')",
    );
    await database.close();
    await expectLater(VaultServices.open(directory, key), throwsStateError);
    database = await VaultDatabaseSession.open(
      '${directory.path}/vault.sqlite',
    );
    try {
      expect(
        (await database.db.unsafeQuery(
          'SELECT value FROM unrelated',
        )).first.first,
        'do-not-touch',
      );
    } finally {
      await database.close();
    }
  });

  test(
    'another store cannot open the same vault and reads are isolated',
    () async {
      services = await VaultServices.open(directory, key);
      await expectLater(VaultServices.open(directory, key), throwsStateError);
      await services!.store.read(
        (data) => data['accounts'][0]['name'] = 'not saved',
      );
      expect(
        await services!.store.read((data) => data['accounts'][0]['name']),
        'Owner',
      );
    },
  );

  test(
    'a new installation creates SQLite without creating a JSON vault',
    () async {
      await legacy.delete();
      services = await VaultServices.open(directory, key);
      expect(await File('${directory.path}/vault.sqlite').exists(), isTrue);
      expect(await legacy.exists(), isFalse);
      expect(await services!.store.read((data) => data['accounts']), isEmpty);
    },
  );

  test('concurrent transactions preserve every committed change', () async {
    services = await VaultServices.open(directory, key);
    await Future.wait(
      List.generate(
        12,
        (_) => services!.store.write((data) async {
          final current = (data['counter'] as int?) ?? 0;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          data['counter'] = current + 1;
        }),
      ),
    );
    await services!.close();
    services = null;
    services = await VaultServices.open(directory, key);
    expect(await services!.store.read((data) => data['counter']), 12);
  });

  test(
    'version-one SQLite upgrades tracking without inventing old item links',
    () async {
      final original = jsonDecode(await legacy.readAsString());
      services = await VaultServices.open(directory, key);
      await services!.close();
      services = null;
      var database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      try {
        await database.db.unsafeExecute(
          'DROP INDEX IF EXISTS vault_events_secret',
        );
        final columns = (await database.db.unsafeQuery(
          'PRAGMA table_info(vault_events)',
        )).map((row) => row[1]).toSet();
        for (final column in ['secretId', 'actorId', 'version', 'details']) {
          if (columns.contains(column)) {
            await database.db.unsafeExecute(
              'ALTER TABLE vault_events DROP COLUMN "$column"',
            );
          }
        }
        await database.db.unsafeExecute('DROP TABLE vault_invitations');
        await database.db.unsafeExecute(
          'ALTER TABLE vault_accounts DROP COLUMN invitationPolicy',
        );
        await database.db.unsafeExecute(
          'ALTER TABLE vault_accounts DROP COLUMN themeMode',
        );
        await database.db.unsafeExecute('PRAGMA user_version = 1');
        await database.db.unsafeExecute(
          'ALTER TABLE vault_secrets DROP COLUMN needsRotation',
        );
        for (final column in ['usernameCiphertext', 'url', 'expiresAt']) {
          await database.db.unsafeExecute(
            'ALTER TABLE vault_secrets DROP COLUMN "$column"',
          );
        }
      } finally {
        await database.close();
      }
      // A wrong key must leave even the schema version unchanged.
      await expectLater(
        VaultServices.open(directory, base64Encode(List.filled(32, 99))),
        throwsA(anything),
      );
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      expect(
        (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
        1,
      );
      await database.close();
      services = await VaultServices.open(directory, key);
      expect(await services!.store.read((data) => data), original);
      await services!.close();
      services = null;
      database = await VaultDatabaseSession.open(
        '${directory.path}/vault.sqlite',
      );
      try {
        expect(
          (await database.db.unsafeQuery('PRAGMA user_version')).first.first,
          6,
        );
        expect(
          (await database.db.unsafeQuery(
            'SELECT secretId, actorId FROM vault_events',
          )).first.toList(),
          [null, null],
        );
      } finally {
        await database.close();
      }
    },
  );
}
