import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  late String actor, org;
  final key = base64Encode(List.filled(32, 73));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-credentials-');
    services = await VaultServices.open(directory, key);
    final account = await services.accounts.register(
      'owner@example.com',
      'fixture-login-password',
      'Owner',
    );
    actor = account.account.id;
    org = (await services.organizations.create(actor, 'Team')).id;
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });

  Future<SecretView> save({
    String? id,
    String? value = 'credential-password',
    String? username = 'private-username',
    String? url = 'https://example.com/login',
    DateTime? expiresAt,
    String kind = 'Username and password',
  }) => services.vault.save(
    actor,
    org,
    id: id,
    name: 'Service login',
    value: value,
    username: username,
    url: url,
    expiresAt: expiresAt,
    project: 'Default',
    environment: 'Production',
    kind: kind,
    description: '',
  );

  test(
    'credential fields encrypt separately, survive restart, and copy with field-specific audit',
    () async {
      final secret = await save(expiresAt: DateTime.utc(2030, 5, 12));
      expect(secret.url, 'https://example.com/login');
      expect(secret.expiresAt, DateTime.utc(2030, 5, 12));
      expect(jsonEncode(secret.toJson()), isNot(contains('private-username')));
      final snapshot = await services.store.read((data) => data);
      expect(jsonEncode(snapshot), isNot(contains('credential-password')));
      expect(jsonEncode(snapshot), isNot(contains('private-username')));
      await services.close();
      for (final file in directory.listSync().whereType<File>().where(
        (file) => file.path.contains('vault.sqlite'),
      )) {
        final disk = latin1.decode(await file.readAsBytes());
        expect(disk, isNot(contains('credential-password')));
        expect(disk, isNot(contains('private-username')));
      }
      services = await VaultServices.open(directory, key);
      final fields = await services.vault.revealFields(
        actor,
        org,
        secret.id,
      );
      expect(fields.username, 'private-username');
      expect(fields.value, 'credential-password');
      final copy = await services.vault.copy(
        actor,
        org,
        secret.id,
        field: 'username',
      );
      expect(copy.value, 'private-username');
      await services.tracking.confirmCopy(actor, org, secret.id, copy.eventId);
      final events = await services.tracking.forSecret(actor, org, secret.id);
      expect(events.first.action, 'copied');
      expect(events.first.details, 'Field: username');
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains('private-username')),
      );
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains('credential-password')),
      );
    },
  );

  test('username preserves exact entered whitespace', () async {
    final secret = await save(username: '  private-username  ');
    expect(
      (await services.vault.revealFields(actor, org, secret.id)).username,
      '  private-username  ',
    );
    expect(
      (await services.vault.copy(
        actor,
        org,
        secret.id,
        field: 'username',
      )).value,
      '  private-username  ',
    );
  });

  test(
    'username ciphertext cannot be substituted with password ciphertext',
    () async {
      await save();
      await services.store.write((data) {
        final row = (data['secrets'] as List).single as Map;
        row['usernameCiphertext'] = row['ciphertext'];
      });
      await services.close();
      await expectLater(VaultServices.open(directory, key), throwsA(anything));
    },
  );

  test(
    'metadata-only edits retain exact ciphertext and can clear URL and expiry',
    () async {
      final secret = await save(expiresAt: DateTime.utc(2030, 5, 12));
      final before = await services.store.read(
        (d) => (d['secrets'] as List).single as Map,
      );
      final edited = await save(
        id: secret.id,
        value: null,
        username: null,
        url: null,
      );
      expect(edited.url, isNull);
      expect(edited.expiresAt, isNull);
      final after = await services.store.read(
        (d) => (d['secrets'] as List).single as Map,
      );
      expect(after['ciphertext'], before['ciphertext']);
      expect(after['usernameCiphertext'], before['usernameCiphertext']);
      final event = (await services.tracking.forSecret(
        actor,
        org,
        secret.id,
      )).first;
      expect(event.action, 'updated');
      expect(event.details, 'Changed: url, expiry date');
      await save(
        id: secret.id,
        value: null,
        username: 'replacement-username',
        url: null,
      );
      final rotation = (await services.tracking.forSecret(
        actor,
        org,
        secret.id,
      )).first;
      expect(rotation.action, 'rotated');
      expect(rotation.details, 'Changed: username');
    },
  );

  test(
    'new credentials require both fields and reject invalid URLs atomically',
    () async {
      for (final operation in [
        () => save(value: null),
        () => save(username: null),
        () => save(username: '  '),
        () => save(url: 'javascript:alert(1)'),
        () => save(url: 'https://user:password@example.com'),
      ]) {
        await expectLater(
          Future.sync(operation),
          throwsA(isA<VaultException>()),
        );
      }
      expect(await services.vault.list(actor, org), isEmpty);
    },
  );

  test(
    'existing single-value secrets support metadata and credential conversion',
    () async {
      final secret = await save(kind: 'API key', username: null, url: '   ');
      expect(secret.url, isNull);
      expect(secret.expiresAt, isNull);
      final fields = await services.vault.revealFields(
        actor,
        org,
        secret.id,
      );
      expect(fields.username, isNull);
      expect(fields.value, 'credential-password');
      await save(id: secret.id, value: null, username: 'private-username');
      await save(id: secret.id, value: null, username: null, kind: 'Password');
      final reverted = await services.vault.revealFields(
        actor,
        org,
        secret.id,
      );
      expect(reverted.username, isNull);
      expect(reverted.value, 'credential-password');
      await expectLater(
        services.vault.copy(
          actor,
          org,
          secret.id,
          field: 'username',
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        services.vault.copy(
          actor,
          org,
          secret.id,
          field: 'invalid',
        ),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'credential reveal and copy enforce organization access and readers cannot edit',
    () async {
      final secret = await save();
      final other = await services.accounts.register(
        'reader@example.com',
        'fixture-reader-password',
        'Reader',
      );
      await expectLater(
        services.vault.revealFields(
          other.account.id,
          org,
          secret.id,
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        services.vault.copy(
          other.account.id,
          org,
          secret.id,
          field: 'username',
        ),
        throwsA(isA<VaultException>()),
      );
      final invitation = await services.invitations.create(
        actor,
        org,
        other.account.email,
        'Reader',
        'reader',
      );
      await services.invitations.accept(
        other.account.id,
        invitation.invitation.id,
        invitation.token,
      );
      expect(
        (await services.vault.revealFields(
          other.account.id,
          org,
          secret.id,
        )).username,
        'private-username',
      );
      await expectLater(
        services.vault.save(
          other.account.id,
          org,
          id: secret.id,
          name: 'No',
          value: 'forbidden',
          project: 'Default',
          environment: 'Production',
          kind: 'Password',
          description: '',
        ),
        throwsA(isA<VaultException>()),
      );
    },
  );
}
