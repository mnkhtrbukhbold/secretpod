import 'dart:convert';
import 'dart:io';
import 'package:secretpod_client/secretpod_client.dart' as client_api;
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/generated/serverpod.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:test/test.dart';

class _Auth implements client_api.ClientAuthKeyProvider {
  String? token;
  @override
  Future<String?> get authHeaderValue async =>
      token == null ? null : 'Bearer $token';
}

void main() {
  test(
    'real Serverpod transport enforces auth and round-trips the secret lifecycle',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'secretpod-http-',
      );
      final services = await VaultServices.open(
        directory,
        base64Encode(List<int>.filled(32, 41)),
      );
      VaultServices.instance = services;
      final pod = Serverpod(
        ['--mode', 'test'],
        authenticationHandler: (session, token) async {
          final actor = await services.accounts.authenticate(token);
          return actor == null
              ? null
              : AuthenticationInfo(
                  actor,
                  {},
                  authId: CryptoService.tokenDigest(token),
                );
        },
      );
      await pod.start();
      final auth = _Auth();
      final client = client_api.Client('http://localhost:${pod.server.port}/')
        ..authKeyProvider = auth;
      final otherAuth = _Auth();
      final other = client_api.Client('http://localhost:${pod.server.port}/')
        ..authKeyProvider = otherAuth;
      try {
        await expectLater(
          client.vault.organizations(),
          throwsA(isA<client_api.ServerpodClientUnauthorized>()),
        );
        await expectLater(
          client.invitation.inbox(),
          throwsA(isA<client_api.ServerpodClientUnauthorized>()),
        );
        for (final operation in [
          () => client.vault.renameOrganization('unknown', 'Unauthenticated'),
          () => client.profile.updateName('Unauthenticated'),
          () => client.profile.updateEmail('test-password', 'new@example.com'),
          () => client.profile.updateTheme('dark'),
          () => client.profile.changePassword('old-password', 'new-password'),
        ]) {
          await expectLater(
            operation(),
            throwsA(isA<client_api.ServerpodClientUnauthorized>()),
          );
        }
        final owner = await client.account.register(
          'transport@example.com',
          'transport-password-123!',
          'Alex',
        );
        auth.token = owner.token;
        expect(
          (await client.profile.updateName('Updated owner')).name,
          'Updated owner',
        );
        expect((await client.profile.updateTheme('dark')).themeMode, 'dark');
        final extraSession = await other.account.login(
          'transport@example.com',
          'transport-password-123!',
        );
        otherAuth.token = extraSession.token;
        await expectLater(
          client.profile.updateEmail(
            'incorrect-password',
            'updated@example.com',
          ),
          throwsA(isA<client_api.VaultException>()),
        );
        expect(
          (await client.profile.updateEmail(
            'transport-password-123!',
            'updated@example.com',
          )).email,
          'updated@example.com',
        );
        await client.profile.changePassword(
          'transport-password-123!',
          'new-transport-password',
        );
        expect((await client.invitation.profile()).id, owner.account.id);
        await expectLater(
          other.invitation.profile(),
          throwsA(isA<client_api.ServerpodClientUnauthorized>()),
        );
        final org = await client.vault.createOrganization('Transport team');
        final renamed = await client.vault.renameOrganization(
          org.id,
          'Renamed transport team',
        );
        expect(renamed.id, org.id);
        expect(renamed.name, 'Renamed transport team');
        expect(
          (await client.vault.organizations()).single.name,
          'Renamed transport team',
        );
        await expectLater(
          client.vault.renameOrganization(org.id, '  '),
          throwsA(isA<client_api.VaultException>()),
        );
        final secret = await client.vault.saveSecret(
          org.id,
          null,
          'DEPLOY_KEY',
          'first-secret-value',
          'Platform',
          'Production',
          'API key',
          'Deployment',
        );
        expect(
          (await client.vault.listSecrets(org.id)).single.name,
          'DEPLOY_KEY',
        );
        expect(
          await client.vault.revealSecret(org.id, secret.id),
          'first-secret-value',
        );
        final outsider = await other.account.register(
          'outsider@example.com',
          'transport-password-123!',
          'Sam',
        );
        otherAuth.token = outsider.token;
        await expectLater(
          other.vault.renameOrganization(org.id, 'Denied'),
          throwsA(isA<client_api.VaultException>()),
        );
        await expectLater(
          other.vault.revealSecret(org.id, secret.id),
          throwsA(isA<client_api.VaultException>()),
        );
        await expectLater(
          other.vault.secretActivity(org.id, secret.id, null),
          throwsA(isA<client_api.VaultException>()),
        );
        await expectLater(
          other.vault.copySecret(org.id, secret.id),
          throwsA(isA<client_api.VaultException>()),
        );
        final invitation = await client.invitation.create(
          org.id,
          outsider.account.email,
          'Sam',
          'reader',
        );
        expect(
          (await other.account.previewInvitation(
            invitation.token,
          )).recipientEmail,
          outsider.account.email,
        );
        expect((await other.invitation.inbox()).single.status, 'pending');
        await expectLater(
          other.invitation.outgoing(org.id),
          throwsA(isA<client_api.VaultException>()),
        );
        await expectLater(
          other.vault.revealSecret(org.id, secret.id),
          throwsA(isA<client_api.VaultException>()),
        );
        await other.invitation.accept(
          invitation.invitation.id,
          invitation.token,
        );
        expect(
          await other.vault.revealSecret(org.id, secret.id),
          'first-secret-value',
        );
        await expectLater(
          other.vault.deleteSecret(org.id, secret.id),
          throwsA(isA<client_api.VaultException>()),
        );
        final rotated = await client.vault.saveSecret(
          org.id,
          secret.id,
          'DEPLOY_KEY',
          'rotated-secret-value',
          'Platform',
          'Production',
          'API key',
          'Deployment',
        );
        expect(rotated.version, 2);
        final receipt = await other.vault.copySecret(org.id, secret.id);
        expect(receipt.value, 'rotated-secret-value');
        final pending = await other.vault.secretActivity(
          org.id,
          secret.id,
          null,
        );
        expect(pending.first.action, 'copy requested');
        await other.vault.confirmCopy(org.id, secret.id, receipt.eventId);
        final history = await client.vault.secretActivity(
          org.id,
          secret.id,
          null,
        );
        expect(history.first.action, 'copied');
        expect(history.first.actorId, outsider.account.id);
        expect(history.first.secretId, secret.id);
        expect(history.first.version, 2);
        expect(
          await client.vault.revealSecret(org.id, secret.id),
          'rotated-secret-value',
        );
        final audit = await client.vault.activity(org.id);
        expect(
          audit.map((e) => e.action),
          containsAll(['created', 'revealed', 'rotated']),
        );
        expect(
          jsonEncode(audit.map((e) => e.toJson()).toList()),
          isNot(contains('secret-value')),
        );
        await client.vault.deleteSecret(org.id, secret.id);
        expect(await client.vault.listSecrets(org.id), isEmpty);
        final credential = await client.vault.saveSecret(
          org.id,
          null,
          'ADMIN_LOGIN',
          'transport-service-password',
          'Platform',
          'Production',
          'Username and password',
          '',
          username: 'transport-service-user',
          url: 'https://example.com/login',
          expiresAt: DateTime.utc(2030, 12, 31),
        );
        expect(credential.url, 'https://example.com/login');
        expect(credential.expiresAt, DateTime.utc(2030, 12, 31));
        final fields = await other.vault.revealSecretFields(
          org.id,
          credential.id,
        );
        expect(fields.username, 'transport-service-user');
        expect(fields.value, 'transport-service-password');
        final usernameCopy = await other.vault.copySecret(
          org.id,
          credential.id,
          field: 'username',
        );
        expect(usernameCopy.value, 'transport-service-user');
        await other.vault.confirmCopy(
          org.id,
          credential.id,
          usernameCopy.eventId,
        );
        expect(
          (await client.vault.secretActivity(
            org.id,
            credential.id,
            null,
          )).first.details,
          'Field: username',
        );
        final updatedCredential = await client.vault.saveSecret(
          org.id,
          credential.id,
          credential.name,
          null,
          'Platform',
          'Production',
          'Username and password',
          'Updated metadata',
        );
        expect(updatedCredential.url, 'https://example.com/login');
        expect(updatedCredential.expiresAt, DateTime.utc(2030, 12, 31));
        final cleared = await client.vault.saveSecret(
          org.id,
          credential.id,
          credential.name,
          null,
          'Platform',
          'Production',
          'Username and password',
          'Cleared metadata',
          replaceMetadata: true,
        );
        expect(cleared.url, isNull);
        expect(cleared.expiresAt, isNull);
        expect(
          (await other.vault.revealSecretFields(
            org.id,
            credential.id,
          )).username,
          'transport-service-user',
        );
        await client.vault.deleteSecret(org.id, credential.id);
        final newcomerInvite = await client.invitation.create(
          org.id,
          'newcomer@example.com',
          'Suggested name',
          'editor',
        );
        final newcomer = await client.account.registerFromInvitation(
          newcomerInvite.token,
          'Chosen name',
          'newcomer-password-123',
        );
        expect(newcomer.account.name, 'Chosen name');
        expect(newcomer.account.email, 'newcomer@example.com');
        otherAuth.token = newcomer.token;
        expect((await other.vault.organizations()).single.role, 'editor');
        expect((await other.invitation.inbox()).single.status, 'accepted');
        await other.invitation.updatePolicy('none');
        expect((await other.invitation.profile()).invitationPolicy, 'none');
        final secondOrg = await client.vault.createOrganization('Another team');
        await expectLater(
          client.invitation.create(
            secondOrg.id,
            newcomer.account.email,
            'Name',
            'reader',
          ),
          throwsA(isA<client_api.VaultException>()),
        );
        final declineLink = await client.invitation.create(
          org.id,
          'decline@example.com',
          'Decline',
          'reader',
        );
        await other.account.declineInvitation(declineLink.token);
        expect(
          (await client.invitation.outgoing(org.id)).first.status,
          'declined',
        );
        await expectLater(
          other.account.registerFromInvitation(
            declineLink.token,
            'No access',
            'long-enough-password',
          ),
          throwsA(isA<client_api.VaultException>()),
        );
        // Exercise generated paging parameters on every list endpoint over HTTP.
        final pagingSecret = await client.vault.saveSecret(
          org.id,
          null,
          'PAGING_FIXTURE',
          'synthetic-value',
          'Default',
          'Production',
          'API key',
          '',
        );
        final pagedOperations = <Future<List<dynamic>> Function(int, int)>[
          (offset, limit) =>
              client.vault.organizations(offset: offset, limit: limit),
          (offset, limit) =>
              client.vault.members(org.id, offset: offset, limit: limit),
          (offset, limit) =>
              client.vault.listSecrets(org.id, offset: offset, limit: limit),
          (offset, limit) =>
              client.vault.activity(org.id, offset: offset, limit: limit),
          (offset, limit) => client.vault.secretActivity(
            org.id,
            pagingSecret.id,
            null,
            offset: offset,
            limit: limit,
          ),
          (offset, limit) =>
              other.invitation.inbox(offset: offset, limit: limit),
          (offset, limit) =>
              client.invitation.outgoing(org.id, offset: offset, limit: limit),
        ];
        for (final operation in pagedOperations) {
          expect(await operation(0, 1), hasLength(1));
          expect(await operation(10000, 25), isEmpty);
          await expectLater(
            operation(0, 101),
            throwsA(isA<client_api.VaultException>()),
          );
          await expectLater(
            operation(-1, 25),
            throwsA(isA<client_api.VaultException>()),
          );
        }
        expect(
          (await client.vault.listSecrets(
            org.id,
            query: 'PAGING_FIXTURE',
            limit: 1,
          )).single.id,
          pagingSecret.id,
        );
        final counts = await client.vault.summary(
          org.id,
          query: 'PAGING_FIXTURE',
        );
        expect(counts.filteredSecretCount, 1);
        expect(counts.memberCount, 3);
        await expectLater(
          other.vault.summary(secondOrg.id),
          throwsA(isA<client_api.VaultException>()),
        );
        // Removal and rotation marking round-trip through the generated API.
        await other.vault.revealSecret(org.id, pagingSecret.id);
        await expectLater(
          other.vault.memberRemovalSecrets(org.id, owner.account.id),
          throwsA(isA<client_api.VaultException>()),
        );
        final removalSecrets = await client.vault.memberRemovalSecrets(
          org.id,
          newcomer.account.id,
          offset: 0,
          limit: 100,
          utcOffsetMinutes: 120,
        );
        expect(removalSecrets.map((s) => s.id), [pagingSecret.id]);
        expect(
          (await client.vault.setSecretRotationRequired(
            org.id,
            pagingSecret.id,
            true,
          )).needsRotation,
          isTrue,
        );
        expect(
          (await client.vault.setSecretRotationRequired(
            org.id,
            pagingSecret.id,
            false,
          )).needsRotation,
          isFalse,
        );
        await client.vault.removeMember(
          org.id,
          newcomer.account.id,
          [pagingSecret.id],
          [pagingSecret.id],
          utcOffsetMinutes: 120,
        );
        expect(
          (await client.vault.listSecrets(org.id)).single.needsRotation,
          isTrue,
        );
        expect((await client.vault.summary(org.id)).memberCount, 2);
        expect(await other.vault.organizations(), isEmpty);
        await expectLater(
          other.vault.revealSecret(org.id, pagingSecret.id),
          throwsA(isA<client_api.VaultException>()),
        );
        await expectLater(
          other.vault.setSecretRotationRequired(org.id, pagingSecret.id, false),
          throwsA(isA<client_api.VaultException>()),
        );
        await expectLater(
          other.invitation.accept(
            newcomerInvite.invitation.id,
            newcomerInvite.token,
          ),
          throwsA(isA<client_api.VaultException>()),
        );
        await client.vault.logout();
        await expectLater(
          client.vault.organizations(),
          throwsA(isA<client_api.ServerpodClientUnauthorized>()),
        );
      } finally {
        client.close();
        other.close();
        await pod.shutdown(exitProcess: false);
        await services.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
