import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  late AuthResult owner;
  late OrganizationView organization;
  final key = base64Encode(List<int>.filled(32, 37));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('organization-rename-');
    services = await VaultServices.open(directory, key);
    owner = await services.accounts.register(
      'owner@example.test',
      'organization-test-password',
      'Owner',
    );
    organization = await services.organizations.create(
      owner.account.id,
      'Engineering',
    );
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });

  Future<OrganizationView> rename(String actor, String id, String name) =>
      services.organizations.rename(actor, id, name);

  test(
    'owner rename persists without changing identity, membership or secrets',
    () async {
      final secret = await services.vault.save(
        owner.account.id,
        organization.id,
        name: 'API_KEY',
        value: 'fixture-value',
        project: 'Default',
        environment: 'Production',
        kind: 'API key',
        description: '',
      );
      final before = await services.store.read((data) => data);
      final updated = await rename(
        owner.account.id,
        organization.id,
        '  Platform  ',
      );
      expect(updated.name, 'Platform');
      expect(updated.id, organization.id);
      expect(updated.createdAt, organization.createdAt);
      expect(updated.role, 'owner');
      final after = await services.store.read((data) => data);
      for (final collection in ['members', 'secrets', 'accounts', 'sessions']) {
        expect(after[collection], before[collection]);
      }
      final event = (await services.tracking.list(
        owner.account.id,
        organization.id,
      )).first;
      expect(event.action, 'renamed organization');
      expect(event.target, 'Platform');
      expect(event.actorId, owner.account.id);
      expect(event.details, 'Previous name: Engineering');
      await services.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services.organizations.list(owner.account.id)).single.name,
        'Platform',
      );
      expect(
        await services.vault.reveal(
          owner.account.id,
          organization.id,
          secret.id,
        ),
        'fixture-value',
      );
    },
  );

  test('invalid and unchanged names do not write audit events', () async {
    final before = await services.store.read((data) => data);
    for (final name in ['', '   ', 'x' * 81]) {
      await expectLater(
        rename(owner.account.id, organization.id, name),
        throwsA(isA<VaultException>()),
      );
    }
    await rename(owner.account.id, organization.id, ' Engineering ');
    expect(await services.store.read((data) => data), before);
    expect(
      (await rename(owner.account.id, organization.id, 'x' * 80)).name.length,
      80,
    );
  });

  for (final role in ['reader', 'editor', 'outsider']) {
    test('$role cannot rename another organization', () async {
      final user = await services.accounts.register(
        '$role@example.test',
        'organization-test-password',
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
      } else {
        await services.organizations.create(
          user.account.id,
          'Other organization',
        );
      }
      final before = await services.store.read((data) => data);
      await expectLater(
        rename(user.account.id, organization.id, 'Unauthorized'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        rename(owner.account.id, 'missing', 'Unknown'),
        throwsA(isA<VaultException>()),
      );
      expect(await services.store.read((data) => data), before);
    });
  }
}
