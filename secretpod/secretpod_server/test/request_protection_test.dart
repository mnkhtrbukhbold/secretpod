import 'dart:async';
import 'dart:convert';

import 'package:secretpod_server/src/account/account_service.dart';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:secretpod_server/src/vault/vault_service.dart';
import 'package:test/test.dart';

class _UnavailableStore extends _Store {
  @override
  Future<T> read<T>(T Function(VaultData) operation) async {
    throw StateError('Synthetic database outage');
  }
}

class _Store implements VaultStore {
  final VaultData data = {
    'accounts': <Map<String, dynamic>>[],
    'sessions': <Map<String, dynamic>>[],
    'organizations': <Map<String, dynamic>>[],
    'members': <Map<String, dynamic>>[],
    'secrets': <Map<String, dynamic>>[],
    'events': <Map<String, dynamic>>[],
    'projects': <Map<String, dynamic>>[],
  };
  int reads = 0, writes = 0;
  @override
  Future<T> read<T>(T Function(VaultData) operation) async {
    reads++;
    return operation(jsonDecode(jsonEncode(data)) as VaultData);
  }

  @override
  Future<T> write<T>(FutureOr<T> Function(VaultData) operation) async {
    writes++;
    return operation(data);
  }

  @override
  Future<void> close() async {}
}

void main() {
  late _Store store;
  late VaultService vault;
  late SecretView secret;
  setUp(() async {
    store = _Store();
    for (final actor in ['reader', 'other']) {
      rows(store.data, 'accounts').add({
        'id': actor,
        'name': actor,
        'email': '$actor@example.com',
      });
      rows(store.data, 'members').add({
        'accountId': actor,
        'organizationId': 'org',
        'role': 'owner',
      });
    }
    vault = VaultService(
      store,
      CryptoService(base64Encode(List.filled(32, 9))),
    );
    secret = await vault.save(
      'reader',
      'org',
      name: 'KEY',
      value: 'synthetic-value',
      project: 'Default',
      environment: 'Development',
      kind: 'API key',
      description: '',
    );
  });

  test(
    'all reveal and copy routes share an account budget before storage',
    () async {
      for (var i = 0; i < 10; i++) {
        switch (i % 3) {
          case 0:
            await vault.reveal('reader', 'org', secret.id);
          case 1:
            await vault.revealFields('reader', 'org', secret.id);
          case 2:
            await vault.copy('reader', 'org', secret.id);
        }
      }
      final writes = store.writes;
      final events = rows(store.data, 'events').length;
      for (final request in [
        () => vault.reveal('reader', 'org', secret.id),
        () => vault.revealFields('reader', 'org', secret.id),
        () => vault.copy('reader', 'org', secret.id),
        () => vault.reveal('reader', 'different-org', 'different-secret'),
      ]) {
        await expectLater(
          request(),
          throwsA(
            isA<VaultException>().having(
              (e) => e.message,
              'message',
              contains('Try again in'),
            ),
          ),
        );
      }
      expect(store.writes, writes);
      expect(rows(store.data, 'events').length, events);
      expect(await vault.reveal('other', 'org', secret.id), 'synthetic-value');
      expect(
        jsonEncode(rows(store.data, 'events')),
        isNot(contains('synthetic-value')),
      );
    },
  );

  test(
    'concurrent secret access reserves quota before awaiting storage',
    () async {
      final results = await Future.wait(
        List.generate(25, (_) async {
          try {
            await vault.reveal('reader', 'org', secret.id);
            return true;
          } on VaultException {
            return false;
          }
        }),
      );
      expect(results.where((allowed) => allowed).length, 10);
      expect(
        rows(
          store.data,
          'events',
        ).where((e) => e['action'] == 'revealed').length,
        10,
      );
    },
  );

  test('successful logins cannot reset the email request budget', () async {
    const password = 'exact password bytes ';
    final salt = CryptoService.randomToken();
    rows(store.data, 'accounts').add({
      'id': 'login',
      'name': 'Login',
      'email': 'login@example.com',
      'salt': salt,
      'passwordHash': await CryptoService.hashPassword(password, salt),
    });
    var now = DateTime.utc(2026, 10, 14);
    final accounts = AccountService(store, now: () => now);
    for (var i = 0; i < 10; i++) {
      await accounts.login(' LOGIN@EXAMPLE.COM ', password);
    }
    final reads = store.reads;
    final writes = store.writes;
    await expectLater(
      accounts.login('login@example.com', password),
      throwsA(
        isA<VaultException>().having(
          (e) => e.message,
          'message',
          contains('Too many attempts'),
        ),
      ),
    );
    expect(store.reads, reads);
    expect(store.writes, writes);
    now = now.add(const Duration(minutes: 15));
    expect(
      (await accounts.login('login@example.com', password)).account.id,
      'login',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('empty and oversized login passwords do not access storage', () async {
    final accounts = AccountService(store);
    for (final password in ['', 'x' * 257]) {
      await expectLater(
        accounts.login('nobody@example.com', password),
        throwsA(
          isA<VaultException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password.',
          ),
        ),
      );
    }
    expect(store.reads, 0);
  });

  test(
    'rotating email addresses cannot bypass the global login budget',
    () async {
      var now = DateTime.utc(2026, 10, 14);
      final accounts = AccountService(_UnavailableStore(), now: () => now);
      for (var i = 0; i < 60; i++) {
        await expectLater(
          accounts.login('person$i@example.com', 'password'),
          throwsStateError,
        );
      }
      for (var i = 0; i < 100; i++) {
        await expectLater(
          accounts.login('blocked$i@example.com', 'password'),
          throwsA(
            isA<VaultException>().having(
              (e) => e.message,
              'message',
              contains('60 seconds'),
            ),
          ),
        );
      }
      now = now.add(const Duration(minutes: 1));
      await expectLater(
        accounts.login('fresh@example.com', 'password'),
        throwsStateError,
      );
    },
  );

  test(
    'normalized email attempts expire without rejected attempts extending them',
    () async {
      var now = DateTime.utc(2026, 10, 14);
      final accounts = AccountService(_UnavailableStore(), now: () => now);
      for (var i = 0; i < 10; i++) {
        await expectLater(
          accounts.login(' PERSON@EXAMPLE.COM ', 'password'),
          throwsStateError,
        );
      }
      now = now.add(const Duration(minutes: 14, seconds: 59));
      await expectLater(
        accounts.login('person@example.com', 'password'),
        throwsA(
          isA<VaultException>().having(
            (e) => e.message,
            'message',
            contains('1 seconds'),
          ),
        ),
      );
      now = now.add(const Duration(seconds: 1));
      await expectLater(
        accounts.login('person@example.com', 'password'),
        throwsStateError,
      );
    },
  );
}
