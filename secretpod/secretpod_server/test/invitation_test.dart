import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/invitation/invitation_service.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late VaultServices services;
  late InvitationService invitations;
  late DateTime now;
  late String org;
  final key = base64Encode(List.filled(32, 29));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-invitations-');
    services = await VaultServices.open(directory, key);
    now = DateTime.now().toUtc();
    invitations = InvitationService(
      services.store,
      services.accounts,
      now: () => now,
    );
    await services.store.write((data) {
      for (final (id, email) in [
        ('owner', 'owner@company.test'),
        ('recipient', 'person@company.test'),
        ('outsider', 'other@else.test'),
      ]) {
        (data['accounts'] as List).add({
          'id': id,
          'email': email,
          'name': id,
          'salt': 'fixture-salt',
          'passwordHash': 'fixture-hash',
        });
      }
    });
    org = (await services.organizations.create('owner', 'Company')).id;
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });
  Future<InvitationCreated> invite([String email = 'person@company.test']) =>
      invitations.create(
        'owner',
        org,
        email,
        'Company supplied name',
        'reader',
      );

  test(
    'inviting does not grant access; acceptance requires matching recipient and token',
    () async {
      final result = await invite();
      expect(result.invitation.status, 'pending');
      expect(await services.organizations.list('recipient'), isEmpty);
      expect(
        (await invitations.inbox('recipient')).single.id,
        result.invitation.id,
      );
      await expectLater(
        services.vault.list('recipient', org),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.accept('outsider', result.invitation.id, result.token),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.accept('recipient', result.invitation.id, 'wrong-token'),
        throwsA(isA<VaultException>()),
      );
      await invitations.accept('recipient', result.invitation.id, result.token);
      expect(
        (await services.organizations.list('recipient')).single.role,
        'reader',
      );
      expect(
        (await invitations.outgoing('owner', org)).single.status,
        'accepted',
      );
      await expectLater(
        invitations.accept('recipient', result.invitation.id, result.token),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.decline('recipient', result.invitation.id),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'new recipient can edit name and atomically create account and accept',
    () async {
      final result = await invite('new@company.test');
      expect(
        (await invitations.preview(result.token)).recipientName,
        'Company supplied name',
      );
      final auth = await invitations.registerAndAccept(
        result.token,
        'My chosen name',
        'a-new-account-password',
      );
      expect(auth.account.name, 'My chosen name');
      expect(auth.account.email, 'new@company.test');
      expect(await services.accounts.authenticate(auth.token), auth.account.id);
      expect(
        (await services.organizations.list(auth.account.id)).single.id,
        org,
      );
      await expectLater(
        invitations.registerAndAccept(
          result.token,
          'Again',
          'another-valid-password',
        ),
        throwsA(isA<VaultException>()),
      );
      expect(
        await services.store.read((d) => (d['accounts'] as List).length),
        4,
      );
    },
  );

  test(
    'revocation during signup hashing leaves no account session or membership',
    () async {
      final result = await invite('race@company.test');
      final registering = invitations.registerAndAccept(
        result.token,
        'Race',
        'a-new-account-password',
      );
      await invitations.revoke('owner', org, result.invitation.id);
      await expectLater(registering, throwsA(isA<VaultException>()));
      expect(
        await services.store.read(
          (d) => (d['accounts'] as List).any(
            (a) => a['email'] == 'race@company.test',
          ),
        ),
        isFalse,
      );
      expect(
        await services.store.read((d) => (d['sessions'] as List).length),
        0,
      );
      expect((await services.organizations.members('owner', org)).length, 1);
    },
  );

  test(
    'existing account cannot be replaced through signup invitation',
    () async {
      final result = await invite();
      await expectLater(
        invitations.registerAndAccept(
          result.token,
          'Replacement',
          'a-new-account-password',
        ),
        throwsA(isA<VaultException>()),
      );
      expect((await invitations.inbox('recipient')).single.status, 'pending');
      expect(await services.organizations.list('recipient'), isEmpty);
      expect((await invitations.profile('recipient')).name, 'recipient');
    },
  );

  test(
    'decline works without an account and enforces a seven-day cooldown',
    () async {
      final result = await invite('new@company.test');
      await invitations.declineToken(result.token);
      expect(
        (await invitations.outgoing('owner', org)).single.status,
        'declined',
      );
      await expectLater(
        invite('new@company.test'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.preview(result.token),
        throwsA(isA<VaultException>()),
      );
      now = now.add(const Duration(days: 8));
      expect((await invite('new@company.test')).invitation.status, 'pending');
    },
  );

  test(
    'only recipient can decline and only owner can create, list or revoke',
    () async {
      final result = await invite();
      await expectLater(
        invitations.decline('outsider', result.invitation.id),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.outgoing('outsider', org),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.revoke('outsider', org, result.invitation.id),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        invitations.create('recipient', org, 'x@company.test', 'X', 'editor'),
        throwsA(isA<VaultException>()),
      );
      await invitations.decline('recipient', result.invitation.id);
      expect((await invitations.inbox('recipient')).single.status, 'declined');
      expect(await services.organizations.list('recipient'), isEmpty);
    },
  );

  test(
    'expired or revoked links cannot be accepted and old pending links can be replaced',
    () async {
      final result = await invite();
      now = now.add(const Duration(days: 7));
      expect((await invitations.inbox('recipient')).single.status, 'expired');
      await expectLater(
        invitations.accept('recipient', result.invitation.id, result.token),
        throwsA(isA<VaultException>()),
      );
      final next = await invite();
      await invitations.revoke('owner', org, next.invitation.id);
      await expectLater(
        invitations.preview(next.token),
        throwsA(isA<VaultException>()),
      );
      expect(
        (await invitations.outgoing('owner', org)).first.status,
        'revoked',
      );
    },
  );

  test(
    'blocking preferences reject new and pending invites and survive restart',
    () async {
      final result = await invite();
      final profile = await invitations.updatePolicy('recipient', 'none');
      expect(profile.invitationPolicy, 'none');
      expect((await invitations.inbox('recipient')).single.status, 'blocked');
      await expectLater(
        invitations.accept('recipient', result.invitation.id, result.token),
        throwsA(isA<VaultException>()),
      );
      await expectLater(invite(), throwsA(isA<VaultException>()));
      await services.close();
      services = await VaultServices.open(directory, key);
      invitations = InvitationService(
        services.store,
        services.accounts,
        now: () => now,
      );
      expect((await invitations.profile('recipient')).invitationPolicy, 'none');
      await invitations.updatePolicy('recipient', 'all');
      expect((await invite()).invitation.status, 'pending');
    },
  );

  test(
    'same-domain policy compares exact domains and blocks incompatible pending invitations',
    () async {
      await invitations.updatePolicy('recipient', 'sameDomain');
      expect((await invite()).invitation.status, 'pending');
      await invitations.updatePolicy('outsider', 'sameDomain');
      await expectLater(
        invite('other@else.test'),
        throwsA(isA<VaultException>()),
      );
      await invitations.updatePolicy('outsider', 'all');
      final foreign = await invite('other@else.test');
      await invitations.updatePolicy('outsider', 'sameDomain');
      expect((await invitations.inbox('outsider')).single.status, 'blocked');
      await expectLater(
        invitations.accept('outsider', foreign.invitation.id, foreign.token),
        throwsA(isA<VaultException>()),
      );
      await services.store.write(
        (data) => (data['accounts'] as List).firstWhere(
          (a) => a['id'] == 'recipient',
        )['email'] = 'person@sub.company.test',
      );
      await expectLater(
        invite('person@sub.company.test'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'duplicate creation and racing responses cannot create duplicate membership',
    () async {
      final results = await Future.wait([
        invite().then<Object>((v) => v).catchError((Object e) => e),
        invite().then<Object>((v) => v).catchError((Object e) => e),
      ]);
      expect(results.whereType<InvitationCreated>().length, 1);
      final result = results.whereType<InvitationCreated>().single;
      final responses = await Future.wait([
        invitations
            .accept('recipient', result.invitation.id, result.token)
            .then((_) => 'accepted')
            .catchError((Object _) => 'failed'),
        invitations
            .decline('recipient', result.invitation.id)
            .then((_) => 'declined')
            .catchError((Object _) => 'failed'),
      ]);
      expect(responses.where((r) => r == 'failed').length, 1);
      expect((await services.organizations.members('owner', org)).length, 2);
    },
  );

  test(
    'invitation rate limits persist and token never appears in stored records or lists',
    () async {
      final result = await invite();
      expect(
        jsonEncode(await services.store.read((d) => d)),
        isNot(contains(result.token)),
      );
      expect(
        jsonEncode(
          (await invitations.inbox(
            'recipient',
          )).map((i) => i.toJson()).toList(),
        ),
        isNot(contains('token')),
      );
      for (var i = 1; i < 20; i++) {
        await invite('person$i@company.test');
      }
      await services.close();
      services = await VaultServices.open(directory, key);
      invitations = InvitationService(
        services.store,
        services.accounts,
        now: () => now,
      );
      await expectLater(
        invite('limit@company.test'),
        throwsA(isA<VaultException>()),
      );
      now = now.add(const Duration(hours: 2));
      expect((await invite('limit@company.test')).invitation.status, 'pending');
    },
  );
}
