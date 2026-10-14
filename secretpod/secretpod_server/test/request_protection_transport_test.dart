import 'dart:convert';
import 'dart:io';

import 'package:secretpod_client/secretpod_client.dart' as api;
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/generated/serverpod.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:test/test.dart';

class _Auth implements api.ClientAuthKeyProvider {
  _Auth(this.token);
  final String token;
  @override
  Future<String?> get authHeaderValue async => 'Bearer $token';
}

void main() {
  test(
    'HTTP clients share account quotas and rejected requests preserve audits',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'secretpod-limits-',
      );
      final services = await VaultServices.open(
        directory,
        base64Encode(List.filled(32, 23)),
      );
      addTearDown(() async {
        await services.close();
        await directory.delete(recursive: true);
      });
      final tokens = List.generate(3, (_) => CryptoService.randomToken());
      await services.store.write((data) {
        for (final actor in ['owner', 'reader']) {
          rows(data, 'accounts').add({
            'id': actor,
            'name': actor,
            'email': '$actor@example.com',
            'salt': 'fixture',
            'passwordHash': 'fixture',
          });
        }
        for (var i = 0; i < tokens.length; i++) {
          rows(data, 'sessions').add({
            'digest': CryptoService.tokenDigest(tokens[i]),
            'accountId': i < 2 ? 'owner' : 'reader',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          });
        }
      });
      final organization = await services.organizations.create(
        'owner',
        'Limit test',
      );
      await services.store.write((data) {
        rows(data, 'members').add({
          'accountId': 'reader',
          'organizationId': organization.id,
          'role': 'reader',
        });
      });
      final secret = await services.vault.save(
        'owner',
        organization.id,
        name: 'SYNTHETIC',
        value: 'synthetic-secret',
        project: 'Default',
        environment: 'Development',
        kind: 'API key',
        description: '',
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
      addTearDown(() => pod.shutdown(exitProcess: false));
      final clients = tokens
          .map(
            (token) =>
                api.Client('http://localhost:${pod.server.port}/')
                  ..authKeyProvider = _Auth(token),
          )
          .toList();
      addTearDown(() {
        for (final client in clients) {
          client.close();
        }
      });
      final first = clients[0], second = clients[1], reader = clients[2];
      final copy = await first.vault.copySecret(organization.id, secret.id);
      await Future.wait(
        List.generate(9, (i) async {
          if (i.isEven) {
            expect(
              await first.vault.revealSecret(organization.id, secret.id),
              'synthetic-secret',
            );
          } else {
            expect(
              (await second.vault.revealSecretFields(
                organization.id,
                secret.id,
              )).value,
              'synthetic-secret',
            );
          }
        }),
      );
      final before = await services.store.read(
        (data) => jsonEncode(rows(data, 'events')),
      );
      for (final request in [
        () => second.vault.revealSecret(organization.id, secret.id),
        () => first.vault.revealSecretFields(organization.id, secret.id),
        () => second.vault.copySecret(organization.id, secret.id),
      ]) {
        await expectLater(
          request(),
          throwsA(
            isA<api.VaultException>().having(
              (e) => e.message,
              'message',
              contains('Too many secret access requests. Try again in'),
            ),
          ),
        );
      }
      expect(
        await services.store.read((data) => jsonEncode(rows(data, 'events'))),
        before,
      );
      await first.vault.confirmCopy(organization.id, secret.id, copy.eventId);
      await first.vault.confirmCopy(organization.id, secret.id, copy.eventId);
      final events = await services.store.read((data) => rows(data, 'events'));
      expect(
        events.where((e) => e['id'] == copy.eventId).single['action'],
        'copied',
      );
      expect(
        await reader.vault.revealSecret(organization.id, secret.id),
        'synthetic-secret',
      );
    },
  );
}
