import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  dynamic services;
  final key = base64Encode(List<int>.generate(32, (i) => i));
  const password = 'a-long-test-password!';
  late AuthResult owner;
  late OrganizationView organization;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-test-');
    services = await VaultServices.open(directory, key);
    owner = await services.accounts.register(
      'owner@example.com',
      password,
      'Owner',
    );
    organization = await services.organizations.create(
      owner.account.id,
      'Engineering',
    );
  });
  tearDown(() async {
    if (services != null) await services.close();
    await directory.delete(recursive: true);
  });

  Future<SecretView> create({
    String name = 'API_KEY',
    String value = 'private-value-123',
  }) async => await services.vault.save(
    owner.account.id,
    organization.id,
    name: name,
    value: value,
    project: 'Website',
    environment: 'Production',
    kind: 'API key',
    description: 'Backend access',
  );

  test(
    'direct addition cannot grant membership without recipient consent',
    () async {
      final recipient = await services.accounts.register(
        'pending@example.com',
        password,
        'Pending',
      );
      await expectLater(
        services.organizations.addMember(
          owner.account.id,
          organization.id,
          recipient.account.email,
          'reader',
        ),
        throwsA(isA<VaultException>()),
      );
      expect(await services.organizations.list(recipient.account.id), isEmpty);
    },
  );

  test(
    'ciphertext persists without values or passwords and survives restart',
    () async {
      final secret = await create();
      expect(jsonEncode(secret.toJson()), isNot(contains('private-value-123')));
      await services.close();
      for (final file in directory.listSync().whereType<File>().where(
        (file) => file.path.contains('vault.sqlite'),
      )) {
        final disk = latin1.decode(await file.readAsBytes());
        expect(disk, isNot(contains('private-value-123')));
        expect(disk, isNot(contains(password)));
        expect(disk, isNot(contains(owner.token)));
      }
      services = await VaultServices.open(directory, key);
      expect(
        await services.vault.reveal(
          owner.account.id,
          organization.id,
          secret.id,
        ),
        'private-value-123',
      );
    },
  );

  test(
    'legacy vault upgrades its startup marker without changing records',
    () async {
      final secret = await create();
      final legacyCheck = await services.crypto.encrypt(
        'PodVault key check v1',
        'key-check',
      );
      await services.store.write(
        (dynamic data) => data['keyCheck'] = legacyCheck,
      );
      final before = await services.store.read((dynamic data) => data);
      before.remove('keyCheck');
      await services.close();
      services = null;
      services = await VaultServices.open(directory, key);
      final after = await services.store.read((dynamic data) => data);
      final migratedCheck = after.remove('keyCheck') as String;
      expect(after, before);
      expect(
        await services.crypto.decrypt(migratedCheck, 'key-check'),
        'SecretPod key check v1',
      );
      expect(
        await services.accounts.authenticate(owner.token),
        owner.account.id,
      );
      expect(
        await services.vault.reveal(
          owner.account.id,
          organization.id,
          secret.id,
        ),
        'private-value-123',
      );
      await services.close();
      services = null;
      services = await VaultServices.open(directory, key);
      expect(
        await services.store.read((dynamic data) => data['keyCheck']),
        migratedCheck,
      );
    },
  );

  test(
    'unrecognized startup marker is rejected without overwriting it',
    () async {
      final invalidCheck = await services.crypto.encrypt(
        'unknown format',
        'key-check',
      );
      await services.store.write(
        (dynamic data) => data['keyCheck'] = invalidCheck,
      );
      await services.close();
      services = null;
      final file = File('${directory.path}/vault.sqlite');
      final before = await file.readAsBytes();
      await expectLater(VaultServices.open(directory, key), throwsStateError);
      expect(await file.readAsBytes(), before);
    },
  );

  test(
    'outsiders cannot list or reveal another organization secrets',
    () async {
      final secret = await create();
      final outsider = await services.accounts.register(
        'other@example.com',
        password,
        'Other',
      );
      await expectLater(
        services.vault.list(outsider.account.id, organization.id),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        services.vault.reveal(outsider.account.id, organization.id, secret.id),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test('reader can reveal but cannot mutate or add members', () async {
    final secret = await create();
    final reader = await services.accounts.register(
      'reader@example.com',
      password,
      'Reader',
    );
    final invitation = await services.invitations.create(
      owner.account.id,
      organization.id,
      reader.account.email,
      'Reader',
      'reader',
    );
    await services.invitations.accept(
      reader.account.id,
      invitation.invitation.id,
      invitation.token,
    );
    expect(
      await services.vault.reveal(
        reader.account.id,
        organization.id,
        secret.id,
      ),
      'private-value-123',
    );
    await expectLater(
      services.vault.delete(reader.account.id, organization.id, secret.id),
      throwsA(isA<VaultException>()),
    );
    await expectLater(
      services.organizations.addMember(
        reader.account.id,
        organization.id,
        owner.account.email,
        'editor',
      ),
      throwsA(isA<VaultException>()),
    );
  });

  test(
    'rotation increments version, duplicate identity is rejected, audit has no value',
    () async {
      final secret = await create();
      await expectLater(create(), throwsA(isA<VaultException>()));
      final rotated = await services.vault.save(
        owner.account.id,
        organization.id,
        id: secret.id,
        name: 'API_KEY',
        value: 'new-private-value',
        project: 'Website',
        environment: 'Production',
        kind: 'API key',
        description: 'Rotated',
      );
      expect(rotated.version, 2);
      expect(
        await services.vault.reveal(
          owner.account.id,
          organization.id,
          secret.id,
        ),
        'new-private-value',
      );
      final events = await services.tracking.list(
        owner.account.id,
        organization.id,
      );
      expect(
        events.map((dynamic e) => e.action),
        containsAll(['created', 'rotated', 'revealed']),
      );
      expect(
        jsonEncode(events.map((dynamic e) => e.toJson()).toList()),
        isNot(contains('private-value')),
      );
      await services.vault.delete(owner.account.id, organization.id, secret.id);
      expect(
        await services.vault.list(owner.account.id, organization.id),
        isEmpty,
      );
    },
  );

  test('logout revokes a session and wrong password fails', () async {
    expect(await services.accounts.authenticate(owner.token), owner.account.id);
    await expectLater(
      services.accounts.login('owner@example.com', 'wrong-password'),
      throwsA(isA<VaultException>()),
    );
    final signedIn = await services.accounts.login(
      ' OWNER@EXAMPLE.COM ',
      password,
    );
    expect(signedIn.account.id, owner.account.id);
    await services.accounts.logout(signedIn.token);
    expect(await services.accounts.authenticate(signedIn.token), isNull);
  });

  test(
    'ciphertext tampering and moving ciphertext to a different secret fail closed',
    () async {
      final encrypted = await services.crypto.encrypt('hidden', 'org:secret');
      expect(await services.crypto.decrypt(encrypted, 'org:secret'), 'hidden');
      await expectLater(
        services.crypto.decrypt(encrypted, 'org:different'),
        throwsA(anything),
      );
      final bytes = base64Decode(encrypted);
      bytes[15] ^= 1;
      await expectLater(
        services.crypto.decrypt(base64Encode(bytes), 'org:secret'),
        throwsA(anything),
      );
    },
  );

  test('wrong master key cannot open existing data', () async {
    await create();
    await services.close();
    services = null;
    await expectLater(
      VaultServices.open(directory, base64Encode(List<int>.filled(32, 99))),
      throwsA(anything),
    );
  });

  test('concurrent logins cannot exceed four active password hashes', () async {
    final results = await Future.wait(
      List.generate(6, (_) async {
        try {
          await services.accounts.login('owner@example.com', password);
          return true;
        } on VaultException catch (e) {
          expect(e.message, contains('Too many attempts'));
          return false;
        }
      }),
    );
    expect(results.where((ok) => ok).length, lessThanOrEqualTo(4));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('failed transaction does not save partial state', () async {
    await expectLater(
      services.store.write((dynamic state) async {
        state['accidental'] = 'partial';
        throw StateError('abort');
      }),
      throwsStateError,
    );
    expect(
      await services.store.read(
        (dynamic state) => state.containsKey('accidental'),
      ),
      false,
    );
  });
}
